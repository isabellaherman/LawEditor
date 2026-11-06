# LawEditor

Write rules in plain sentences; an agent (Claude or Codex) turns each one into a [Bend](https://github.com/bendlang/bend) **law**, and Bend checks it.

Everything is Bend: the server (`server.bend`), the editor's logic (`EDITOR.bend`, with its own rules in `LAWS.bend`), and the look ([Bend-UI](https://github.com/isabellaherman/Bend-UI)). JS only reads input and draws.

## Run

You need [Bend](https://github.com/bendlang/bend) (`bend` on your PATH), [Bun](https://bun.sh), and `claude` (Claude Code) or `codex` installed and logged in.

```bash
bun install
bun run start
```

Open http://127.0.0.1:4280. Your project lives in `project/`: `GDD.md` (your sentences), `TYPES.bend` (what the laws talk about) and `LAWS.bend` (the laws). To use another folder, run the server from it:

```bash
bun run build
cd ~/my-project
bend /path/to/LawEditor/server.bend /path/to/LawEditor/dist /path/to/LawEditor/AGENT.md
```

## How it works

1. Write a rule and press Enter. It gets an empty dot.
2. Pick an AI in the agent (click the face) and press **Generate LAWs**.
3. For each sentence, the agent adds what's missing to `TYPES.bend`, appends one law to `LAWS.bend`, and checks it with `bend LAWS.bend --check-only`. The server checks again.
4. Green: the law compiles (a law with no proof yet is fine). Red: it doesn't, or the agent couldn't write one; the message says why.

**Laws** shows every law and definition. Deleting a sentence never deletes its law: the law turns amber until you remove it. To edit, hold the lock.

**Context** shows `AGENT.md`, exactly what the agent is told. Read only.

**Chat** talks with the AI you picked. It reads your project and never edits it; it's told what Context shows.

## Files

| File | What it is |
|---|---|
| `server.bend` | The server: serves the page, keeps the project files, runs the agent |
| `EDITOR.bend` | The editor's logic (line states, when Generate is on) |
| `CHAT.bend` | The chat's logic (who wrote a message, when Send is on) |
| `LAWS.bend` / `PROOF.bend` | The editor's own rules and their proofs (`bun run check`) |
| `AGENT.md` | What the agent is told |
| `web/` | The page: `index.html` (Bend-UI classes only) and `main.js` and `chat.js` (draw). No CSS of its own |

Agent instructions for this repo: [`AGENTS.md`](AGENTS.md).
