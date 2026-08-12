#!/bin/bash
# Stop hook: reminds Claude to write an Obsidian/ note (per CLAUDE.md's
# "Documentation workflow" section) whenever lab deliverables were edited
# more recently than the newest Obsidian note.
set -euo pipefail

[ -f "CLAUDE.md" ] || exit 0

mtime_of() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null
}

baseline_mtime=$(mtime_of "CLAUDE.md")

newest_tracked=0
for f in template.py solution/solution.py golden_dataset.json exercises.md reflection.md \
         artifacts/actual_answers.json artifacts/benchmark_results.json; do
  [ -f "$f" ] || continue
  m=$(mtime_of "$f")
  [ -n "$m" ] && [ "$m" -gt "$newest_tracked" ] && newest_tracked=$m
done

# Nothing tracked has changed since this workflow was set up (CLAUDE.md's
# creation) — a fresh checkout where every file shares the clone mtime.
if [ "$newest_tracked" -le "$baseline_mtime" ]; then
  exit 0
fi

newest_note=0
if [ -d "Obsidian" ]; then
  for f in Obsidian/*.md; do
    [ -f "$f" ] || continue
    m=$(mtime_of "$f")
    [ -n "$m" ] && [ "$m" -gt "$newest_note" ] && newest_note=$m
  done
fi

if [ "$newest_tracked" -gt "$newest_note" ]; then
  cat <<'JSON'
{"decision":"block","reason":"Lab deliverables (template.py / solution/solution.py / golden_dataset.json / exercises.md / reflection.md / artifacts/*.json) changed more recently than any note under Obsidian/. Before stopping: write or update the beginner-friendly Vietnamese note(s) in Obsidian/ for the Task/TODO/Checkpoint you just completed, per the \"Documentation workflow\" section in CLAUDE.md, and keep Obsidian/00-index.md in sync."}
JSON
  exit 0
fi

exit 0
