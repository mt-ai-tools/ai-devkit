# stand-in

A stand-in for the operator over the questions an agent puts to them: each
finished reply read by a fresh model into one fixed form — whether it asks
the operator something, the options, the one it recommends, whether it says
the work is finished — and each question sorted by another into a kind of
question and the risks its recommended option carries, against a preset of
the operator's own judgement.

Models read; code decides. A form counts only once a check in code has
passed it: every field there and of its type, the recommendation among the
options, every kind and every risk one the preset holds. A form that fails is
refused with its reasons, never repaired or guessed at. Nothing is ever
decided from a model's words, only from a form that passed. It reads the
reply it is handed and never a conversation itself. It knows no kind of
question and no risk by name: whatever the preset holds is what a sorter is
handed and what its answer is checked against.

Needs a preset: a folder of kinds of question, each with a one-line summary,
and a list of risks, each opening with its short name. Needs the Claude Code
command-line tool, signed in, to ask models through, and `bash`, `awk` and
`jq`.
