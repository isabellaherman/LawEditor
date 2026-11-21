# Harness

What the chat may do, and when it asks. Works the same with any AI.
The rules live in POLICY.bend; LAWS.bend checks them.

## What it builds

LawEditor builds Bend. A project's files are of three kinds (POLICY.bend holds the list):

| Kind  | What it is                                                                   | Laws check it |
|-------|------------------------------------------------------------------------------|---------------|
| Logic | .bend files: the program itself                                              | Yes           |
| Glue  | A command in shell, a setting, a text, the page that draws what Bend returns | No            |
| Other | A program in another language                                                | No            |

The chat writes logic in Bend and keeps glue free of rules. Another language is not what it builds:
it says so, and the question before the file is written says so too. You decide.

After a reply that changed the project, Bend checks every .bend file and bundles the page
(BUILD.bend). The result shows in the conversation; with an error, the chat gets a turn to fix it.
A page is opened at a second address (the pages door), apart from the app's own.

## Modes

The person picks one under the message field. It starts on "Only read".
"Ask before changes" works with Claude only: Codex can't ask yet. "Change freely" comes later.

| What the chat does    | Only read | Ask before changes | Change freely |
|-----------------------|-----------|--------------------|---------------|
| Read files            | Yes       | Yes                | Yes           |
| Edit or create files  | No        | Asks               | Yes           |
| Run commands          | No        | Asks               | Asks          |
| Change LAWS.bend      | Never     | Never              | Never         |

## When it offers the mode

In Only read, when the person wants something built, the chat doesn't refuse: it offers
Ask before changes (OFFER.bend). Switch moves the picker and sends the request again;
Stay changes nothing. The flow is drawn in Chat › Context, from OFFER.flow().

## When it asks

In Ask before changes, before an action that isn't reading, the chat knocks at the gate with the
whole action (GATE.bend) and waits. A law refuses, the mode refuses, what was allowed for this
conversation passes; otherwise the person is asked: Allow, Allow for this session, or Don't allow.
Until they answer, the turn waits, with no time limit. Nothing is tried twice.
The question shows in the message box's place, with what would change; the conversation keeps one
line of what was answered. A refused action is marked "not run" and changes no count of files.

## Resources and skills

The harness gives resources that don't know what they are for: the project's files, the commands the
mode allows, a clock to be called again. A skill is your own orientation for using them in one context:
when to use it, what it needs, the steps, when to stay silent, what to do alone and what to ask first,
where to speak (SKILL.bend).

The chat writes a skill when you ask ("save that as a skill"), and you see its whole text before it is
kept: Save skill, or Don't save. A skill is a file of the project (.laweditor/skills), plain text you
can open and change. The chat is told the project's skills at every turn, and reads a skill's file
before using it. A skill says how; a timer says when.

## Timers

The chat has no clock: it only answers when it is called. To come back by itself it asks for a timer
(TIMER.bend), and the server keeps the clock (CLOCK.bend).

| Rule                                   | What it means                                                    |
|----------------------------------------|------------------------------------------------------------------|
| You are asked first                    | Set timer, or Don't set, with how often and what it will do      |
| The clock is the server's              | A timer comes due only while the server runs                     |
| A timer's turn is an ordinary turn     | Same conversation, AI and mode; what needs your yes still waits  |
| A timer sets no timer                  | A turn a timer started proposes none                             |
| A missed time is one turn              | The hours a computer slept through never start a row of turns    |
| Its first turn is at its next time     | Never when it is set; laweditor timers test <n> starts one now   |
| It goes on until you say               | Pause, resume or stop it: laweditor timers                       |
| There is a most                        | 20 per project; days at a time of day, or a span of 1 minute to 30 days |

Each time a timer comes due costs a whole turn of the AI, even when it has nothing new to say.
Looking at the clock costs nothing. The timers are files in the project's .laweditor/timers:
laweditor timers lists them; pause <n>, resume <n>, test <n> and stop <n> do the rest.

## Reading the page

The project's page opens beside the chat, in a frame that is always the same (INSPECT.bend). Its bar has
three tools, and none needs the chat to write anything: they read the page as it is drawn, so they are the
same on every page.

| Tool     | What it does                                                                        |
|----------|-------------------------------------------------------------------------------------|
| Comment  | Click a part and write what should change: the message starts with what it points at |
| Measures | Every padding, margin and gap, drawn with its number                                 |
| Inspect  | Click a part and read its values, each with its name on the scale                    |

The page is served from another address than the app's, so the app can't read it. Only when the app's
frame asks (?inspect), the server adds the probe to the page (engine/probe.js): it reads the page's boxes
and tells the frame. Opened in a tab of its own, the page is exactly what Bend bundled.

## What is yours

A message that starts with ! is a command you run yourself, in the project's folder. Nothing is
asked, since you are the one asking; a mode that only reads runs none. The chat reads what it printed.
The terminal under the chat is your own shell. The chat neither sees it nor types in it.

## One engine

The page and the terminal (laweditor) are windows on the same engine: the conversation, its
questions and what was allowed live in the server, kept with the project. What is done in one
shows in the other.

## Checked by

chat_only_reads, chat_claude_reads, chat_codex_reads, chat_never_changes

## Ideas from

- Claude's artifacts: a page beside the talk, with a tool on its bar to comment on a part of it.
- Chrome DevTools and Figma's Dev Mode: the space of each part drawn over it, with its number.
- Claude Code: a mode picker under the field; asking before an action; rules per tool.
- Codex: a read-only mode as the safe start.
- Hermes: allow once, for the session, or never.
- Hermes: the process that is always on keeps the clock and looks every minute; a turn a timer started can't set timers.
- Claude Code: a time that was missed starts one turn, not one per miss.
- Grok Bot: a skill is how and a routine is when; do the task once, save the way as a skill, then put it on a schedule; its first run is at its next time; Pause, Test, Edit and Delete.
- OpenClaw: the timer's turn happens in the conversation itself, where the person already looks.
