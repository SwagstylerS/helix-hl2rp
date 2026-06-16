---
name: helix-lint
description: >-
  Lint Garry's Mod Lua in this HL2RP schema with glualint (GLuaFixer). Use to statically
  check changed or specified .lua files for syntax errors and style issues before committing.
  Runs glualint if it is installed on PATH; if it is not installed, explains the optional
  one-time binary install and degrades gracefully without blocking. Pairs with
  helix-convention-check (which covers the design rules glualint cannot see).
---

# Helix Lint (glualint)

Static analysis for this schema's GMod Lua. glualint understands GLua syntax (`!`, `&&`,
`||`, `!=`) that stock Lua linters reject, so it is the right tool here.

## Procedure
1. **Detect glualint:** run `command -v glualint`.
2. **If present:** lint the target.
   - Changed files: `git diff --name-only --diff-filter=ACM '*.lua'` then
     `glualint lint <files>` (or `glualint lint .` for the whole tree).
   - Summarize findings as `path:line — message`, grouped errors-first. glualint exits
     non-zero on lint errors — report them, do not crash.
3. **If absent:** do **not** fail. Print the optional install note below and suggest running
   `helix-convention-check` for the design-rule checks that don't need a binary.

## Optional one-time install (network permitting)
glualint is a prebuilt static binary from the GLuaFixer releases:
- Repo: https://github.com/FPtje/GLuaFixer/releases
- Linux example:
  ```sh
  curl -L -o /tmp/glualint.zip \
    https://github.com/FPtje/GLuaFixer/releases/latest/download/glualint-x86_64-linux.zip
  unzip -o /tmp/glualint.zip -d "$HOME/.local/bin" && chmod +x "$HOME/.local/bin/glualint"
  ```
  (Asset names change between releases — check the releases page for the current Linux asset.)
- The ephemeral web environment may block this download depending on the network policy; if
  so, run lint locally or in CI instead. Never make a session depend on this install.

## Optional config
A `glualint.json` at repo root can pin rules. None exists yet; add one only if the team
wants enforced style (keep it lenient — this codebase mixes layouts intentionally).

## Scope note
glualint catches syntax/style only. The server's hard rules (no chat commands for world
interaction, no gamey text, netstream preference, "HL2 RP" category) are enforced by
`helix-convention-check`, not glualint. Run both.
