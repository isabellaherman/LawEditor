# Harness

What the chat may do, and when it asks. Works the same with any AI.
The rules live in POLICY.bend; LAWS.bend checks them.

## Modes

The person picks one under the message field. It starts on "Only read".
"Ask before changes" works with Claude only: Codex can't ask yet. "Change freely" comes later.

| What the chat does    | Only read | Ask before changes | Change freely |
|-----------------------|-----------|--------------------|---------------|
| Read files            | Yes       | Yes                | Yes           |
| Edit or create files  | No        | Asks               | Yes           |
| Run commands          | No        | Asks               | Asks          |
| Change LAWS.bend      | Never     | Never              | Never         |

## When it asks

The chat tries; what its mode doesn't allow is refused, and it says what it wanted.
The person answers: Allow, Always allow (this session), or Don't allow.
Until they answer, the talk waits. Then the same conversation goes on (ASK.bend).

## Checked by

chat_only_reads, chat_claude_reads, chat_codex_reads, chat_never_changes

## Ideas from

- Claude Code: a mode picker under the field; asking before an action; rules per tool.
- Codex: a read-only mode as the safe start.
- Hermes: allow once, for the session, or never.
