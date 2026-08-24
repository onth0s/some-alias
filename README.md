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
| `Resolve-GotoUrl` | Internal helper: classify a `goto` target as URL or search |
| `Save-GotoStore` | Internal helper: write the goto alias store |
| `Find-GotoAlias` | Internal helper: exact-match lookup in the goto alias store |
| `op` | Launch opencode |
| `goto` | Open a URL in the browser, Google-search a string, or save/list/delete URL aliases |
| `sf` | `sempath find` |
| `sg` | `sempath get` (or `sempath <args>`) |
| `HH` | `hermes gateway run -v` |
| `alias` | Universal command lookup |
| `c` | Alias for `cls` (clear screen) |
| `ls` | GNU-style flags for `Get-ChildItem` (`-a -l -t -S -X -r -R`) |
| `cd` / `cd..` / `cd~` / `cd\` | Path navigation — feeds session + Waypoint persistent history |
| `cdh` | Display session history (list of recent directories) |
| `gs` | `git status` |
| `gsall` | Check git status of all repos under the tracked roots |
| `uprof` | Reload `$PROFILE` (auto-cleans removed functions) |
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
yt [<url>] [-c <cookies-file>] [-v | -video] [-s | -song] [<N>]
```

#### Modes

| Mode | Flag | Behaviour |
|------|------|-----------|
| **Song (default)** | *(none)* or `-s` / `-song` | Extracts audio, saves as MP3 with embedded thumbnail + metadata |
| **Video** | `-v` / `-video` | Downloads best video + best audio muxed together |
| **Cookies** | `-c <file>` | Pass a cookies file to yt-dlp (absolute or relative path) |

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
yt "https://youtube.com/..." -c cookies.txt     # pass cookies file
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

If the path doesn't exist, prints a warning (yellow) and `cd`s to the nearest
existing ancestor directory instead; errors only if none exists.

---

### `stp` — Show path from clipboard in Explorer

```powershell
stp
```

Same path resolution as `gotp`, but opens the target in Windows Explorer instead
of navigating in the terminal. Missing paths warn (yellow) and open the nearest
existing ancestor directory.

---

### `gp` — Get path (copy to clipboard)

```powershell
gp [<path>]
```

Copies the given path to clipboard. If no argument provided, copies the current
working directory. Strips surrounding quotes, backticks, and trailing file-size
annotations before copying. If the path doesn't exist, warns (yellow) and copies
the nearest existing ancestor directory instead; errors only if none exists.

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
- `Get-NearestExistingPath` — walks up a nonexistent path until it finds
  something that exists (`C:\a\b\c` → `C:\a` when only `C:\a` exists); returns
  `$null` if nothing exists before the drive root. Fallback engine behind the
  missing-path handling in `gp`, `gotp`, and `stp`.

---

### `op` — Launch opencode

```powershell
op [<args>...]
```

Shortcut for launching `opencode`.

---

### `goto` — Open URL, Google search, or URL aliases

```powershell
goto [<url-or-search>] [-a <NAME> | --add-alias <NAME>]
                        [-d <NAME> | --del-alias <NAME>] [-ls | --list-alias]
```

A smarter browser `start`: detects whether the argument is a URL or a search
string.

- **URL** — scheme-URLs (`https://…`) open as-is; `www.…`, bare domains
  (`google.com`, `reddit.com/r/pics`), and `localhost`/IP addresses get the
  appropriate scheme prepended.
- **String** — anything else (e.g. `goto how to make omelete`) opens a Google
  search for the text. Quotes optional.
- **No args** — opens the clipboard contents (whitespace-collapsed and
  trimmed): a URL, an alias name, or search text. Errors on an empty
  clipboard. `-h` / `--help` prints usage help.
- **`-a <NAME>` / `--add-alias <NAME>`** — opens the target *and* saves it as a
  URL alias. Later, `goto <NAME>` opens the saved URL directly. Names are
  case-sensitive (letters, digits, `-`, `_`); `goto X` and `goto x` are
  distinct aliases, and re-using an existing name asks for confirmation before
  overwriting.
- **`-d <NAME>` / `--del-alias <NAME>`** — deletes a saved alias after
  confirmation.
- **`-ls` / `--list-alias`** — lists all saved aliases (`name -> url`).

Aliases persist in `$HOME\.goto-aliases.json` (a JSON `name -> url` map, created
on first use). A template with the format is committed as
`goto-aliases.example.json`.

#### Examples

```powershell
goto google.com                                      # opens https://google.com
goto localhost:3000                                  # opens http://localhost:3000
goto how to make omelete                             # Google search
goto onth0s.github.io/markdown-viewer -a MD          # opens + saves alias MD
goto MD                                              # opens the saved URL
goto                                                    # opens the clipboard URL/text
goto -a MD                                            # opens clipboard URL + saves alias MD
goto -ls                                             # list aliases
goto -d MD                                           # delete alias MD
```

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

### `ls` — GNU-style listing flags

```powershell
ls [-a] [-l] [-t] [-S] [-X] [-r] [-R] [-? | --help] [<path>...]
```

Shadow of the built-in `ls` alias (`Get-ChildItem`). With no flags it behaves
exactly like plain `Get-ChildItem`; any unrecognized argument (e.g. `-Force`,
`-Filter *.txt`) is passed straight through. Short flags can be combined into
one token (`ls -ltr`).

| Flag | Meaning |
|------|---------|
| `-a` | Include hidden/system files (`-Force`) |
| `-l` | Long listing (`Mode LastWriteTime Length Name`) |
| `-t` | Sort by last-write time, newest first |
| `-S` | Sort by size, largest first |
| `-X` | Sort by extension, then name |
| `-r` | Reverse the sort order |
| `-R` | Recurse into subdirectories |
| `-?`, `--help` | Show usage help |

Directories are grouped first whenever sorting is applied; `-r` reverses the
sort within each group.

---

### `uprof` — Reload profile

```powershell
uprof
```

Dot-sources `$PROFILE` to reload all functions without restarting PowerShell.
Before re-sourcing, it parses the profile's AST and removes any functions
that no longer exist, so stale definitions don't linger after edits.

---

### `cd` / `cd..` / `cd~` / `cd\` — Path navigation with history

```powershell
cd [<path>]          # cd alone goes to ~
cd -                 # toggle to the previous directory
cd..                 # parent directory (no space)
cd~                  # home directory (no space)
cd\                  # root directory (no space)
```

Built-in `cd`/`chdir` are overridden so every directory change feeds a two-layer
history:

- **Session history** — in-memory list (last 50 directories), viewable via `cdh`.
  `cd -` toggles to the most recent previous entry.
- **Persistent stack** — written to Waypoint on every jump. A fresh tab can pick
  up where the last tab left off with `wp h` or `wp u 0`.

`cd..`, `cd~`, and `cd\` are single tokens that PowerShell resolves directly to
`Set-Location`, bypassing the `cd` alias. They are defined as functions so they
route through the same history mechanism instead of being silent.

---

### `cdh` — Session history

```powershell
cdh
```

Prints the in-memory directory history (same list that `cd -` pulls from).

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
No fallback: if nothing valid is found, it fails with an error.

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
npm notice noise from `npx` is suppressed.

---

### `xxx` — Exit session

```powershell
xxx
```

Shortcut for `exit`. (`exit` is a keyword, not a command, so this is a function rather than an alias.)

---



### `gsall` — Check all repos

```powershell
gsall
```

Runs `check-repos.ps1`, which scans three roots — `00__DEV`, this repo
(`Documents\WindowsPowerShell`), and the Blender startup scripts dir
(`...\Blender 5.2\5.2\scripts\startup`) — recursively up to depth 3, and reports
each git repo's status as `CLEAN` or `DIRTY`. Repos nested under `node_modules`
and repos ignored by a parent repo (via that parent's `.gitignore`) are skipped.
Prints a summary line (`N repos (X dirty, Y clean) - Zs`) followed by a table
with the tracked file count per repo.

