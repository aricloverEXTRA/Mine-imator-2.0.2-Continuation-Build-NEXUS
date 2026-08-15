# Mine-imator Nexus — AI Companion

A tiny, **dependency-free** local HTTP server that connects Mine-imator's AI
Assistant to a local or remote AI model.

- Uses only the Python standard library (no `pip install` needed).
- Runs **outside** the renderer, so the AI has **zero impact** on rendering or
  animation performance. Mine-imator just sends a prompt and receives a plan.
- Supports **Ollama**, any **OpenAI-compatible** endpoint, **Anthropic**
  (Claude) and **Google Gemini**.
- The provider is **auto-detected** from the endpoint URL, or set explicitly in
  Mine-imator (Projects tab → AI → Provider).
- **API keys are optional** and only needed for cloud providers. Local models
  (e.g. Ollama) need no key at all.

## Quick start

```bash
# Start the companion (default port 8765)
python main.py

# Or pick a custom port (must match the "Companion port" in Mine-imator)
python main.py --port 9000
```

Requires Python 3.8+.

## How it fits together

```
Mine-imator (Projects tab -> AI)
        |  http_post -> 127.0.0.1:<port>/api/chat   (JSON prompt + context)
        v
AI Companion (this server)                           <-- does ALL network I/O
        |  OpenAI-compatible /v1/chat/completions
        v
Ollama / any OpenAI-compatible model
```

Mine-imator sends a prompt together with a read-only snapshot of the current
project ("context" / telemetry toggle). The model replies with a JSON edit
plan. The companion validates the plan shape, then Mine-imator validates every
action against the real project before applying **anything** (transactional —
a failed step rolls the whole change back).

## Endpoints

### `GET /health` (POST also accepted)

```json
{ "status": "ok", "service": "mineimator-ai-companion", "version": "1.2.0" }
```

### `POST /api/chat`

Request body:

```json
{
  "prompt": "Raise the right arm of Steve by 20 degrees",
  "context": { "project": { ... } } | null,
  "model": "llama3.1",
  "endpoint": "http://127.0.0.1:11434/v1",
  "temperature": 0.7,
  "max_tokens": 2048,
  "provider": "auto",
  "api_key": "",
  "mcp": [ { "name": "...", "url": "http://..." } ],
  "history": [ { "role": "user", "content": "..." } ],
  "memory": "Compacted summary of earlier work in this project session."
}
```

- `context` — read-only project snapshot (the "project understanding" toggle in
  Mine-imator). This is **not** telemetry/tracking; it never leaves your
  machine unless your model endpoint is remote.
- `provider` — `auto` (default), `ollama`, `openai`, `anthropic` or `gemini`.
  `auto` guesses from the endpoint URL: `generativelanguage` → Gemini,
  `anthropic.com` → Anthropic, everything else → OpenAI-compatible.
- `api_key` — optional. Required for Anthropic / Gemini / cloud OpenAI
  endpoints; ignored for local models.
- `mcp` — optional list of read-only MCP (JSON-RPC over HTTP) servers whose
  resources are fetched and summarized into the prompt. Failures are non-fatal.
- `history` — optional array of `{ "role", "content" }` messages (most recent
  last) from the current **project session**. The companion keeps only the
  most recent 40 as a safety net against token bloat.
- `memory` — optional plain-text string: a compacted summary of earlier work in
  the same session (produced by `/api/compact`). It is injected as an extra
  system message so the model keeps continuity without paying for the full
  transcript.

Both `history` and `memory` are **per project** and kept in memory only by
Mine-imator — they are never written to project files and vanish when the
project is closed.

Response (success):

```json
{
  "status": "ok",
  "message": "I moved Steve's right arm up 20 degrees.",
  "plan": [
    { "type": "set_pose", "object": "Steve", "part": "Right Arm",
      "values": { "rot_x": 20 }, "frame": 12 }
  ],
  "usage": { "prompt_tokens": 120, "completion_tokens": 40, "total_tokens": 160 },
  "warnings": []
}
```

Supported action types: `set_pose`, `set_object`, `move_object`,
`set_camera`, `add_keyframe`, `remove_keyframe`, `set_render`. Values use the
engine's `pos_x/pos_y/pos_z`, `rot_x/rot_y/rot_z`, `sca_x/sca_y/sca_z`,
`alpha`, `fov`, `exposure` and `gamma` channels (`move_object` treats
`pos_*` as **deltas**; `set_render` accepts `samples`, `render_distance`,
`exposure`, `gamma` and `aa_power`).

Response (error) — HTTP 502:

```json
{
  "status": "error",
  "error": { "code": "connection_refused", "message": "...", "retryable": true }
}
```

### `POST /api/compact`

Summarizes the session transcript (the same `history`/`memory` the chat
endpoint uses) into a short, plain-text memory note. Mine-imator stores it as
the new session `memory`, replacing the full transcript — so the model keeps
its context but the request shrinks. Use this when the session gets long.

Request body:

```json
{
  "model": "llama3.1",
  "endpoint": "http://127.0.0.1:11434/v1",
  "temperature": 0.7,
  "max_tokens": 2048,
  "provider": "auto",
  "api_key": "",
  "history": [ { "role": "user", "content": "..." } ],
  "memory": "Previous compact memory, if any."
}
```

Response (success):

```json
{
  "status": "ok",
  "summary": "The user asked to pose Steve's arm... Pending: the camera shot.",
  "usage": { "prompt_tokens": 300, "completion_tokens": 60, "total_tokens": 360 },
  "warnings": []
}
```

The summary is **plain text** (not JSON) and is kept under 400 words. It is
written in the same language as the transcript, never invents details, and
covers: what was asked, which objects/parts/values were edited (with names and
numbers), what is done, what is pending, and any preferences/constraints.

Response (error) — HTTP 502, same shape as `/api/chat`. If the session has no
transcript, it returns `invalid_request`.

## Error codes

| code                   | meaning                                                      |
| ---------------------- | ------------------------------------------------------------ |
| `invalid_request`      | Bad request body (missing prompt, missing API key, etc.)     |
| `connection_refused`   | Model endpoint unreachable (is Ollama running?)              |
| `model_not_found`      | Model name not available on the endpoint                     |
| `quota_exceeded`       | Provider quota / credit limit (HTTP 429)                     |
| `rate_limited`         | Provider rate limit (HTTP 429)                               |
| `token_limit`          | Request exceeded token/context limit (HTTP 400/413)          |
| `timeout`              | Model took too long to respond                               |
| `malformed_llm_response` | The model's reply was not valid JSON/plan                  |
| `internal_error`       | Anything unexpected                                          |

Every error is shown in Mine-imator as a friendly message, and **no project
changes are made** when an error occurs.

## Local-model compatibility warning

If the resolved provider is OpenAI-compatible and the endpoint is
`127.0.0.1`/`localhost` (e.g. Ollama, LM Studio), the companion appends a
warning to the response telling the user that a local model **may not support
the AI Assistant's tools** and results may be inconsistent. This is only a
notice — the request still goes through.

## Security notes

- The companion binds to `127.0.0.1` only, so it is not exposed to your local
  network.
- API keys are stored **per project** in the project file (plain text) and sent
  to the model endpoint. Prefer local models (Ollama) if you don't want a key
  stored in project files.
- It sends whatever the project asks it to send to the configured model
  endpoint. Use a local model (Ollama) if you don't want project data leaving
  your machine.
- It performs **no** write operations on the model's behalf — all edits happen
  inside Mine-imator after validation.
