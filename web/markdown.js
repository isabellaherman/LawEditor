// Markdown to HTML, for the context views (AGENT.md in Laws, CHAT.md in Chat).
export function markdown(src) {
  const esc = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
  const inline = (s) => esc(s)
    .replace(/`([^`]+)`/g, "<code>$1</code>")
    .replace(/\*\*([^*]+)\*\*/g, "<strong>$1</strong>")
    .replace(/(https?:\/\/[^\s)]+)/g, '<a href="$1" target="_blank" rel="noopener">$1</a>');
  const out = []; let list = null, code = null;
  for (const line of src.split("\n")) {
    if (code !== null) { if (/^```/.test(line)) { out.push(`<pre><code>${esc(code.join("\n"))}</code></pre>`); code = null; } else code.push(line); continue; }
    if (/^```/.test(line)) { if (list) { out.push(`<${list.t}>${list.items.join("")}</${list.t}>`); list = null; } code = []; continue; }
    const h = line.match(/^(#{1,3}) (.*)/), li = line.match(/^(\s*)(-|\d+\.) (.*)/);
    if (li && !li[1]) {
      const t = li[2] === "-" ? "ul" : "ol";
      if (!list || list.t !== t) { if (list) out.push(`<${list.t}>${list.items.join("")}</${list.t}>`); list = { t, items: [] }; }
      list.items.push(`<li>${inline(li[3])}</li>`); continue;
    }
    if (li && list) { list.items[list.items.length - 1] = list.items[list.items.length - 1].replace("</li>", `<br>${inline(li[3])}</li>`); continue; }
    if (list) { out.push(`<${list.t}>${list.items.join("")}</${list.t}>`); list = null; }
    if (h) out.push(`<h${h[1].length}>${inline(h[2])}</h${h[1].length}>`);
    else if (line.trim()) out.push(`<p>${inline(line)}</p>`);
  }
  if (list) out.push(`<${list.t}>${list.items.join("")}</${list.t}>`);
  return out.join("\n");
}
