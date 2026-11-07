# Changelog

Versions stay at 0.x until the MVP.

## Unreleased

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
