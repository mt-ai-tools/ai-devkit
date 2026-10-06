# stand-in

A stand-in for the operator over the questions an agent puts to them: a gate
at the end of every reply, in the sessions it is switched on for, that has
each finished reply read by a fresh model into one fixed form — whether it
asks the operator something, the options, the one it recommends, whether it
says the work is finished — and each question checked by another against the
project's written rules and conventions, then sorted into a kind of question
and the risks its recommended option carries, against a preset of the
operator's own judgement. A question that breaks an entry, or calls something
a rule that no entry is, goes back to the agent; a kind that carries a
challenge is challenged first; the rest is routed in code, back to the agent,
on to the operator with why, or up the operator's own challenge ladder. On
the ladder the agent is challenged twice more in the preset's own words; each
reply is matched by another model against the first answer's options, and
the answer holds only where every reply picks the option first recommended,
however it is worded. One that moves is sent a bigger look around once, then
asked once more whether it is sure. Where it moves again, it reaches the
operator with a cold second reading of the question by another model, which
decides nothing; where it holds, it reaches them told it moved and then held.
Either way it never counts as held: an answer that moved once is never one
that would be approved. While a kind is on trial, which every kind is, an
answer that held reaches the operator too, marked with what would have been
approved.

It is switched on for a session by a command the operator types, and in no
other way. With a brief's name, the brief is taken through the work
organizer, and the session is handed the preset's opener before anything
else; with a word asking for no brief, it is switched on and nothing is
taken; bare, the organizer's list is shown to pick from, and nothing
changes. A command that cannot be carried out is refused whole, in the
organizer's own words where the organizer refused it, and leaves nothing
switched on and nothing taken. It is switched off when the session ends.

Before any question reaches the operator, whatever its route, the agent is
asked once to retell it plainly, and its retelling is what the operator reads
first; then why it came to them; then fixed parts a fresh model writes from
the whole exchange between the stand-in and the agent, in everyday words —
the problem with an everyday example, the first recommendation, what moved
it and why in the agent's own reasons, what it recommends now — then the
second reading where one ran, and last the operator's call, each option with
its risk. The fresh model retells and never judges or recommends; a part it
leaves empty is a refused form. The exchange is kept in the session's record
while the question is held.

Every question it lets go leaves one whole line in a log of its own: when,
in which session and brief, the question as asked and as retold, how it was
sorted and checked, every answer on the ladder, the whole exchange, how it
ended and why, the summary's parts and the second reading. Lines from sessions
writing at once never interleave. The first thing the operator types after a
question reached them is kept as their answer to it. Asked in plain words,
it shows the operator the questions it settled without them, and brings any
of them back in full, word for word on request, for the agent to ask again;
both are shown through a hook, exactly as written, never retold by a model.

Models read; code decides. A form counts only once a check in code has
passed it: every field there and of its type, the recommendation among the
options, every kind, risk and entry one it was handed. A form that fails is
refused with its reasons, never repaired or guessed at. Nothing is ever
decided from a model's words, only from a form that passed. It reads the
reply it is handed and never a conversation itself. It knows no kind of
question, no risk, no rule and no convention by name: whatever the preset and
the two collections hold is what its readers are handed and what their
answers are checked against.

It fails toward the operator: whatever it cannot read or judge lets the reply
stop with the reason shown to them, and asks the agent nothing more. It never
holds one question past a small number of send-backs asking the agent to
rethink, the ladder's challenges among them; the bigger look around, the
second "are you sure?" after it and the plain retelling are fixed rounds
outside that count, each sent at most once for a question. A second
reading, a summary or a log line that fails never holds a question up: the
operator is told why there is none. Where it is off for a session it does
nothing, and asks no model.

Needs a preset: a folder of kinds of question, each with a one-line summary
and its route, a list of risks, each opening with its short name, a
challenge ladder holding each message the stand-in sends — the two
challenges, the bigger look around and the plain retelling — quoted under
the short name it is asked for by, and an opener, what a session started
with a brief is told first. Needs the rules, and the conventions
where a project keeps them, and the kit's advisor, whose command a second
reading runs. Needs a working folder of its own, holding a switch per
session it is on for, its record of each and its log, worth nothing beyond
one machine. Needs the kit's work organizer, to show its list, to take a
brief, and to say which brief a session holds. Needs registering for Claude
Code's end-of-reply event, with a time limit no shorter than the one it
declares; for its turn-start event, to keep the operator's answers, and
again, beside the skill that offers the command, to act on the command that
starts it; for its session-end event, to switch it off; and for its
after-tool event of the Skill tool, beside its two other skills, to show
what they ask for. Needs the Claude Code
command-line tool, signed in, to ask models through; and `bash`, `awk`,
`jq` and util-linux's `flock`.
