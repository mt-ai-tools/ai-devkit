#!/usr/bin/env bash
# The routes, decided in code from forms that passed their checks and never
# from a model's words: where a question goes once it has passed the rules
# and conventions check and any challenge. Every function here is a
# transform. Sourced, never executed.
#
# A question with no recommendation goes back to the agent to state one: the
# operator is handed a decision, never a blank question. Then any of an
# always-yours kind, a risk named on the recommended option, or a sort the
# sorter was unsure of brings it to the operator, with every reason that
# applies; so does a question sorted as a step's report waiting for the go,
# since a reply that asks something is never one the stand-in says go to; and
# so does a recommendation to put work off, where the kind's recommendation
# would otherwise stand unchallenged. What is left takes its kind's own route:
# up the ladder, the light check's one challenge, or accepted as it stands.
. "$(dirname "${BASH_SOURCE[0]}")/preset.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The route a question takes, as JSON {route, words}: route is "agent", the
# words those it is sent back with; "operator", the words one line per reason
# it came to them; or the kind's own route — ladder, light or accept — the
# words any line the operator would be shown beside it. Given the reader's
# form, the sorter's answer, the kind's entry, the preset's risks, and whether
# the agent kept the question through a challenge. A kept question goes on as
# it stood when challenged and is never sent back for a recommendation: the
# agent has already answered for it, and a send-back would only start the
# challenge over.
derive_route() {
  local form="$1" sort="$2" entry="$3" risks="$4" kept="$5" recommended name route lines="" risk words
  recommended="$(jq -r '.recommended' <<<"$form")"
  if [ -z "$recommended" ] && [ "$kept" != true ]; then
    to_route agent "$(gate_no_recommendation_note)"
    return 0
  fi
  name="$(jq -r '.name' <<<"$entry")"
  route="$(jq -r '.route' <<<"$entry")"
  case "$route" in
    "$ROUTE_ASK") lines+="$(gate_kind_line "$name" "$(jq -r '.summary' <<<"$entry")")"$'\n' ;;
    "$ROUTE_GO") lines+="$(gate_go_kind_line "$name")"$'\n' ;;
  esac
  while IFS= read -r risk; do
    [ -n "$risk" ] || continue
    words="$(jq -r --arg risk "$risk" '.[] | select(.name == $risk) | .words' <<<"$risks")"
    lines+="$(gate_risk_line "$recommended" "$risk" "$words")"$'\n'
  done < <(jq -r '.risks[]' <<<"$sort")
  if jq -e '.unsure' >/dev/null <<<"$sort"; then
    lines+="$(gate_unsure_line "$name")"$'\n'
  fi
  # Only where the recommendation would stand unchallenged: the operator takes
  # the agent's word on when to do a step, except a recommendation to put it
  # off, where their own habit is to push toward doing it now (settled
  # 2026-10-06). The ladder and the light check challenge whatever is
  # recommended, and an always-yours kind reaches them anyway.
  if [ "$route" = "$ROUTE_ACCEPT" ] && jq -e '.defers' >/dev/null <<<"$sort"; then
    lines+="$(gate_defers_line "$recommended")"$'\n'
  fi
  local reasons="$lines"
  [ "$kept" != true ] || lines+="$(gate_kept_line)"$'\n'
  if [ -n "$reasons" ]; then
    to_route operator "$lines"
  else
    to_route "$route" "$lines"
  fi
}

# One route's JSON.
to_route() {
  jq -cn --arg route "$1" --arg words "$2" '{route: $route, words: $words}'
}
