// The composer: one field with the send button inside. When Send is on is CHAT.bend.
import C from "../../CHAT.bend";

export function createComposer(form, onSend) {
  const text = form.querySelector(".composer__text"), send = form.querySelector(".composer__send");
  let answering = false, asking = false;
  const sync = () => { send.disabled = !C.can_send(asking, answering, text.value.trim().length); };
  text.addEventListener("input", sync);
  text.addEventListener("keydown", (e) => { if (e.key === "Enter" && !e.shiftKey) { e.preventDefault(); form.requestSubmit(); } });
  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    const t = text.value.trim();
    if (!C.can_send(asking, answering, t.length)) return;
    text.value = ""; answering = true; sync();
    await onSend(t);
    answering = false; sync(); text.focus();
  });
  sync();
  // A question waits for the person: the field is off, and says why, until they answer.
  const placeholder = text.placeholder;
  function hold(on) {
    asking = on; text.disabled = on;
    text.placeholder = on ? "Answer the question above to keep talking" : placeholder;
    sync(); if (!on) text.focus();
  }
  return { focus: () => text.focus(), hold };
}
