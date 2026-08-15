#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Mine-imator Nexus — AI Companion
================================
A tiny, dependency-free local HTTP server that sits between Mine-imator and an
AI model. It supports:

  * Ollama / LM Studio / any OpenAI-compatible endpoint (no key needed)
  * OpenAI (chat/completions) with a Bearer API key
  * Anthropic (Claude, /v1/messages) with an x-api-key
  * Google Gemini (generateContent) with a query API key

The provider is auto-detected from the endpoint URL, or set explicitly in
Mine-imator (Projects tab -> AI -> Provider). API keys are optional and only
needed for cloud providers.

It exists so Mine-imator itself never talks directly to a model and so the AI
workload runs OUTSIDE the renderer: the companion does all network I/O and JSON
parsing, so enabling the AI has zero impact on rendering performance.

Endpoints
---------
GET  /health                 -> {"status":"ok", ...}            (also accepts POST)
POST /api/chat               -> chat with the model, see contract below
POST /api/compact            -> summarize the session memory to save tokens

The /api/chat request may include a "history" array (list of {"role",
"content"} messages, most recent last) and a "memory" string (a compacted
summary of earlier exchanges). Both give the model continuity across a project
session. /api/compact takes the same history/memory and returns a short,
plain-text summary that Mine-imator stores as the new session memory.

Run
---
    python main.py [--port 8765]

The port must match the "Companion port" setting inside Mine-imator (Projects
tab -> AI). Default is 8765.
"""

import argparse
import json
import os
import socket
import sys
import threading
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VERSION = "1.2.0"
DEFAULT_PORT = 8765
DEFAULT_MODEL = "llama3.1"
DEFAULT_ENDPOINT = "http://127.0.0.1:11434/v1"

# --------------------------------------------------------------------------
# Error codes (shared contract with Mine-imator's GML error catalog)
# --------------------------------------------------------------------------
ERR = {
    "invalid_request": "invalid_request",
    "connection_refused": "connection_refused",
    "model_not_found": "model_not_found",
    "quota_exceeded": "quota_exceeded",
    "rate_limited": "rate_limited",
    "token_limit": "token_limit",
    "timeout": "timeout",
    "malformed_llm_response": "malformed_llm_response",
    "internal_error": "internal_error",
}

REQUEST_TIMEOUT = 120.0  # seconds; generous for local models on slow hardware

# --------------------------------------------------------------------------
# System prompt given to the model. It MUST answer in JSON so the companion
# can turn it into a safe, validated edit plan for Mine-imator.
# --------------------------------------------------------------------------
SYSTEM_PROMPT = """You are the AI assistant built into Mine-imator Nexus. You help the user
create and edit Minecraft animations. You ONLY respond with a single JSON object,
no markdown, no commentary outside the JSON.

The JSON object must have exactly this shape:

{
  "message": "A short, friendly explanation of what you did, in plain text.",
  "plan": [
    {
      "type": "set_pose",
      "object": "Name of the object",
      "part": "Name of the body part (optional)",
      "values": {"rot_x": 20.0, "rot_y": 0.0, "rot_z": 0.0},
      "bend": {"x": 0.0, "y": 0.0, "z": 0.0},
      "frame": 12
    }
  ]
}

Allowed plan action types:
- set_pose:  rotate a body part. "object" is required, "part" required.
             "values" may contain rot_x/rot_y/rot_z.
- set_object: set position/rotation/scale of an object. "object" required.
              "values" may contain pos_x/pos_y/pos_z, rot_x/rot_y/rot_z,
              sca_x/sca_y/sca_z. Missing axes keep their current value.
- move_object: move an object by a delta. "object" required. "values" may
              contain pos_x/pos_y/pos_z which are added to the current values
              (positive or negative).
- set_camera: change the active camera. "values" may contain pos_x/pos_y/pos_z,
              rot_x/rot_y/rot_z, fov, exposure, gamma.
- add_keyframe: ensure a keyframe exists on the given object/part at "frame".
- remove_keyframe: remove the keyframe at "frame" on the given object/part.
- set_render: change render settings. "values" may contain samples,
              render_distance, exposure, gamma, aa_power.

Rules:
- Only reference objects and parts that exist in the provided context. If a
  name is not in the context, do NOT invent it; explain in "message" that you
  could not find it and return an empty plan [].
- Prefer small, incremental changes. One action per logical change.
- "frame" defaults to the current frame shown in context if omitted.
- Never fabricate values outside sane ranges (rotations -360..360, scale
  -10..10, fov 1..170, exposure 0.1..10, samples 1..4096).
- You only manage the CURRENT project. You cannot touch files, settings, or
  anything outside the project.
"""

# Used by POST /api/compact to turn a session transcript into a short, reusable
# memory note. The summary is plain text (NOT JSON) because it is stored as the
# project session memory and fed back to the model on later requests.
COMPACT_PROMPT = """You manage the memory of an AI animation assistant inside Mine-imator.
You are given the raw transcript of a work session (the user's requests and the
assistant's replies). Summarize it into a concise, reusable memory note that will
be given back to the assistant in future requests so it can continue the work
without losing context.

Requirements:
- Write in plain text. Do NOT use JSON, markdown code blocks, or any special format.
- Keep it under 400 words.
- Cover: what the user asked for, which objects/parts/values were edited (with
  names and numbers where known), what was already done, what is still pending,
  and any important preferences or constraints mentioned.
- Never invent details that are not in the transcript.
- Write in the same language as the transcript.
"""

# The "context" field is a JSON blob describing the current project. It is
# embedded in the user message when present.


def build_messages(payload, extra_context):
    """Build the chat messages list for the model.

    Order:
      system (instructions)
      system (optional compacted session memory summary)
      ... optional conversation history (last 40 messages, as-is) ...
      user  (current prompt + context + MCP info)
    """
    prompt = payload.get("prompt", "").strip()
    if not prompt:
        raise ValueError("prompt is required")

    messages = [
        {"role": "system", "content": payload.get("system") or SYSTEM_PROMPT}
    ]

    # Compacted session memory summary (if any) -> extra system message.
    memory = payload.get("memory")
    if isinstance(memory, str) and memory.strip():
        messages.append(
            {
                "role": "system",
                "content": (
                    "A compact summary of earlier work in this project session. "
                    "Use it for continuity; do not repeat it back.\n"
                    + memory.strip()
                ),
            }
        )

    # Conversation history (list of {"role", "content"}). Safety net: only
    # keep the most recent 40 messages to avoid runaway token bloat.
    history = payload.get("history")
    if isinstance(history, list):
        for entry in history[-40:]:
            if not isinstance(entry, dict):
                continue
            role = entry.get("role")
            content = entry.get("content")
            if (
                role in ("user", "assistant")
                and isinstance(content, str)
                and content.strip()
            ):
                messages.append({"role": role, "content": content})

    user_text = prompt
    if extra_context:
        user_text += (
            "\n\n[Project context (read-only JSON, use only the names that "
            "exist here):\n" + extra_context + "\n]"
        )
    if payload.get("mcp"):
        mcp_lines = []
        for mcp in payload["mcp"]:
            if mcp.get("name") and mcp.get("resources"):
                mcp_lines.append(
                    "- {0}: {1}".format(
                        mcp["name"], ", ".join(mcp["resources"][:40])
                    )
                )
        if mcp_lines:
            user_text += (
                "\n\n[Additional information available from external tools "
                "(read-only):\n" + "\n".join(mcp_lines) + "\n]"
            )

    messages.append({"role": "user", "content": user_text})
    return messages


def _resolve_provider(provider, endpoint):
    """Figure out which provider API to talk to."""
    p = (provider or "auto").strip().lower()
    ep = (endpoint or "").lower()
    if p in ("ollama", "openai", "anthropic", "gemini"):
        return p
    # auto-detect from the endpoint URL
    if "generativelanguage.googleapis.com" in ep:
        return "gemini"
    if "anthropic.com" in ep:
        return "anthropic"
    return "openai"  # includes Ollama and other OpenAI-compatible servers


def _http_post_json(url, body, headers, timeout=REQUEST_TIMEOUT):
    """POST JSON. Returns (status_code, parsed_json_or_None, network_error_or_None)."""
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode("utf-8"),
        headers=headers,
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8")), None
    except urllib.error.HTTPError as e:
        try:
            detail = json.loads(e.read().decode("utf-8"))
        except Exception:
            detail = {}
        return e.code, detail, None
    except urllib.error.URLError as e:
        return 0, None, str(e.reason)
    except socket.timeout:
        return 0, None, "timeout"


def _iter_error_messages(detail):
    """Yield human-readable error strings from various provider error shapes."""
    if isinstance(detail, dict):
        err = detail.get("error")
        if isinstance(err, dict):
            for k in ("message", "msg", "status"):
                if isinstance(err.get(k), str):
                    yield err[k]
            if isinstance(err.get("details"), str):
                yield err["details"]
        elif isinstance(err, str):
            yield err
        for k in ("message", "msg"):
            if isinstance(detail.get(k), str):
                yield detail[k]


def _raise_http_error(code, detail, model, endpoint, provider):
    text = str(detail)[:300].lower()
    msgs = " ".join(_iter_error_messages(detail)).lower()
    if code == 404:
        raise _error(
            ERR["model_not_found"],
            "The model '{}' was not found on the {} endpoint '{}'.".format(
                model, provider, endpoint
            ),
        )
    if code == 429:
        if any(w in (msgs + text) for w in ("quota", "insufficient", "credit", "limit reached")):
            raise _error(
                ERR["quota_exceeded"],
                "The model provider reported a quota or credit limit.",
                retryable=False,
            )
        raise _error(
            ERR["rate_limited"],
            "The model provider is rate limiting requests. Try again shortly.",
            retryable=True,
        )
    if code in (401, 403):
        raise _error(
            ERR["invalid_request"],
            "The API key was rejected by {}. Check the API key in the AI panel.".format(
                provider
            ),
            retryable=False,
        )
    if code in (400, 413):
        if any(
            w in (msgs + text)
            for w in ("token", "context length", "context_length", "maximum")
        ):
            raise _error(
                ERR["token_limit"],
                "The request exceeded the model's token/context limit.",
                retryable=False,
            )
        if "model" in msgs and "not" in msgs:
            raise _error(
                ERR["model_not_found"],
                "The model '{}' could not be used: {}".format(model, msgs.strip()[:200]),
            )
        raise _error(
            ERR["internal_error"],
            "The {} endpoint rejected the request: {}".format(
                provider, (msgs or text).strip()[:200]
            ),
            retryable=False,
        )
    if code == 529:  # Anthropic overloaded
        raise _error(
            ERR["rate_limited"],
            "The model provider is overloaded. Try again shortly.",
            retryable=True,
        )
    raise _error(
        ERR["internal_error"],
        "The {} endpoint returned HTTP {}: {}".format(provider, code, text[:200]),
        retryable=True,
    )


def _raise_network_error(reason, endpoint):
    low = str(reason).lower()
    if "timed out" in low or "timeout" in low:
        raise _error(
            ERR["timeout"],
            "The model took too long to respond ({}s).".format(REQUEST_TIMEOUT),
            retryable=True,
        )
    if "connection" in low or "refused" in low or "resolve" in low:
        raise _error(
            ERR["connection_refused"],
            "Could not reach the AI endpoint '{}'. Is the model server running? "
            "(Error: {})".format(endpoint, reason),
            retryable=True,
        )
    raise _error(
        ERR["internal_error"],
        "Network error talking to '{}': {}".format(endpoint, reason),
        retryable=True,
    )


def _call_openai(endpoint, model, messages, temperature, max_tokens, api_key):
    """OpenAI-compatible /chat/completions (also Ollama, LM Studio, etc.)."""
    url = endpoint.rstrip("/")
    if not url.endswith("/chat/completions"):
        url += "/chat/completions"
    headers = {"Content-Type": "application/json"}
    if api_key:
        headers["Authorization"] = "Bearer " + api_key
    body = {
        "model": model,
        "messages": messages,
        "temperature": temperature,
        "max_tokens": max_tokens,
        "stream": False,
    }
    code, data, net_err = _http_post_json(url, body, headers)
    if net_err:
        _raise_network_error(net_err, endpoint)
    if code != 200:
        _raise_http_error(code, data, model, endpoint, "OpenAI-compatible")
    try:
        content = data["choices"][0]["message"]["content"]
        usage = data.get("usage", {})
    except (KeyError, IndexError, TypeError):
        raise _error(
            ERR["internal_error"],
            "The model endpoint did not return a valid chat completion.",
            retryable=True,
        )
    return content, {
        "prompt_tokens": usage.get("prompt_tokens", 0),
        "completion_tokens": usage.get("completion_tokens", 0),
        "total_tokens": usage.get("total_tokens", 0),
    }


def _call_anthropic(model, messages, temperature, max_tokens, api_key, endpoint):
    """Anthropic Messages API (/v1/messages)."""
    url = endpoint.rstrip("/")
    if url.endswith("/v1"):
        url = url[:-3]
    if not url.endswith("/v1/messages"):
        url += "/v1/messages"
    headers = {
        "Content-Type": "application/json",
        "x-api-key": api_key or "",
        "anthropic-version": "2023-06-01",
    }
    sys_text = ""
    user_text = ""
    for m in messages:
        if m.get("role") == "system":
            sys_text = (sys_text + "\n\n" if sys_text else "") + m.get("content", "")
        else:
            user_text = (user_text + "\n\n" if user_text else "") + m.get("content", "")
    if sys_text:
        user_text = "System instructions:\n" + sys_text + "\n\n" + user_text
    body = {
        "model": model,
        "max_tokens": max_tokens,
        "temperature": temperature,
        "messages": [{"role": "user", "content": user_text}],
    }
    code, data, net_err = _http_post_json(url, body, headers)
    if net_err:
        _raise_network_error(net_err, endpoint)
    if code != 200:
        _raise_http_error(code, data, model, endpoint, "Anthropic")
    try:
        blocks = data.get("content", [])
        content = "".join(
            b.get("text", "") for b in blocks if isinstance(b, dict) and b.get("type") == "text"
        )
        usage = data.get("usage", {})
    except Exception:
        raise _error(
            ERR["internal_error"],
            "The Anthropic endpoint did not return a valid response.",
            retryable=True,
        )
    pin = usage.get("input_tokens", 0)
    pout = usage.get("output_tokens", 0)
    return content, {
        "prompt_tokens": pin,
        "completion_tokens": pout,
        "total_tokens": pin + pout,
    }


def _call_gemini(endpoint, model, messages, temperature, max_tokens, api_key):
    """Google Gemini generateContent API."""
    url = endpoint.rstrip("/")
    if not (url.endswith("/v1beta") or url.endswith("/v1")):
        url += "/v1beta"
    url = url.rstrip("/")
    mname = model if model.startswith("models/") else "models/" + model
    url = url + "/" + mname + ":generateContent"
    if api_key:
        sep = "&" if "?" in url else "?"
        url = url + sep + "key=" + api_key
    sys_text = ""
    user_text = ""
    for m in messages:
        if m.get("role") == "system":
            sys_text = (sys_text + "\n\n" if sys_text else "") + m.get("content", "")
        else:
            user_text = (user_text + "\n\n" if user_text else "") + m.get("content", "")
    if sys_text:
        user_text = "System instructions:\n" + sys_text + "\n\n" + user_text
    body = {
        "contents": [{"role": "user", "parts": [{"text": user_text}]}],
        "generationConfig": {
            "temperature": temperature,
            "maxOutputTokens": max_tokens,
        },
    }
    code, data, net_err = _http_post_json(url, body, {"Content-Type": "application/json"})
    if net_err:
        _raise_network_error(net_err, endpoint)
    if code != 200:
        _raise_http_error(code, data, model, endpoint, "Gemini")
    try:
        parts = data["candidates"][0]["content"]["parts"]
        content = "".join(p.get("text", "") for p in parts if isinstance(p, dict))
        usage = data.get("usageMetadata", {})
    except Exception:
        raise _error(
            ERR["internal_error"],
            "The Gemini endpoint did not return a valid response.",
            retryable=True,
        )
    return content, {
        "prompt_tokens": usage.get("promptTokenCount", 0),
        "completion_tokens": usage.get("candidatesTokenCount", 0),
        "total_tokens": usage.get("totalTokenCount", 0),
    }


def call_model(provider, endpoint, model, messages, temperature, max_tokens, api_key):
    """Route a chat request to the right provider API.

    Raises a dict error payload (with code/message) on any failure.
    Returns (content, usage_dict) on success.
    """
    provider = _resolve_provider(provider, endpoint)
    if provider in ("anthropic", "gemini", "openai") and not api_key:
        raise _error(
            ERR["invalid_request"],
            "An API key is required for the {} provider. Add one in the AI "
            "panel, or use a local model (Ollama) without a key.".format(provider),
            retryable=False,
        )
    if provider == "anthropic":
        return _call_anthropic(model, messages, temperature, max_tokens, api_key, endpoint)
    if provider == "gemini":
        return _call_gemini(endpoint, model, messages, temperature, max_tokens, api_key)
    return _call_openai(endpoint, model, messages, temperature, max_tokens, api_key)


def strip_code_fence(text):
    """Remove ```json ... ``` fences the model may have added."""
    text = text.strip()
    if text.startswith("```"):
        # Remove first fence line and any trailing fence
        first = text.find("\n")
        if first != -1:
            text = text[first + 1 :]
        if text.rstrip().endswith("```"):
            text = text.rstrip()[:-3].rstrip()
    return text.strip()


def parse_llm_response(content):
    """Turn the model's raw text into {message, plan, warnings}.

    Raises malformed_llm_response when the JSON cannot be understood.
    """
    warnings = []
    text = strip_code_fence(content)

    # Try to locate the first JSON object if the model added prose.
    obj = None
    try:
        obj = json.loads(text)
    except Exception:
        start = text.find("{")
        end = text.rfind("}")
        if start != -1 and end > start:
            try:
                obj = json.loads(text[start : end + 1])
            except Exception:
                obj = None
    if obj is None:
        raise _error(
            ERR["malformed_llm_response"],
            "The model did not return valid JSON. Please try again or use a "
            "different model.",
        )

    if not isinstance(obj, dict):
        raise _error(
            ERR["malformed_llm_response"],
            "The model's response was not a JSON object.",
        )

    message = obj.get("message")
    if message is None:
        message = ""

    plan = obj.get("plan", [])
    if plan is None:
        plan = []
    if not isinstance(plan, list):
        raise _error(
            ERR["malformed_llm_response"],
            "The 'plan' field in the model's response must be a list.",
        )

    # Basic action validation (strict checking happens in Mine-imator itself).
    allowed_types = {
        "set_pose",
        "set_object",
        "move_object",
        "set_camera",
        "add_keyframe",
        "remove_keyframe",
        "set_render",
    }
    cleaned = []
    for i, action in enumerate(plan):
        if not isinstance(action, dict) or not action.get("type"):
            warnings.append("Dropped plan action #{}: missing 'type'.".format(i + 1))
            continue
        if action["type"] not in allowed_types:
            warnings.append(
                "Dropped plan action #{}: unknown type '{}'.".format(
                    i + 1, action["type"]
                )
            )
            continue
        cleaned.append(action)
    if len(cleaned) != len(plan):
        warnings.append("Some plan actions were dropped because they were invalid.")

    return message, cleaned, warnings


def gather_mcp_resources(mcp_servers):
    """Minimal read-only MCP support: fetch resources/list from each server.

    Only JSON-RPC-over-HTTP servers are supported. Failures are non-fatal and
    reported as warnings so the chat still works.
    """
    results = []
    warnings = []
    for mcp in mcp_servers or []:
        name = mcp.get("name", "mcp")
        url = mcp.get("url", "")
        if not url:
            continue
        payload = json.dumps(
            {"jsonrpc": "2.0", "method": "resources/list", "id": 1}
        ).encode("utf-8")
        req = urllib.request.Request(
            url,
            data=payload,
            headers={"Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            resources = data.get("result", {}).get("resources", [])
            if not isinstance(resources, list):
                resources = []
            names = [
                str(r.get("name") or r.get("uri"))
                for r in resources
                if isinstance(r, dict)
            ]
            results.append({"name": name, "url": url, "resources": names})
        except Exception as e:
            warnings.append(
                "Could not reach MCP server '{}' ({}): {}".format(name, url, str(e)[:120])
            )
    return results, warnings


def handle_chat(payload):
    """Entry point for POST /api/chat. Returns a JSON-serializable dict."""
    try:
        prompt = payload.get("prompt")
        if not prompt or not str(prompt).strip():
            raise _error(ERR["invalid_request"], "Field 'prompt' is required.")
        model = str(payload.get("model") or DEFAULT_MODEL)
        endpoint = str(payload.get("endpoint") or DEFAULT_ENDPOINT)
        provider = str(payload.get("provider") or "auto").strip().lower()
        api_key = str(payload.get("api_key") or "").strip()
        try:
            temperature = float(payload.get("temperature", 0.7))
        except (TypeError, ValueError):
            temperature = 0.7
        temperature = max(0.0, min(2.0, temperature))
        try:
            max_tokens = int(payload.get("max_tokens", 2048))
        except (TypeError, ValueError):
            max_tokens = 2048
        max_tokens = max(1, min(32768, max_tokens))

        context = payload.get("context")
        context_text = None
        if isinstance(context, dict):
            context_text = json.dumps(context)
        elif isinstance(context, str) and context.strip():
            context_text = context

        mcp_servers = payload.get("mcp")
        if not isinstance(mcp_servers, list):
            mcp_servers = None

        mcp_resources, mcp_warnings = gather_mcp_resources(mcp_servers)

        messages = build_messages(payload, context_text)
        # Rebuild with MCP resources attached
        if mcp_resources:
            payload = dict(payload)
            payload["mcp"] = mcp_resources
            messages = build_messages(payload, context_text)

        content, usage = call_model(
            provider, endpoint, model, messages, temperature, max_tokens, api_key
        )
        message, plan, parse_warnings = parse_llm_response(content)

        warnings = mcp_warnings + parse_warnings
        # Heads-up for local/custom models that may not follow the JSON contract
        resolved = _resolve_provider(provider, endpoint)
        if resolved == "openai" and ("127.0.0.1" in endpoint or "localhost" in endpoint):
            warnings.append(
                "Using a local model: it must support structured JSON output to "
                "work with the AI Assistant. If the reply is garbled, the model "
                "may not be compatible."
            )
        return {
            "status": "ok",
            "message": message,
            "plan": plan,
            "usage": usage,
            "warnings": warnings,
        }
    except _AiError as e:
        return {"status": "error", "error": {"code": e.code, "message": e.message, "retryable": e.retryable}}
    except Exception as e:  # last-resort safety net
        return {
            "status": "error",
            "error": {
                "code": ERR["internal_error"],
                "message": "Unexpected companion error: {}".format(str(e)[:300]),
                "retryable": True,
            },
        }


def handle_compact(payload):
    """Entry point for POST /api/compact.

    Summarizes the session transcript into a short plain-text memory note that
    Mine-imator stores as the project session memory (reducing token bloat).
    """
    try:
        model = str(payload.get("model") or DEFAULT_MODEL)
        endpoint = str(payload.get("endpoint") or DEFAULT_ENDPOINT)
        provider = str(payload.get("provider") or "auto").strip().lower()
        api_key = str(payload.get("api_key") or "").strip()
        try:
            temperature = float(payload.get("temperature", 0.7))
        except (TypeError, ValueError):
            temperature = 0.7
        temperature = max(0.0, min(2.0, temperature))
        try:
            max_tokens = int(payload.get("max_tokens", 2048))
        except (TypeError, ValueError):
            max_tokens = 2048
        max_tokens = max(1, min(32768, max_tokens))

        history = payload.get("history")
        if not isinstance(history, list):
            history = []
        memory = payload.get("memory")
        if not isinstance(memory, str):
            memory = ""

        # Build the session transcript from history + previous compact memory.
        lines = []
        for entry in history:
            if not isinstance(entry, dict):
                continue
            role = entry.get("role")
            content = entry.get("content")
            if (
                role in ("user", "assistant")
                and isinstance(content, str)
                and content.strip()
            ):
                who = "User" if role == "user" else "Assistant"
                lines.append("{0}: {1}".format(who, content.strip()))
        if memory.strip():
            lines.append("Previous compact memory: " + memory.strip())
        if not lines:
            raise _error(
                ERR["invalid_request"], "There is no session memory to compact."
            )

        transcript = "\n\n".join(lines)
        messages = [
            {"role": "system", "content": COMPACT_PROMPT},
            {"role": "user", "content": "Session transcript:\n\n" + transcript},
        ]

        content, usage = call_model(
            provider, endpoint, model, messages, temperature, max_tokens, api_key
        )
        summary = content.strip()
        if not summary:
            raise _error(
                ERR["malformed_llm_response"],
                "The model returned an empty summary.",
            )

        resolved = _resolve_provider(provider, endpoint)
        warnings = []
        if resolved == "openai" and ("127.0.0.1" in endpoint or "localhost" in endpoint):
            warnings.append(
                "Using a local model: it may summarize less reliably than a "
                "cloud model. The result can be regenerated at any time."
            )

        return {
            "status": "ok",
            "summary": summary,
            "usage": usage,
            "warnings": warnings,
        }
    except _AiError as e:
        return {"status": "error", "error": {"code": e.code, "message": e.message, "retryable": e.retryable}}
    except Exception as e:  # last-resort safety net
        return {
            "status": "error",
            "error": {
                "code": ERR["internal_error"],
                "message": "Unexpected companion error: {}".format(str(e)[:300]),
                "retryable": True,
            },
        }


# --------------------------------------------------------------------------
# HTTP layer
# --------------------------------------------------------------------------
class _AiError(Exception):
    def __init__(self, code, message, retryable=True):
        super().__init__(message)
        self.code = code
        self.message = message
        self.retryable = retryable


def _error(code, message, retryable=True):
    return _AiError(code, message, retryable)


class Handler(BaseHTTPRequestHandler):
    server_version = "MineimatorAIBridge/" + VERSION

    def log_message(self, fmt, *args):  # quieter logging
        sys.stderr.write("[ai-companion] %s\n" % (fmt % args))

    def _send(self, code, obj):
        body = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def _read_body(self):
        length = int(self.headers.get("Content-Length", 0) or 0)
        if length <= 0:
            return {}
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8"))
        except Exception:
            return {}

    def do_OPTIONS(self):  # CORS preflight
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def do_GET(self):
        if self.path.split("?")[0] == "/health":
            self._send(
                200,
                {
                    "status": "ok",
                    "service": "mineimator-ai-companion",
                    "version": VERSION,
                    "time": int(time.time()),
                },
            )
        else:
            self._send(
                404,
                {
                    "status": "error",
                    "error": {"code": "invalid_request", "message": "Not found."},
                },
            )

    def do_POST(self):
        path = self.path.split("?")[0]
        if path == "/health":
            self._send(200, {"status": "ok", "service": "mineimator-ai-companion", "version": VERSION})
            return
        if path == "/api/chat":
            payload = self._read_body()
            result = handle_chat(payload)
            code = 200 if result.get("status") == "ok" else 502
            self._send(code, result)
            return
        if path == "/api/compact":
            payload = self._read_body()
            result = handle_compact(payload)
            code = 200 if result.get("status") == "ok" else 502
            self._send(code, result)
            return
        self._send(
            404,
            {
                "status": "error",
                "error": {"code": "invalid_request", "message": "Unknown endpoint."},
            },
        )


def main():
    parser = argparse.ArgumentParser(description="Mine-imator Nexus AI Companion")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument("--host", default="127.0.0.1")
    args = parser.parse_args()

    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(
        "[ai-companion] Mine-imator Nexus AI Companion {} listening on "
        "http://{}:{}".format(VERSION, args.host, args.port),
        flush=True,
    )
    print(
        "[ai-companion] Default model: {} (endpoint {})".format(
            DEFAULT_MODEL, DEFAULT_ENDPOINT
        ),
        flush=True,
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[ai-companion] Shutting down.", flush=True)


if __name__ == "__main__":
    main()
