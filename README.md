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
| `opf` | Open a path (arg or clipboard) |
| `gp` | Copy a path (arg or cwd) to clipboard |
| `ConvertFrom-ClipboardPath` | Internal helper: normalize path text |
| `Resolve-PathString` | Internal helper: resolve a path string to a full path |
| `op` | Launch opencode |
| `sf` | `sempath find` |
| `sg` | `sempath get` (or `sempath <args>`) |
| `HH` | `hermes gateway run -v` |
| `alias` | Universal command lookup |
| `c` | Alias for `cls` (clear screen) |
| `gs` | `git status` |
| `gsall` | Check git status of all repos under `00__DEV` |
| `codex` | Launch ollama codex model |
| `uprof` | Reload `$PROFILE` |
| `upkey` | Restart AutoHotkey (stop all AHK processes, relaunch `STD_HotKeys.ahk`) |
| `ow` | Manage OpenWhispr pm2 services (start/restart, or `nuke`) |
| `tree` | Directory tree (ignores `node_modules`/`.next`) |
| `xxx` | Exit the session |

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

### Path helpers (`ConvertFrom-ClipboardPath`, `Resolve-PathString`)

Internal functions shared by `gp`, `gotp`, `stp`, and `opf`; not meant to be
called directly.

- `ConvertFrom-ClipboardPath` — single source of the path-text cleaning used by
  the clipboard utilities: strips quotes and backticks, leading terminal junk
  (`-`, `>`, `*`, `#`, checkmarks, `Success: Found match:` prefixes), trailing
  `[<size>, <date> <time>]` metadata annotations, expands `~` to the user
  profile, and trims whitespace.
- `Resolve-PathString` — resolves a path string to a full path: kept as-is when
  already rooted, resolved via `Resolve-Path` when it exists, otherwise joined
  to the current directory.

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

### `alias` — Universal command lookup

```powershell
alias [<name>]
```

Looks up any alias, function, or cmdlet and shows its definition. With no
arguments, lists all aliases. Works as a replacement for `Get-Alias` which
only finds aliases, not functions.

---

### `uprof` — Reload profile

```powershell
uprof
```

Dot-sources `$PROFILE` to reload all functions without restarting PowerShell.

---

### `upkey` — Restart AutoHotkey

```powershell
upkey
```

Stops all running AutoHotkey processes, waits ~300 ms for memory to clear, then
relaunches `STD_HotKeys.ahk`.

---

### `opf` — Open path (arg or clipboard)

```powershell
opf [<path>]
```

Opens a file or directory. With no argument, tries the clipboard: strips ANSI
escape codes, terminal prefixes, and trailing file-size/metadata annotations,
and tries single lines plus space-/newline-joined candidates before giving up.

---

### `sg` — sempath get

```powershell
sg
```

Runs `sempath get` with no arguments, or passes any given arguments straight to
`sempath`.

---

### `ow` — Manage OpenWhispr pm2 services

```powershell
ow          # start or restart openwhispr + openwhispr-preview
ow nuke     # stop and delete both pm2 services
ow kill     # stop and delete both pm2 services (alias of nuke)
```

Checks the pm2 status of `openwhispr` and `openwhispr-preview`:

- **Both online** → restart both
- **Both offline** → start both
- **Mixed** → restart both

`ow nuke` (and `ow kill`) stops and deletes both services entirely.

---

### `tree` — Directory tree

```powershell
tree [<args>...]
```

Renders a directory tree via `tree-node-cli`, ignoring `node_modules` and `.next`.

---

### `xxx` — Exit session

```powershell
xxx
```

Shortcut for `exit`. (`exit` is a keyword, not a command, so this is a function rather than an alias.)

---

### `codex` — Launch ollama codex model

```powershell
codex [<args>...]
```

Shortcut for `ollama launch codex --model minimax-m3:cloud`.

---

### `gsall` — Check all repos

```powershell
gsall
```

Runs `check-repos.ps1`, which scans two roots — `00__DEV` and this repo
(`Documents\WindowsPowerShell`) — recursively up to depth 3, and reports each
git repo's status as `CLEAN` or `DIRTY`. Repos nested under `node_modules` and
repos ignored by a parent repo are skipped. Prints a summary line
(`N repos (X dirty, Y clean) - Zs`) followed by a table with the tracked file
count per repo.

