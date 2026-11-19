// LawEditor's copy of DungeonBend's web driver (branch port/bend-new, web/driver.js, by Lorenzo
// Battistela), unchanged below this note. It is the same in every project that has a page: LawEditor
// bundles it with the project's main.bend (engine/BUILD.bend). Only "the game" in its words is a project here.
//
// DungeonBend app driver for the new Bend.
//
// The old Bend2 runtime owned the app loop (birl/rt/runtime.js: __run_app,
// __app_patch, __app_run_cmd). The new Bend has no app loop, so this file is
// that loop: it takes a compiled Bend program, calls its entry defs
// and keeps the DOM in step with render(state).
//
// The same driver runs both pages: web/app.js starts the game
// (src/main.bend), web/ui-test.js the ui-test page (src/ui_test.bend). A
// program exports init, render and on_event; key_event is needed only when its
// view has a key root (data-key-root).
//
// It mirrors the old runtime on purpose, node for node and in the same order,
// because the handwritten bridges in assets/runtime/ rely on the DOM it
// produced (AGENTS.md section 5). All game logic stays in Bend: this file only
// moves values across the boundary.
//
// Bend values as JS sees them: a constructor is {$: "name", field: value},
// a String is a string, a U32 is a number, a List is {$: "Con", head, tail}
// or {$: "Nil"}, a function field is a JS function.

// Values
// ======

function list(xs) {
  const out = [];
  for (let at = xs; at.$ === "Con"; at = at.tail) {
    out.push(at.head);
  }
  return out;
}

// View
// ====
// decode turns a Web.HTML tree into the shape the patcher walks: attributes
// split by kind, kids as an array.

function decodeAttrs(attrs) {
  const out = { attrs: {}, props: {}, style: {}, on: {}, fx: [], keyRoot: false };
  for (const attr of list(attrs)) {
    switch (attr.$) {
      case "attr": {
        out.attrs[attr.name] = attr.value;
        // The page root asks for key presses (the old on_key_down attribute).
        if (attr.name === "data-key-root") {
          out.keyRoot = true;
        }
        break;
      }
      case "prop": {
        out.props[attr.name] = attr.value;
        break;
      }
      case "style": {
        out.style[attr.name] = attr.value;
        break;
      }
      case "on": {
        const event = attr.event;
        if (event.$ === "click") {
          out.on.click = event.msg;
        } else if (event.$ === "double_click") {
          out.on.dblclick = event.msg;
        } else {
          throw new Error("unknown Web.DomEvent: " + event.$);
        }
        break;
      }
      case "every_ms": {
        out.fx.push({ ms: attr.ms >>> 0, msg: attr.msg });
        break;
      }
      default: {
        throw new Error("unknown Web.Attr: " + attr.$);
      }
    }
  }
  return out;
}

function decode(view) {
  switch (view.$) {
    case "text": {
      return { $: "text", value: view.value };
    }
    case "node": {
      return { $: "node", tag: view.tag, attrs: decodeAttrs(view.attrs), kids: list(view.kids).map(decode) };
    }
    default: {
      throw new Error("unknown Web.HTML: " + view.$);
    }
  }
}

// Attributes
// ==========

const EMPTY = { attrs: {}, props: {}, style: {}, on: {}, fx: [], keyRoot: false };

function setAttr(el, name, value) {
  if (name === "value" && "value" in el) {
    if (el.value !== value) {
      el.value = value;
    }
    return;
  }
  el.setAttribute(name, value);
}

function delAttr(el, name) {
  if (name === "value" && "value" in el) {
    el.value = "";
  }
  el.removeAttribute(name);
}

function setProp(el, name, value) {
  if (name in el) {
    el[name] = value;
  } else {
    el.setAttribute(name, value);
  }
}

function delProp(el, name) {
  if (name in el) {
    el[name] = "";
  }
  el.removeAttribute(name);
}

function patchAttrs(el, prev, next) {
  for (const name in prev.attrs) {
    if (!(name in next.attrs)) {
      delAttr(el, name);
    }
  }
  for (const name in next.attrs) {
    if (prev.attrs[name] !== next.attrs[name]) {
      setAttr(el, name, next.attrs[name]);
    }
  }
  for (const name in prev.props) {
    if (!(name in next.props)) {
      delProp(el, name);
    }
  }
  for (const name in next.props) {
    if (prev.props[name] !== next.props[name]) {
      setProp(el, name, next.props[name]);
    }
  }
  for (const name in prev.style) {
    if (!(name in next.style)) {
      el.style.removeProperty(name);
    }
  }
  for (const name in next.style) {
    if (prev.style[name] !== next.style[name]) {
      el.style.setProperty(name, next.style[name]);
    }
  }
}

// Bindings
// ========
// Listeners and timers are rebound on every patch, as the old runtime did.

function clearBindings(dom) {
  const got = dom.__bend_bindings;
  if (got === undefined) {
    return;
  }
  for (const off of got) {
    off();
  }
  delete dom.__bend_bindings;
}

function patchBindings(el, next, app) {
  clearBindings(el);
  const got = [];
  for (const name in next.on) {
    const msg = next.on[name];
    const handler = () => app.dispatch(msg);
    el.addEventListener(name, handler);
    got.push(() => el.removeEventListener(name, handler));
  }
  if (next.keyRoot) {
    const handler = (evt) => {
      evt.preventDefault();
      const code = typeof evt.which === "number" ? evt.which : evt.keyCode;
      app.dispatch(app.program.key_event(app.state, (code ?? 0) >>> 0));
    };
    el.addEventListener("keydown", handler);
    got.push(() => el.removeEventListener("keydown", handler));
  }
  for (const fx of next.fx) {
    const timer = setInterval(() => app.dispatch(fx.msg), fx.ms);
    got.push(() => clearInterval(timer));
  }
  if (got.length !== 0) {
    el.__bend_bindings = got;
  }
}

function dispose(dom) {
  clearBindings(dom);
  for (const kid of dom.childNodes) {
    dispose(kid);
  }
}

// Patch
// =====

const SVG_NS = "http://www.w3.org/2000/svg";

function mount(view, app, svg) {
  if (view.$ === "text") {
    return document.createTextNode(view.value);
  }
  const isSvg = svg || view.tag === "svg";
  const el = isSvg ? document.createElementNS(SVG_NS, view.tag) : document.createElement(view.tag);
  patchAttrs(el, EMPTY, view.attrs);
  patchBindings(el, view.attrs, app);
  const kidSvg = isSvg && view.tag !== "foreignObject";
  for (const kid of view.kids) {
    el.appendChild(mount(kid, app, kidSvg));
  }
  return el;
}

function replace(dom, view, app, svg) {
  const next = mount(view, app, svg);
  dispose(dom);
  return next;
}

function patch(dom, prev, next, app, svg) {
  if (prev.$ !== next.$) {
    return replace(dom, next, app, svg);
  }
  if (prev.$ === "text") {
    if (prev.value !== next.value) {
      dom.nodeValue = next.value;
    }
    return dom;
  }
  if (prev.tag !== next.tag) {
    return replace(dom, next, app, svg);
  }
  patchAttrs(dom, prev.attrs, next.attrs);
  patchBindings(dom, next.attrs, app);
  const isSvg = svg || next.tag === "svg";
  const kidSvg = isSvg && next.tag !== "foreignObject";
  const shared = Math.min(prev.kids.length, next.kids.length);
  for (let i = 0; i < shared; ++i) {
    const kid = dom.childNodes[i];
    const got = patch(kid, prev.kids[i], next.kids[i], app, kidSvg);
    if (got !== kid) {
      dom.replaceChild(got, kid);
    }
  }
  while (dom.childNodes.length > next.kids.length) {
    const last = dom.lastChild;
    if (last === null) {
      break;
    }
    dispose(last);
    dom.removeChild(last);
  }
  for (let i = shared; i < next.kids.length; ++i) {
    dom.appendChild(mount(next.kids[i], app, kidSvg));
  }
  return dom;
}

// Commands
// ========

function runCmd(cmd, app) {
  switch (cmd.$) {
    case "none": {
      return;
    }
    case "batch": {
      for (const sub of list(cmd.cmds)) {
        runCmd(sub, app);
      }
      return;
    }
    case "delay": {
      setTimeout(() => app.dispatch(cmd.event), cmd.ms >>> 0);
      return;
    }
    case "store_get": {
      let value = null;
      try {
        value = localStorage.getItem(cmd.key);
      } catch {
      }
      app.dispatch(typeof value === "string" ? cmd.on_some(value) : cmd.on_none);
      return;
    }
    case "store_set": {
      try {
        localStorage.setItem(cmd.key, cmd.value);
      } catch {
      }
      app.dispatch(cmd.event);
      return;
    }
    case "store_del": {
      try {
        localStorage.removeItem(cmd.key);
      } catch {
      }
      app.dispatch(cmd.event);
      return;
    }
    default: {
      throw new Error("unknown Web.Cmd: " + cmd.$);
    }
  }
}

// App
// ===

export function start(program) {
  const root = document.getElementById("app");
  if (root === null) {
    throw new Error("missing #app mount node");
  }
  const boot = program.init();
  const app = { state: boot.state, dispatch: step, program };
  let view = decode(program.render(app.state));
  let dom = mount(view, app, false);
  function step(msg) {
    const result = program.on_event(msg, app.state);
    app.state = result.state;
    const next = decode(program.render(app.state));
    const got = patch(dom, view, next, app, false);
    if (got !== dom) {
      root.replaceChild(got, dom);
    }
    dom = got;
    view = next;
    runCmd(result.cmd, app);
  }
  root.replaceChildren(dom);
  // For the browser console and for tests: the live state and the last view.
  globalThis.__dungeonbend = { app, view: () => view, game: program };
  runCmd(boot.cmd, app);
}
