# herdr: name a new, unnamed pane after its folder. Sourced from ~/.zshrc.
if [[ -n "$HERDR_PANE_ID" ]] && command -v jq >/dev/null; then
  ( [[ -z "$(herdr pane get "$HERDR_PANE_ID" 2>/dev/null | jq -r '.result.pane.label // empty')" ]] \
      && herdr pane rename "$HERDR_PANE_ID" "${PWD:t}" >/dev/null 2>&1 ) &!
fi
