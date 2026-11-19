# LawEditor's copy of Web.bend, from DungeonBend (branch port/bend-new, src/Web.bend, by Lorenzo Battistela),
# unchanged below this note. It is the same in every project that has a page: LawEditor puts it in the
# project (engine/BUILD.bend) and the chat never edits it. harness/web/WEB.md says how a page uses it.
#
# Web: the HTML and app-update vocabulary the game was written against.
#
# The old Bend2 shipped these as built-ins (`HTML`, `HTML/Attr`, `App/Update`,
# `App/Cmd`) together with `<div ..>` literals. The new Bend has neither, so
# the port carries its own copy and tools/port.py rewrites every HTML literal
# into these constructors:
#
#   <div class="x" on_click={go{}}>{kid}</div>
#   Web.node{"div", [Web.attr{"class", "x"}, Web.on{Web.click{go{}}}], [kid]}
#
# Everything under HTML is `Data` on purpose: a view is a plain tree that can
# be copied, compared in asserts and handed to JS as `{$: "node", ..}`.
#
# OPEN DECISION (see PORT-STATUS.md): the old `HTML/Event` also had events that
# carry a function (`key_down{fun: U32 -> Ev}`, `input{fun: String -> Ev}`).
# A function field would make the whole HTML tree affine (`Type`), so they are
# left out until the JS runtime contract is chosen. The game uses exactly one:
# `on_key_down` on the page root.

import Base

type DomEvent<-Ev: Data> is Data:
  click{msg: Ev}
  double_click{msg: Ev}

type Attr<-Ev: Data> is Data:
  attr{name: String, value: String}
  prop{name: String, value: String}
  style{name: String, value: String}
  on{event: DomEvent<Ev>}
  every_ms{ms: U32, msg: Ev}

type HTML<-Ev: Data> is Data:
  text{value: String}
  node{tag: String, attrs: List<&2, Attr<Ev>>, kids: List<&2, HTML<Ev>>}

# App command. `store_get` keeps its callback, so a Cmd (and an Update) is
# affine: it is built once by the update function and consumed by the runtime.
type Cmd<-Ev: Data> is Type:
  none{}
  batch{cmds: List<&1, Cmd<Ev>>}
  delay{ms: U32, event: Ev}
  store_get{key: String, on_some: @+wire: String -> Ev, on_none: Ev}
  store_set{key: String, value: String, event: Ev}
  store_del{key: String, event: Ev}

type Update<-St: Data, -Ev: Data> is Type:
  update{state: St, cmd: Cmd<Ev>}

def _assert_text() -> {text{"hello"} == text{"hello"} : HTML<Unit>}:
  {==}

def _assert_node() -> {node{"button", [attr{"id", "ok"}, on{click{Unit{}}}], [text{"go"}]} == node{"button", [attr{"id", "ok"}, on{click{Unit{}}}], [text{"go"}]} : HTML<Unit>}:
  {==}
