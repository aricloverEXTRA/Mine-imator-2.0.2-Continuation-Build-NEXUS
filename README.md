# Mine-imator

<p align="center">
  <img src="https://www.mineimatorforums.com/uploads/monthly_2021_08/image.png.4699187f1f02be8222a5bf5100c1738f.png" width=800/>
  <br/>
  <br/>
  <img src="https://www.mineimatorforums.com/uploads/monthly_2023_03/336815532_programview.png.9212aa1f6d1bed63411408aa5e905ce0.png" width=800/>
</p>

Mine-imator is a 3D movie maker based on the sandbox game Minecraft, with over 8 million downloads since its launch in 2012. Version 2.0, the 10th anniversary update brings numerous additions including a new UI, new renderer, animation features, multiplatform support and 3D world importer.

Website and download: https://www.mineimator.com

The software is written using GameMaker Language and converted to a separate C++ environment using a custom built GML parser (CppGen). The final executable is built for Windows, Mac OS and Linux using the Qt framework, DirectX/OpenGL rendering and various other libraries.

---

# Building Mine-imator from source — the simple guide (Windows)

> **New here? Don't worry.** This page explains *why* and *how* to turn the
> source code in this repository into a program you can actually run
> (`Mine-imator.exe`) and then into a clean, shareable `.zip` — in plain
> English, step by step.

## Do you even need to build it?

| Your goal | What to do |
| --------- | ---------- |
| Just **use** Mine-imator | Skip this page — download it from <https://www.mineimator.com> |
| Use the **Nexus** build (with the AI Assistant) without building | Grab the pre-built release `.zip` instead |
| **Modify the code** or make your own build | Keep reading — this page is for you |

Building is only needed when you want to change the source code (this
repository) and see your changes in the program. It is **not** something
regular users ever need to do.

## The 30-second version

There are two separate jobs, and only the first one is heavy:

1. **Build `Mine-imator.exe`** — one-time setup of the "toolchain" (the free
   programs that turn C++ code into a running app), run **CppGen** to turn the
   game's GML scripts into C++, then click **Build** in Visual Studio. This
   step needs a powerful PC and takes a while.
2. **Package the `.zip`** — a one-line command. The included helper script does
   *everything* (copies the exe, the game data, the AI companion, and zips it
   into a clean release folder).

**Building the .exe is the hard part. Making the .zip is the easy part.**

---

## Step 1 — What "building the .exe" actually means

Mine-imator's game logic is written in **GML** (GameMaker Language). A custom
tool in this repo called **CppGen** automatically converts that GML into
**C++** code. But C++ code alone is just text — it still needs to be *compiled*
into an executable file. That compiling is done by a collection of free
programs that developers call a **toolchain**:

- **Visual Studio 2022** — the compiler + editor you'll click "Build" in.
- **CMake** — the "glue" that reads the project settings and generates the
  Visual Studio project for you.
- **Qt 5.15.9** — a huge library of ready-made features (windows, buttons,
  rendering) that Mine-imator uses. This fork needs it **built from source**
  once — that's the long, one-time step.
- **.NET SDK** — the small "engine" that runs **CppGen** (the GML → C++
  converter you run in Step 3).
- **Python / Strawberry Perl / OpenSSL / Jom** — smaller helpers the build uses
  along the way.

## Step 2 — Install the tools (one time, ~1 hour)

Follow the official build guide at **`CppProject/BUILD.md`** for exact commands.
Here is the plain-English summary:

1. **Set the `DEV_DIR` environment variable to `C:\Dev`.** The build guide
   uses this folder for everything below (OpenSSL, Jom, Qt). In Windows:
   Start menu → type *"environment variables"* → *"Edit the system
   environment variables"* → *Environment Variables...* → add a new **User
   variable** `DEV_DIR` with the value `C:\Dev`.
2. **Install Visual Studio 2022.** During installation tick *"Desktop
   development with C++"* and *"MFC for latest v143 build tools"*.
3. **Install CMake** from <https://cmake.org/download/>.
4. **Install Python** from <https://www.python.org/downloads/> — when asked,
   tick **"Add Python to PATH"** (this matters!).
5. **Install Strawberry Perl** from <https://strawberryperl.com/>.
6. **Install OpenSSL** into `C:\Dev\OpenSSL` (choose 64-bit, and when asked,
   copy the DLLs to `bin`).
7. **Install Jom** (Qt's parallel build helper) — extract the zip into
   `C:\Dev\Jom` and add that folder to your PATH (same environment-variables
   window as step 1).
8. **Build Qt 5.15.9 from source** — this is the long one (hours, but only
   *once*). The guide walks you through cloning Qt 5.15, running its
   configuration script, then `jom` + `jom install`. When you're done you'll
   have it installed in `C:\Dev\Qt\5.15.9`.
9. **Install the .NET SDK** from <https://dotnet.microsoft.com/download> — the
   "engine" that runs CppGen (see Step 3).

> ☕ **Tip:** Qt is the only step that takes hours. Everything else is quick.
> Grab a coffee and let it run.
>
> 💡 **Good news about the other libraries:** the build guide also lists
> Libzip, FreeType, FFmpeg and OpenAL — but those are already pre-built and
> shipped inside this repo at `CppProject\External\Win64`. You don't need to
> download or build them; **Qt is the only library you build from source.**

## Step 3 — Generate the C++ code, then build the exe

1. **Generate the C++ code with CppGen.** Open a terminal *in this
   repository's folder* and run:

   ```powershell
   dotnet run --project CppGen\CppGen\CppGen.csproj -- GmProject CppProject\Generated CppProject\Asset\Sprites CppProject\Asset\Shaders CppGen\gml.json
   ```

   When it finishes you should see **`Success!`**. This creates the C++ source
   files (`CppProject\Generated`) and the game's images
   (`CppProject\Asset\Sprites`) that the next step will compile.

   > 🔁 Re-run this command any time you change a GML script, so the C++ code
   > stays in sync with the game logic.

2. Open **CMake GUI**.
3. Set **"Where is the source code"** to the `CppProject` folder in this repo.
4. Set **"Where to build the binaries"** to a build folder of your choice
   (for example `C:\Dev\Projects\Mine-imator-build`).
5. Click **Configure** (choose *Visual Studio 17 2022*), then **Generate**,
   then **Open Project**.
6. In Visual Studio, copy the contents of `GmProject\datafiles` into your
   build folder (the guide explains this — the app reads its data from there
   during development).
7. At the top, change the dropdown from *Debug* to **Release**, then press
   **Build** (or `Ctrl+Shift+B`).

When it finishes, your freshly-built program is here:

```
<your build folder>\Release\Mine-imator.exe
```

That's your **Step 1 done** — you have built the actual program. ✅

> The detailed, copy-paste version of everything above (including the exact Qt
> commands and 32-bit / Mac / Linux instructions) lives in
> [`CppProject/BUILD.md`](CppProject/BUILD.md).

---

## Step 4 — Package the `.zip` release (the easy part)

This fork ships a helper script, **`make-release.ps1`**, that packages the
release exactly like the official mbanders build — **no WinRAR or extra
installs needed**.

Open a **PowerShell** window in this repository's folder and run:

```powershell
powershell -ExecutionPolicy Bypass -File .\make-release.ps1 "2.0.2 Nexus 1.0.0" -BuildDir C:\Dev\Projects\Mine-imator-build
```

That's it. The script:

1. Copies your built `Mine-imator.exe` + the `vcomp140.dll` it needs,
2. copies the game data (`Data\` and `Particles\`) straight from
   `GmProject\datafiles`,
3. bundles the **AI companion** (the AI Assistant feature) plus a
   `Start AI Companion.bat` launcher,
4. adds an empty `Projects\` folder (Mine-imator's first-run save area),
5. and zips it all into a tidy, versioned release:

```
Builds\Mine-imator 2.0.2 Nexus 1.0.0.zip
```

### What's inside the .zip

```
Mine-imator 2.0.2 Nexus 1.0.0\
├─ Mine-imator.exe          <- the program (double-click to run!)
├─ vcomp140.dll             <- a small helper library the exe needs
├─ Start AI Companion.bat   <- starts the AI Assistant (Nexus feature)
├─ Projects\                <- empty; where Mine-imator saves your work
├─ Data\ ... Particles\ ... <- the game's textures, sounds, fonts, etc.
└─ companion\               <- the AI Assistant (Python, no install needed)
```

To **use** it: unzip anywhere, double-click `Mine-imator.exe` — done.

### Useful switches

| Switch | What it does |
| ------ | ------------ |
| `"2.0.2 Nexus 1.0.0"` | The release name (used in the zip and folder name). Defaults to `2.0.2 Nexus`. |
| `-BuildDir <path>` | Where your built exe lives (the folder that *contains* `Release\Mine-imator.exe`). |
| `-Win32` | Package the 32-bit build instead of 64-bit. |
| `-SkipCompanion` | Don't bundle the AI companion. |
| `-SkipInstaller` | Don't try to build the optional setup installer. |
| `-UseWinRAR` | Use WinRAR instead of the built-in zip (only if you installed WinRAR). |

If you have **Inno Setup 6** installed, the script also produces a
`... installer.exe` — the kind of installer you'd normally download from a
website. That part is optional.

---

## Troubleshooting (quick fixes for common hiccups)

- **"Built executable not found"** — you ran the script before building, or
  gave the wrong `-BuildDir`. Build the exe first (Step 3), then pass the
  correct folder with `-BuildDir`.
- **PowerShell refuses to run the script ("execution policy")** — that's a
  Windows safety feature. Run it with the `-ExecutionPolicy Bypass` prefix as
  shown above.
- **The build takes forever / my PC is slow** — building Qt is the heavy part;
  only the first build is slow. Later rebuilds are much faster (Visual Studio
  only recompiles what changed).
- **Windows shows a "SmartScreen" warning when I run my own exe** — normal.
  It happens because the program isn't signed with a paid certificate. Click
  "More info" → "Run anyway". It's your own build — it's safe.
- **`git clone` / Qt errors** — make sure you're following `CppProject/BUILD.md`
  exactly, including the extra helper tools (Perl, OpenSSL) before Qt.

---

## I'd rather not build at all

No problem. If you just want to *use* Mine-imator:

- **Official builds:** <https://www.mineimator.com>
- **This fork (Nexus) with the AI Assistant:** use the pre-built release `.zip`.

Building from source is only for people who want to **modify the code** — which
is exactly what makes open-source fun. 😄
