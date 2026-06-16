# Vendored Third-Party Skills

These skills were copied (vendored) into `.claude/skills/` so they ship with the repo and
load offline in fresh/ephemeral Claude Code sessions. Each retains its upstream `LICENSE`.

| Skill folder(s) | Upstream | License | Vendored commit | Date |
|---|---|---|---|---|
| `ponytail`, `ponytail-review`, `ponytail-audit`, `ponytail-help`, `ponytail-debt` | https://github.com/DietrichGebert/ponytail (`skills/`) | MIT | `99139a2` | 2026-06-16 |
| `council-review` | https://github.com/ngmeyer/council-review | MIT | `e9a9ee3` | 2026-06-16 |

## Notes
- **ponytail** — "lazy senior dev" mode: forces the simplest solution that works (YAGNI,
  stdlib first, no unrequested abstractions). Good gate before `helix-scaffold` on net-new
  features. We vendored the **skills only**; the upstream JS **hook runtime** (persistent
  mode / statusline) was intentionally omitted to avoid wiring third-party hooks into
  `settings.json`. The skills are fully usable invoked directly (`/ponytail`,
  `/ponytail-review`, etc.); only cross-turn mode persistence is lost.
- **council-review** — structured multi-perspective deliberation for hard design decisions
  (e.g. "entity vs. terminal action for detainee release"). Implements **Andrej Karpathy's
  LLM Council** pattern as Diverse Multi-Agent Debate (DMAD): 5 advisors with distinct
  reasoning methods collaborate, peer-review anonymously, and a chairman synthesizes a
  verdict. Self-contained — runs entirely inside one Claude Code agent, **no external LLM
  providers/keys needed**. Invoke with `/council-review`, "run the council", "pressure-test
  this". (Karpathy's own `karpathy/llm-council`, ~21k★, is a standalone FastAPI/React web app
  that needs an OpenRouter key — not a drop-in skill — so this faithful skill port is used.)
- **gmod-addon-maker** (github.com/davila7/claude-code-templates) was **not** vendored as a
  skill — it is generic GMod (not Helix-aware) and would compete with `helix-scaffold` for
  triggers. Only its realm/guard rules were adapted into
  `helix-api-reference/references/gmod-realms.md`, with attribution there.

## Updating
Re-clone upstream and copy the `skills/<name>` folder again; update the commit hash and date
above. Keep the `LICENSE` file in each vendored folder.
