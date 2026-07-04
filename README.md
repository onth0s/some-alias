# some-alias

Personal PowerShell profile — custom aliases and utility functions for daily use.

## Contents

- `Microsoft.PowerShell_profile.ps1` — main profile with custom functions
- `profile.ps1` — conda-initialized profile (all-session)
- `.gitignore`

## Functions

| Function | Description |
|----------|-------------|
| `yt` | Smart yt-dlp wrapper with playlist awareness |
| `gotp` | `cd` to a path copied to clipboard |
| `stp` | Open a path from clipboard in Explorer |
| `gp` | Copy a path (arg or cwd) to clipboard |
| `op` | Launch opencode |
| `sf` | `sempath find` |
| `HH` | `hermes gateway run -v` |
| `uprof` | Reload `$PROFILE` |

---

### `yt` — Smart yt-dlp wrapper

Downloads from YouTube (or any yt-dlp-supported site) with interactive playlist
scanning and intelligent skip logic.

#### Usage

```powershell
yt [<url>] [-v | -video] [-s | -song] [<N>]
```

#### Modes

| Mode | Flag | Behaviour |
|------|------|-----------|
| **Song (default)** | *(none)* or `-s` / `-song` | Extracts audio, saves as MP3 with embedded thumbnail + metadata |
| **Video** | `-v` / `-video` | Downloads best video + best audio muxed together |

Both modes always embed thumbnail and metadata.

#### URL input

1. Pass the URL as the first argument.
2. If the first argument is a plain number (e.g. `25`), it is treated as `N`
   (playlist scan count) and the URL is read from clipboard.
3. If no URL argument is given, it reads the URL from clipboard automatically.

#### Playlist scan (`N > 0`)

When `N` is specified (or passed as a bare number), `yt` scans the first `N`
items of a playlist before downloading:

- **What it checks:** whether each item's video ID appears in any filename in
  the **current directory** (matched by `*[<videoId>]*`).
- **Already downloaded** → listed in green, skipped.
- **Missing** → listed in white, then prompts:
  > `Download these N songs? (Y/n)`
- **Already have everything** → prompts:
  > `Download next N after item N? (y/N)`
  Answering `y` downloads items `N+1` through `2N`.

#### Examples

```powershell
yt "https://youtube.com/playlist?list=..."    # download all as MP3
yt -v "https://youtube.com/watch?v=..."        # download single video
yt 10                                            # scan first 10 of URL from clipboard
yt "https://youtube.com/watch?v=..." -v -song   # explicit song mode (redundant)
```

---

### `gotp` — Go to path from clipboard

```powershell
gotp
```

Reads a file/directory path from clipboard, resolves it, and `cd`s into it.
If a file path is detected, navigates to its parent directory. Brackets `[]`
in paths are handled literally (no wildcard issues).

---

### `stp` — Show path from clipboard in Explorer

```powershell
stp
```

Same path resolution as `gotp`, but opens the target in Windows Explorer instead
of navigating in the terminal.

---

### `gp` — Get path (copy to clipboard)

```powershell
gp [<path>]
```

Copies the given path to clipboard. If no argument provided, copies the current
working directory. Strips surrounding quotes, backticks, and trailing file-size
annotations before copying.

---

### `op` — Launch opencode

```powershell
op [<args>...]
```

Shortcut for launching `opencode`.

---

### `sf` — sempath find

```powershell
sf [<args>...]
```

Shortcut for `sempath find`.

---

### `HH` — Hermes gateway

```powershell
HH [<args>...]
```

Shortcut for `hermes gateway run -v`.

---

### `uprof` — Reload profile

```powershell
uprof
```

Dot-sources `$PROFILE` to reload all functions without restarting PowerShell.
