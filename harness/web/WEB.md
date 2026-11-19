# A page in Bend

A program that runs in a browser is written in Bend, all of it, page included. You never write HTML, CSS or
JavaScript. The page is a value Bend returns: `render(state)` gives the whole screen as a tree of
`Web.HTML`, and LawEditor's driver (the same in every project) puts it in the browser, sends each click
back to Bend, and draws the new screen. So everything on the screen (each text, color, size, what a button
does, when it is off) is decided in Bend, and a law can speak of it.

## The files

- `Web.bend`: the page's vocabulary. LawEditor puts it in the project and keeps it as it is: never write or
  change it. Import it as `import ./Web.bend as Web`. Its text is in `.laweditor/web/Web.bend` too (read it
  there if the project doesn't have it yet: LawEditor adds it after your reply).
- `main.bend`: the program. For a page it defines the four names below.
- No `index.html`, no `.js`, no `.css`: LawEditor's own page runs `main.bend`.

## What main.bend defines

```python
import Base
import ./Web.bend as Web

# The state: everything the page shows comes from it.
type Game is Data:
  Game{cheese: Nat, rats: Nat}

# What the page can send back: one constructor per thing the person can do, and the clock.
type Ev is Data:
  collected{}
  bought{}
  ticked{}

# The page's title, in the browser's tab.
def title() -> String:
  "Rato e Queijo"

# The state the page starts in, and what to do first (Web.none{}: nothing).
def init() -> Web.Update<Game, Ev>:
  Web.update{new_game(), Web.none{}}

# The whole screen, from the state.
def render(+g: Game) -> Web.HTML<Ev>:
  ...

# One event: the next state, and what to do next.
def on_event(+e: Ev, +g: Game) -> Web.Update<Game, Ev>:
  match e:
    case collected{}:
      Web.update{collect(g), Web.none{}}
    ...
```

The rules of the program (`collect`, `buy_rat`, `tick`) are ordinary definitions beside them: the laws talk
about those, and about `render` too.

## The vocabulary (Web.bend)

A screen is a tree of two kinds of node:

- `Web.text{"3 queijos"}`: a text.
- `Web.node{"button", [attributes], [children]}`: an element: its HTML tag, a list of `Web.Attr`, a list of
  children.

An attribute is one of:

- `Web.attr{"aria-label", "Buy a rat"}`: an HTML attribute (`class`, `id`, `disabled`, `aria-*`, ...).
- `Web.style{"font-size", "28px"}`: one style rule. Sizes, colors and spaces go here, each from a definition
  (`def gap_px() -> U32: 16`), never typed twice.
- `Web.on{Web.click{bought{}}}`: what a click sends (`Web.double_click{..}` for a double click).
- `Web.every_ms{1000, ticked{}}`: a clock: every 1000 ms the page sends `ticked{}`. Put it on an element that
  is always on the screen.
- `Web.prop{"value", "..."}`: a property of the element (rarely needed).

A button that is off when it can't be used: give it `Web.attr{"disabled", "disabled"}` only when Bend says
so. The list of attributes is a value, so build it with a definition that matches on a `Bool`:

```python
def buy_attrs(can: Bool) -> List<&2, Web.Attr<Ev>>:
  match can:
    case True{}:
      [Web.on{Web.click{bought{}}}]
    case False{}:
      [Web.attr{"disabled", "disabled"}]
```

What `on_event` can ask the browser to do next (a `Web.Cmd`):

- `Web.none{}`: nothing.
- `Web.delay{ms, event}`: send `event` after `ms`.
- `Web.store_set{key, value, event}`, `Web.store_get{key, on_some, on_none}`, `Web.store_del{key, event}`:
  keep a text in the browser (localStorage), read it back, forget it.
- `Web.batch{[...]}`: several of them.

## What it can't do yet

- Typing in a field: there is no event for it. A page of buttons, clicks and clocks only. If the person asks
  for a field to type in, say so in one sentence.
- Keys: only through `key_event(state, code)` and an element with `Web.attr{"data-key-root", "1"}`.
- Drawing pixel by pixel (a canvas): not here. A game that needs it opens a window instead (`App.run`).

## Checking it

`bend main.bend --check-only` checks it. After your reply LawEditor checks every `.bend` file and bundles the
page from `main.bend`; the person opens it with the button under your reply.
