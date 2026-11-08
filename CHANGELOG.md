# Changelog

Versions stay at 0.x until the MVP. Each iteration raises the last digit.

## Next

What the person asked for, as goals. Each one becomes an iteration when it's picked.

- The chat answers fast.
- The game the chat builds follows the laws: Bend checks the game itself, not only `TYPES.bend`.
- The chat proposes only sentences that are rules.
- Codex asks before changes too.
- Codex's answer comes without its own notice ("Reading additional input from stdin...").
- When a project is done, the chat shows a link that opens its folder on the computer.

## 0.1.5 (2026-11-08)

- **Debug screen** (side bar › Debug, to remove later): LawEditor's own `LAWS.bend`, exactly as the file is, and the output of `bend PROOF.bend`, run by the server each time the screen opens (`GET /api/debug/LAWS.bend`, `GET /api/debug/check`). Nothing on it is typed by hand: a law added, changed or removed shows there as it is, and a law that fails shows Bend's own error.

## 0.1.4 (2026-11-07)

- **The chat offers the mode** (`OFFER.bend`, flow A of the four drawn on 2026-11-07). In Only read, when the person wants something built, the chat ends its reply with `MODE: "Ask before changes"`; the page asks Switch / Stay. Switch moves the picker and sends the request again; in Ask before changes the chat writes the smallest version to play first, says how to open it, and asks one question. Stay keeps Only read.
- **The flow is the source, and it is checked.** `OFFER.flow()` is drawn in Chat › Context by Bend-UI's diagram. New laws (`LAWS.bend`, proved in `PROOF.bend`): `offer_flow_is_whole`, `offer_flow_skill_then_system`, `offer_flow_writes_need_you`, `stay_keeps_only_read`, `switch_asks_first`, `reply_hides_offer`.
- **Validated in the app against the diagram**, "quero um jogo de plataforma so andar pro lado":

  | Step | Seen |
  |---|---|
  | You ask for something to be built | Sent in Only read |
  | The chat ends its reply with MODE: | Yes, with a rule (first try missed it: "I want a game" read as a description; the Only read text now says wanting a game means building it) |
  | Switch to Ask before changes? | Card shown, talk stopped |
  | The picker moves; the request goes again | Picker on Ask before changes; a new reply started |
  | The chat writes the smallest version | `plataforma.html` (canvas, arrows or A/D) |
  | Claude refused, question | Allow card with the file |
  | Write it; how to open it; one question | Written; "clique duplo nele"; one question about the screen edge |
  | Stay, Don't allow | Not clicked in this run (Stay is proved by `stay_keeps_only_read`) |

- **Known:** the Allow card shows the whole file, so a game makes it long. The offer card and a rule card can wait at the same time, and answering one frees the message field. The first answer took about 30 s (the chat reads the project first).

## 0.1.3 (2026-11-07)

- **The chat shows its answer while it writes it** (Claude). Claude runs with `--include-partial-messages` and its output goes to a file for the turn (`/tmp/laweditor-turn-<id>.jsonl`; the id keeps only letters and digits). The page asks `GET /api/progress/<id>` every 300 ms and draws the text so far; `ASK.bend` reads it (the message being written now). Codex still answers all at once. Measured: the first words show about 3 s after sending, instead of the whole answer at the end.
- **The server runs compiled** (`bun run start` builds `dist/laweditor-server`). Run as `bend server.bend`, Bend waits for a program to finish before it answers anything else, so the page couldn't ask for the answer so far; the compiled server answers while Claude works.

## 0.1.2 (2026-11-07)

- **The chat builds, and says how.** `CHAT.md` says the chat helps build the project as far as its mode allows, and hears its rules. In Only read, asked to build or change something, it says it can once the person picks Ask before changes (as Claude Code does when a mode blocks it), never that it isn't its job. Tested: "cria um jogo da velha que é impossivel perder e tem grafico de gameboy" in Only read now answers "Posso criar o jogo quando você escolher Ask before changes".
- **The chat runs apart from the person's own Claude Code** (`--safe-mode`, `Policy.claude_isolation`): their CLAUDE.md, plugins, hooks and memory don't reach it, and it starts in about half the time (a bare "oi": about 5.4 s before, 2.4 s now). Asking, Allow and the LAWS.bend refusal work the same.
- Not the cause: the person's connectors (Gmail, Drive…) never load in the chat.

## 0.1.1 (2026-11-07)

- **Fix: Allow didn't let the chat write a file.** Two causes, both in `ASK.bend`. (1) A new or rewritten file comes from Claude's Write tool, and the app allowed it as `Write(//path)`; Claude doesn't take that rule, so Write stayed refused. Claude's file rules are all `Edit(…)`, which covers Write: the grant is now always `Edit(//path)`. (2) Claude's refusal tells it "don't retry, it will be refused for the rest of this session"; told only "Go ahead", it gave up after a few tries. The resume now says what was allowed and that the earlier refusal no longer applies. Tested in the app: "Create a new file TEST.md", Allow, the file is written. The question for Write says "write", not "create" (it may be an existing file).
- **The version** shows at the window's bottom-right (a `tag`, from `package.json`); "Made with Bend-UI" stays alone at the left. Bend-UI 1.0.3 (`.window__foot--end`).
- **The chat knows what a rule is** (`HEAR.md`): one fact that can be checked. "What exists or what someone can do", two things in one sentence, and vague words are not rules yet. With something vague, the chat proposes its clear meaning, or asks one plain question with options and waits. Tested: "eu quero criar um jogo 2D onde eu ando e atiro" gave "Quando o jogador anda, a posição dele muda" (its law compiles) and a question about shooting; the answer "aparece uma bala e a munição diminui" gave two rules.
- **Known issue:** the chat can still propose a sentence that isn't a rule. The skill is a prompt, not a check, so it improves the odds but doesn't guarantee it. When it happens, the law agent refuses the sentence and says why; nothing invalid is written. Seen again on 2026-11-07, after the fix.

## 0.1.0 (2026-11-07)

The chat and the laws talk.

- **The chat hears rules** (`HEAR.md`, `HEAR.bend`): it ends its reply with the rules it heard; each becomes a question (Add, Always add, Don't add), and an added sentence gets its law.
- **The chat's modes** (`POLICY.bend`, `HARNESS.md`), picked under the message field:
  - **Only read**, the start: it reads and changes nothing.
  - **Ask before changes**, Claude only (`ASK.bend`): what it isn't allowed is refused and turned into a question (Allow, Always allow, Don't allow); the same conversation goes on with what the person allowed.
  - `LAWS.bend` is refused in every mode.
- Chat › Context shows `HARNESS.md`: what the chat may do in each mode, and when it asks.
- Bend 2.0.40 added `Tool` to Base, so the policy's types are `AgentTool` and `Agent`, with qualified constructors.
- **Known:** Codex can't ask yet (Ask before changes is off with Codex). The version in the window's bottom-right waits for a footer slot in Bend-UI.
