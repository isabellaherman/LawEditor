# LawEditor's engine: the law agent. It writes one sentence's law in a project, and Bend checks it.
# What it may do comes from harness/POLICY.bend; what it is told, from harness/AGENT.md.

import Base
import ./SYS.bend as Sys
import ../harness/POLICY.bend as Policy

# The command line for each AI.
# Codex has no per-command allowlist: in its workspace-write sandbox it may run any command in the folder.
def args.pick(is_codex: Bool, prompt: String) -> List<String>:
  match is_codex:
    case True{}:
      ["exec", "--skip-git-repo-check", "--sandbox", Policy.codex_sandbox(Policy.law_agent()), prompt]
    case False{}:
      ["-p", prompt, "--allowedTools", Policy.claude_tools(Policy.law_agent()), "--permission-mode", "acceptEdits"]

def args(+ai: String, prompt: String) -> List<String>:
  args.pick(String.eq(ai, "codex"), prompt)

# Bend checks the laws. A law that compiles but has no proof yet is fine (a TODO); an error points at a
# Location. Answers "ok" or "error" on the first line, then the law, or why not.
def reply(agent: U32 & String, check: U32 & String) -> String:
  (+acode, +aout) = agent
  (ccode, +cout) = check
  Sys.pick(U32.is_eq(acode, 127), "error\nCould not start the agent: " ++ aout,
  Sys.pick(String.starts_with(aout, "ERROR"), "error\n" ++ aout,
  Sys.pick(String.contains(cout, "Location:"), "error\n" ++ cout,
  Sys.pick(String.contains(aout, "law "), "ok\n" ++ aout,
  "error\nThe agent answered without a law:\n" ++ aout))))

# One law agent at a time in a project: two would write LAWS.bend over each other. The second waits for
# the first (a folder is the lock; the server clears it when it starts). A project with no law yet gets
# its LAWS.bend here, empty: the agent only ever adds to it.
def locked_sh() -> String:
  "cd \"$0\" || exit 1; until mkdir .laweditor/lawlock 2>/dev/null; do sleep 0.3; done; trap 'rmdir .laweditor/lawlock' EXIT; [ -e LAWS.bend ] || printf 'import Base\\n' > LAWS.bend; \"$@\""

def write(+cx: Sys.Ctx, +dir: String, +ai: String, sentence: String) -> IO(String):
  do IO<String>:
    rules : String <- Sys.read_file(Sys.told(cx, "AGENT.md"))
    agent : U32 & String <- Sys.run_quiet("sh", "-c" <> locked_sh() <> dir <> ai <> args(ai, rules ++ "\n\n## Sentence\n\n" ++ sentence), 600000)
    check : U32 & String <- Sys.run_in(dir, "bend", ["LAWS.bend", "--check-only"], 120000)
    return reply(agent, check)

def good(+r: String) -> Bool:
  String.starts_with(r, "ok\n")

# What the law agent answered, without its first line.
def text(+r: String) -> String:
  String.trim(String.drop(r, String.length(Sys.nth(String.lines(r), 0n))))
