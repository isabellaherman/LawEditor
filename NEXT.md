# Next: the game follows the laws (0.2.0)

A design note, not built yet. Written on 2026-11-08 from a talk with the repo owner, to be read by people and by the tools that will help design the larger flows.

## Today (0.1.5)

- The person talks in the chat; the chat hears rules and proposes them; an accepted sentence goes to `GDD.md`, and the law agent writes its law in `LAWS.bend`. This works.
- But a law checks a stand-in, not the game. To state a law, the law agent adds the smallest model it needs to `TYPES.bend` (a player with a position, a `walk` function). The game the chat builds (for example `plataforma.html`, in JavaScript) is separate code that never meets that model.
- So a game can break a rule and nothing turns red.

## 0.2.0: the laws check the game itself

- The game's logic is written in Bend: its state, and what each action does (walk, jump, lose a life). A page only reads input and draws what Bend returns, as LawEditor itself is built.
- The laws talk about that code, not about a stand-in. Bend checks them, and proofs show the game keeps them.
- If the chat changes the game and breaks a rule (the player rises while walking), the law turns red.

## The first decision: which language

Laws only work on Bend code. So a request to build starts with this choice:

1. **The person names another language** (Python, Unity, JavaScript…): build in it, and say the laws won't check this code.
2. **No language named**: build the logic in Bend, and the laws check it.
3. **No language named, but Bend can't do it yet** (3D, for example): say so, and ask whether to go on in another language (without law checks) or with a simpler version in Bend.

## Open questions

- **Who decides case 3?** The model (a skill: it guesses and can be wrong), or a list in Bend of what Bend can do today (2D canvas, keyboard, sound…) that the system reads and laws can check. The second fits the method: a system step, proved, not a model's guess.
- **Where the flow lives.** Like `HEAR.flow()` and `OFFER.flow()`, this flow should be data in `FLOW.bend` form, drawn by Bend-UI's diagram and checked by the same laws (whole, skill then system, no write without the person) before it is built.
- **What the person sees.** Which language the game is in, and whether its laws are on, should be visible in the chat, not guessed.
- **The step after.** Once the logic is in Bend, how the law agent and the game code stay one: the law agent writes laws against the game's functions instead of adding a stand-in to `TYPES.bend`.
