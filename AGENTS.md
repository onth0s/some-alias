# AGENTS.md

- `wp` (and the Waypoint CLI it wraps) is documented elsewhere — do not
  document it in this repo's README or add Waypoint-related sections.
- NEVER rename, remove, or otherwise alter any alias or function name in the
  profiles. All aliases and function names are user-ratified and must stay
  exactly as they are. Internal refactors are fine only if public names,
  arguments, and behavior are preserved.
- NEVER touch absolute paths in the profiles unless explicitly told to do so by
  the user. Hardcoded paths are intentional and must stay exactly as they are.
