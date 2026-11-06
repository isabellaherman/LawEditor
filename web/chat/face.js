// The agent's face in the chat: beside its latest reply; it flies to each new one (Bend-UI's mountAgent, flyBetween).
// The big face in the corner is only on the Document.
import { mountAgent, flyBetween } from "bend-ui/agent";

export function createFace() {
  let pet = null;
  return {
    // from: where the face was (the start's big face), when it isn't beside an earlier reply.
    to(slot, from = pet && pet.face.getBoundingClientRect()) {
      if (pet) pet.destroy();
      pet = mountAgent(slot, { size: "sm", items: [] });
      if (from && from.width) flyBetween(from, pet);
    },
    lookAt(el) { pet?.lookAtEl(el); },
  };
}
