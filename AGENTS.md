# AGENTS

- The look comes from `bend-ui` (github.com/isabellaherman/Bend-UI). Read its README before touching UI.
- Use the lib's components and tokens. `web/editor.css` holds layout only, with `var(--...)`; no loose numbers.
- Need a value or component the lib lacks? Don't edit `node_modules`. Add it to Bend-UI first, then pull it here.
- Logic goes in `.bend` files (`EDITOR.bend`, `server.bend`). JS only reads input and draws what Bend returns.
- Learn Bend with `bend guide`. Don't invent syntax.
- `LAWS.bend` holds the editor's own rules; it changes only with the repo owner's approval. Run `bun run check` before every commit.
- A design is approved as an artifact first; show the build to the repo owner before committing.
- Everything in English.
- No AI attribution in commits or PRs.
