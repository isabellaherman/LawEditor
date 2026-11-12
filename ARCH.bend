# LawEditor: the harness as it is today, as a FLOW.bend flow (who acts where).
# The words that name a setting (modes, flags, tools, what the chat may never touch) are read
# from POLICY.bend, so they change when the code changes. DIAGRAMS.bend draws it.

import Base
import ./FLOW.bend as F
import ./POLICY.bend as P

def modes() -> String:
  String.join([P.mode_name(0), P.mode_name(1), P.mode_name(2)], " / ")

def codex_asks.at(asks: Bool) -> String:
  match asks:
    case True{}:
      "asks before changes"
    case False{}:
      "cannot ask"

def codex_asks() -> String:
  codex_asks.at(P.can_ask(True{}))

def flow() -> List<&2, F.Step>:
  [
    F.Step{"You use the page", F.Person{}, False{}, [F.Go{1n, ""}]},
    F.Step{"server.bend answers", F.System{}, False{}, [F.Go{2n, "chat"}, F.Go{15n, "Debug"}]},
    F.Step{"POLICY.bend: " ++ modes(), F.System{}, False{}, [F.Go{3n, "Claude"}, F.Go{14n, "Codex"}]},
    F.Step{"Chat: claude " ++ P.claude_isolation() ++ ", CHAT.md + HEAR.md", F.Skill{}, False{}, [F.Go{4n, "refused"}, F.Go{7n, "MODE: line"}, F.Go{9n, "LAW: lines"}]},
    F.Step{"ASK.bend: refusal becomes a question", F.System{}, False{}, [F.Go{5n, ""}]},
    F.Step{"Allow / Always allow / Don't allow", F.Person{}, False{}, [F.Go{6n, "Allow"}]},
    F.Step{"Chat writes in project/, never " ++ String.join(P.never(), ", "), F.Skill{}, True{}, []},
    F.Step{"OFFER.bend reads the MODE: line", F.System{}, False{}, [F.Go{8n, ""}]},
    F.Step{"Switch / Stay", F.Person{}, False{}, []},
    F.Step{"HEAR.bend reads the LAW: lines", F.System{}, False{}, [F.Go{10n, ""}]},
    F.Step{"Add / Always add / Don't add", F.Person{}, False{}, [F.Go{11n, "Add"}]},
    F.Step{"server.bend puts it in GDD.md", F.System{}, True{}, [F.Go{12n, ""}]},
    F.Step{"Law agent: claude " ++ P.claude_tools(P.law_agent()) ++ ", AGENT.md", F.Skill{}, True{}, [F.Go{13n, ""}]},
    F.Step{"bend LAWS.bend: green or red", F.System{}, False{}, []},
    F.Step{"Chat: codex --sandbox " ++ P.codex_sandbox(P.chat()) ++ ", " ++ codex_asks(), F.Skill{}, False{}, []},
    F.Step{"Debug: bend PROOF.bend", F.System{}, False{}, []}
  ]
