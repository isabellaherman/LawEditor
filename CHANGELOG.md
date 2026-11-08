# Changelog

Versions stay at 0.x until the MVP. Each iteration raises the last digit.

## Next

What the person asked for, as goals. Each one becomes an iteration when it's picked.

- The chat shows its answer while it writes it, as Claude does.
- The chat answers fast.
- The game the chat builds follows the laws: Bend checks the game itself, not only `TYPES.bend`.
- The chat proposes only sentences that are rules.
- Codex asks before changes too.

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
