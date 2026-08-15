# Fork Notes — Mine-imator Nexus Build

Base: Mine-imator 2.0.2 Continuation Build 1.0.14.
Build name: **Nexus** (one-word name; set in `macros.gml` as `mineimator_fork_name`).

This document exists so that merging upstream updates (mbanders' continuation build,
published roughly every 3 months) stays **fast and conflict-free**.

## Branch / merge workflow

- Default branch is `plus` (this fork's changes).
- Add the upstream as a remote and merge it periodically:

```powershell
git remote add upstream https://github.com/<mbanders-org>/<mine-imator-2.0.2-continuation>.git
git fetch upstream
git merge upstream/<default-branch>   # on a branch, resolve any conflicts
```

- Keep ALL new code in new files/folders (git never conflicts on those).
- Touched existing files are listed below. When an upstream merge conflicts in one
  of them, re-apply the small additive edit (it is always marked with `// PLUS:` or
  a `PLUS-FORK` comment block).

## Files we modify (existing files)

Each entry is a small, additive change. **Do not** reformat or rename anything else.

- `GmProject/scripts/macros/macros.gml` — added fork version macro (additive only).
- `GmProject/scripts/file_dialog_open_model/file_dialog_open_model.gml` — added `*.obj` to the model file filter.
- `GmProject/scripts/res_load/res_load.gml` — MODEL branch: detect `.obj` and convert to `.mimodel` before loading.
- `GmProject/scripts/model_file_load_shape/model_file_load_shape.gml` — accept shape type `"mesh"` and build its vbuffer.
- `GmProject/scripts/app_startup_interface_tabs/app_startup_interface_tabs.gml` — (Feature 2) AI Assistant tab category.
- `GmProject/scripts/app_event_http/app_event_http.gml` — (Feature 2) dispatch to `ai_response` / `ai_compact_response` on companion replies.
- `GmProject/scripts/project_reset/project_reset.gml`, `project_save_project/project_save_project.gml`, `project_load_project/project_load_project.gml` — (Feature 2) per-project AI state (enabled, context toggle, model, endpoint, provider, API key, temperature, max tokens, MCP).
- `GmProject/scripts/settings_save/settings_save.gml` + `settings_load/settings_load.gml` — (Feature 2) companion port + autostart settings.
- `GmProject/scripts/macros/macros.gml` — fork name/version macros.
- `GmProject/datafiles/Data/Languages/english.milanguage` — (Feature 2) AI section of UI strings.
- `GmProject/Mine-imator.yyp` — registered 27 `ai_*` / `action_ai_*` / `tab_properties_ai` scripts + `folders/Scripts/AI.yy`.
- `CppProject/Gml/UtilFunc.cpp` + `gml.json` — (Feature 2) `http_post` and `system_total_ram_mb` externals.
- `CppProject/Gml/StringFunc.cpp` + `gml.json` — (Feature 2) `string_trim` external.

## New folders (zero merge risk)

- `GmProject/scripts/obj_import/` — OBJ parser + `.mtl` reader.
- `GmProject/scripts/obj_mesh_compress/` — OBJ triangle decimation (compression).
- `GmProject/scripts/obj_mesh_to_mimodel/` — writes `.mimodel` (mesh shape) from parsed OBJ.
- `GmProject/scripts/model_shape_generate_mesh/` — mesh shape vbuffer generator.
- `companion/` — (Feature 2) Python AI companion (MCP server + HTTP API). AI is **OFF by default**.

## `.mimodel` format extension (mesh shape)

The `.mimodel` JSON format gains a new shape type `"mesh"` (alongside `"block"` / `"plane"`):

```json
{
  "name": "model name",
  "texture": "tex.png",
  "texture_size": [1, 1],
  "parts": [
    {
      "name": "part",
      "position": [0, 0, 0],
      "shapes": [
        {
          "type": "mesh",
          "texture": "tex.png",
          "texture_size": [1, 1],
          "uv": [0, 0],
          "vertices": [ [x,y,z, nx,ny,nz, u,v], ... ]
        }
      ]
    }
  ]
}
```

- `vertices` is a flat list of interleaved vertices: `x, y, z, nx, ny, nz, u, v`
  (8 reals per vertex). Coordinates are in Mine-imator internal space (Z-up); UVs are
  pre-normalised 0–1 with V flipped to texture space.
- `uv`, `texture_size`, `from`/`to` are **optional** for mesh shapes: `uv` defaults to
  `[0, 0]`, `texture_size` is `[1, 1]` (mesh UVs are already normalised so nothing is
  scaled by it), and the bounding box is computed from the vertices.
- Mesh shapes are non-bendable (`bend_shape = false`) in this version.
- **Runtime storage:** the loader flattens `vertices` into the instance ds_list
  `mesh_vertices` (interleaved reals), freed in `model_shape_event_destroy`.

## Compression

`obj_mesh_to_mimodel` automatically runs `obj_mesh_compress` when the OBJ has more
than **10 000 triangles** (target = 10 000). `obj_mesh_compress` decimates via
vertex-clustering: it quantises positions to a grid, welds nearby vertices (keeping
one per cell), and drops degenerate triangles. Grid resolution is increased in steps
until the triangle count fits the target, so the result looks close to the original
at a fraction of the triangle count.

---

# Feature 2 — AI Assistant (Nexus)

The AI Assistant is a **per-project** feature (its panel lives in the Projects
tab). It is **OFF by default**; every project must opt in. It lets the model
edit keyframes / pose / camera / render settings by returning a JSON plan that
Mine-imator validates and applies transactionally.

## Architecture

```
Mine-imator (Projects tab → AI)
        |  http_post → 127.0.0.1:<port>/api/chat   (JSON prompt + optional context)
        v
companion/main.py  (Python stdlib only, no pip installs)
        |  routes to the chosen provider
        v
Ollama / OpenAI-compatible / Anthropic (Claude) / Google Gemini
```

The companion does **all** network I/O, outside the renderer, so the AI has
**zero impact** on animation/rendering performance. Context is gathered **only**
at prompt time (never in the frame loop).

## Providers & API keys

- Provider auto-detected from the endpoint URL, or set explicitly: `auto`,
  `ollama`, `openai`, `anthropic`, `gemini`.
- API keys are **optional** and only needed for cloud providers (Claude,
  Gemini, cloud OpenAI). Local models (Ollama, LM Studio) need no key.
- Stored **per project** in the project file (plain text) via the `"ai"`
  section (see Backwards compatibility below).
- When the resolved provider is OpenAI-compatible and the endpoint is
  `127.0.0.1`/`localhost`, a **model-compatibility warning** is appended to the
  reply: local models may not support the AI Assistant's tools.

## Context ("project understanding") toggle

- `Project understanding` is a **separate per-project toggle, default OFF**.
- When ON, a read-only snapshot (project name/size/tempo, timeline length &
  current frame, render settings, active camera, selected objects/keyframes and
  up to 60 selected keyframe positions) is sent with each prompt.
- This is project understanding **only — not telemetry/tracking**. It never
  leaves the machine unless the model endpoint is remote.

## Memory & safety

- **Session memory (per project):** each project keeps an **in-memory** transcript
  of the session (user prompts + assistant replies, capped at 60 entries). On
  every successful exchange the latest user prompt + assistant reply are
  appended; nothing is ever written to project files, so the project file format
  is unchanged and back-compat with the vanilla build is preserved. Memory is
  reset when the project is closed / a new project is opened.
- **Compaction:** when the session gets long, a **Compact** button asks the
  companion's `/api/compact` to summarize the transcript into a short plain-text
  note (under 400 words, in the same language, never inventing details). The
  note replaces the transcript as the project's memory and is injected into
  later requests as a system message — the model keeps continuity while the
  token cost shrinks. A **Clear** button wipes the session memory.
- **Transactional:** every plan action is validated against the real project
  *before* anything is applied. If any step fails, the whole change is rolled
  back (timeline keyframes + render settings restored) and no partial edits
  remain. Exactly **one** undo step is created per successful apply.
- **Leak-free:** plan ownership uses JSON strings stored in the history slot
  (`ai_plan`), and every `json_decode` root map is destroyed recursively with
  `ds_map_destroy` on both the success and error paths. No persistent nested
  ds_map/list structures are kept.
- **8 GB RAM warning:** enabling the AI for the first time checks
  `system_total_ram_mb()`; if the machine has under 8 GB RAM a warning toast is
  shown (the feature still works, but slow on weak hardware).
- **Error safety nets:** every error is mapped to a friendly message
  (connection refused, model not found, quota/credit exceeded, rate limited,
  token/context limit, timeout, malformed model reply, missing API key, etc.)
  and **no project changes are made** when an error occurs.

## New folders (zero merge risk)

- `GmProject/scripts/ai_*/` — 27 AI scripts (context gathering, plan
  validation/apply, JSON helpers, transactional apply + rollback, session
  memory + compaction, UI).
- `GmProject/scripts/tab_properties_ai/`, `action_ai_*` — AI panel + actions.
- `companion/` — the Python AI companion (HTTP API + MCP).

## Build note

The C++ side adds three externals — `http_post`, `system_total_ram_mb`,
`string_trim` — in `CppProject/Gml/UtilFunc.cpp` / `StringFunc.cpp` +
`CppGen/gml.json`. `CppGen` transpiles the GML to `CppProject/Generated/*`
(validated: all `ai_*` functions present in `Mappings.cpp`/`Scripts*.cpp`).
Building the C++ project requires the Qt 5.15.9 + VS2022 toolchain described in
`CppProject/BUILD.md` (a full local build of Qt is needed — not automatable
here).

## Backwards compatibility (vanilla mbanders Continuation Build)

Saving a project from Nexus adds an extra `"ai"` JSON section to the project
file. The **vanilla** mbanders build ignores unknown top-level keys, so a
project saved in Nexus opens **unchanged** in the vanilla build and vice versa
— the two builds are fully interchangeable. The same applies to the global
settings file (extra `"ai"` section ignored by vanilla). All added UI strings
live in `english.milanguage` under a new `ai/` block; the vanilla language file
simply lacks these keys (safe).

## Merge notes

- All AI code lives in new `ai_*` / `action_ai_*` / `tab_properties_ai` scripts
  and new files in `companion/`, so upstream merges have **zero** conflict risk
  except the few additive edits listed in "Files we modify".
- When re-merging upstream, re-apply the small additive edits (marked
  `PLUS-FORK`) in `app_event_http.gml`, `project_*.gml`, `settings_*.gml`,
  `app_startup_interface_tabs.gml`, `UtilFunc.cpp`, `StringFunc.cpp`,
  `gml.json` and `english.milanguage`.

---

# Releases & building (Nexus)

## Short version (Windows)

1. **Build the C++ engine** — see `CppProject/BUILD.md`. This requires
   Visual Studio 2022, CMake, a locally-built Qt 5.15.9 in `C:\Dev\Qt\5.15.9`,
   plus the prebuilt libs in `CppProject/External/Win64`. Configure CMake with
   the source folder set to `CppProject` and build the **Release** config so you
   get `CppProject\build\Release\Mine-imator.exe`.
2. **Package the release** (exactly like mbanders, no WinRAR needed):

   ```powershell
   .\make-release.ps1 "2.0.2 Nexus 1.0.0" -BuildDir C:\Dev\Projects\Mine-imator-build
   ```

   → produces `Builds\Mine-imator 2.0.2 Nexus 1.0.0.zip` with this layout:

   ```
   Mine-imator 2.0.2 Nexus 1.0.0\
   ├─ Mine-imator.exe
   ├─ vcomp140.dll
   ├─ Start AI Companion.bat      (Nexus: launches companion\main.py)
   ├─ Projects\                    (empty, first-run save area)
   ├─ Data\ ... Particles\ ...     (from GmProject\datafiles)
   └─ companion\                   (Nexus: AI Assistant, main.py + README.md)
   ```

3. (Optional) If Inno Setup 6 is installed, `make-release.ps1` also builds the
   `... installer.exe` via `Installer/Windows/setup.iss`.

## How it compares to mbanders' release flow

mbanders' `Installer/Windows/UpdateApp.ps1` stages into a hand-maintained,
git-ignored `Installer/Windows/Mine-imator/` folder, then zips with WinRAR and
builds an Inno Setup installer. `make-release.ps1` (repo root) replicates the
same output — a versioned `Builds\Mine-imator <Version>.zip` whose top-level
folder is the version name — but builds the whole staging folder from the repo
(`GmProject/datafiles`, `Installer/Windows/vcomp140_*.dll`, `companion/`) so no
template folder is needed, and uses the built-in .NET zip by default (use
`-UseWinRAR` to match upstream exactly).

## Useful switches

| Switch | Meaning |
| ------ | ------- |
| `-Version "..."` | Release name (default `2.0.2 Nexus`) |
| `-BuildDir <path>` | CMake binary dir containing `Release\Mine-imator.exe` |
| `-Win32` | Package the 32-bit build (`Release-Win32\` + `vcomp140_x86.dll`) |
| `-SkipCompanion` | Don't bundle the AI companion |
| `-SkipInstaller` | Don't build the Inno Setup installer |
| `-UseWinRAR` | Use WinRAR like upstream instead of .NET zip |

## Mac / Linux

Upstream's `Installer/Mac/UpdateApp.sh` (dmg) and
`Installer/Linux/UpdateApp.sh` (`.deb` + `.tar.gz`) still apply — they copy the
built binary into their git-ignored staging trees. The companion can be bundled
alongside the binary the same way the Windows flow bundles it.
