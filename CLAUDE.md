# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

A single training lab (Day 14 of a 15-day AI program, "AICB-P1 · Phase 1 · K4"):
**AI Evaluation & Benchmarking Pipeline**. The student implements an evaluation
engine (`template.py`), builds a 20-question golden dataset
(`golden_dataset.json`), runs a real RAG assistant (`domain_assistant.py`)
against it, and writes up a failure analysis. There is no app to deploy — the
deliverable is code + dataset + two Markdown reports.

Read `README.md` first for the task list and rubric, and `guide_lab.md` for
the full step-by-step walkthrough (environment setup, per-task guidance,
common errors). Both are in Vietnamese; the student-facing worksheets
(`exercises.md`, `reflection.md`) are filled in by the student, not generated
by tooling.

## Commands

```bash
python -m venv .venv && source .venv/bin/activate   # Windows: .venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
cp .env.example .env                                 # fill OPENAI_API_KEY (only needed for Part 3)

pytest tests/ -v                                      # full suite (42 tests)
pytest tests/test_solution.py::TestRAGASEvaluator -v   # single test class
pytest tests/test_solution.py::TestRAGASEvaluator::test_faithfulness_full_overlap -v  # single test

python validate_golden_dataset.py                     # schema + evidence-provenance check for golden_dataset.json
python domain_assistant.py                             # generate artifacts/actual_answers.json (needs OPENAI_API_KEY)
python evaluate_answers.py                              # score actual answers, write artifacts/benchmark_results.json, print Exercise 3.2 table
```

`tests/test_solution.py` auto-loads `solution/solution.py` if present,
otherwise falls back to `template.py` — so tests can be run against the
in-progress starter file without copying anything first. Copy
`template.py` → `solution/solution.py` only once the TODOs are done (see
Section 13 of `guide_lab.md`).

Targeted checkpoint commands per task (with expected pass counts) are listed
in `guide_lab.md` §4.9 — running the relevant subset after finishing each
task group is the fastest signal loop, cheaper than the full 42-test suite.

## Architecture: three components, do not blur their boundaries

```
DomainAssistant (domain_assistant.py)   →  system under evaluation (the RAG agent)
RAGASEvaluator/LLMJudge/BenchmarkRunner/FailureAnalyzer (template.py) → evaluation engine
evaluate_answers.py                     →  adapter: joins golden_dataset.json + artifacts/actual_answers.json, feeds template.py, writes report
```

- **`domain_assistant.py`** is self-contained and knows nothing about scoring.
  It loads the Markdown corpus in `data/technology_store/` (via
  `manifest.json`), indexes it with a hand-rolled BM25 retriever
  (`BM25Retriever`), and generates answers with an OpenAI model
  (`OpenAIGenerator`). Critically, `DomainAssistant.answer()` only ever
  receives `question` — it must never see `expected_answer` or gold
  `contexts`, because that would leak the answer key into generation and
  invalidate the benchmark. Preserve this boundary in any change here.
- **`template.py`** is the evaluation core and the only file with real TODOs.
  It has no dependency on OpenAI, the corpus, or the retriever — its metrics
  are pure word-overlap heuristics operating on strings passed in by the
  caller. This isolation is intentional (see docstring: "In production,
  replace with actual RAGAS framework"). The five Task 2 metrics
  (`evaluate_faithfulness`, `evaluate_relevance`, `evaluate_completeness`,
  `evaluate_context_recall`, `evaluate_context_precision`) all follow the
  same shape: tokenize with `_tokenize`, compute a set-overlap ratio, clamp
  to `[0.0, 1.0]`, return `1.0` for an empty reference input. Class/function
  signatures in `template.py` are fixed by the test suite — do not change
  them, including the optional `contexts` parameter of `run_full_eval`.
- **`evaluate_answers.py`** never computes metrics itself. It only does
  artifact I/O (`load_evaluation_inputs`, `build_evaluation_artifact`) and
  prints the Exercise 3.2 report table. All scoring logic must stay in
  `template.py`.

## Data flow

```
data/technology_store/*.md  →  golden_dataset.json (student-authored, validated by validate_golden_dataset.py)
                                          │
                              domain_assistant.py (reads id + question only)
                                          │
                              artifacts/actual_answers.json
                                          │
                              evaluate_answers.py → template.py core
                                          │
                              artifacts/benchmark_results.json + printed Exercise 3.2 table
```

`golden_dataset.json` has a **fixed slot layout** enforced by
`validate_golden_dataset.py`: exactly 5 Easy (`E01`–`E05`) + 7 Medium
(`M01`–`M07`) + 5 Hard (`H01`–`H05`) + 3 Adversarial (`A01` out_of_scope,
`A02` prompt_injection, `A03` false_premise_or_ambiguous_trap, in that exact
order and with those exact ids/attack_types). Every `contexts[].text` must be
a verbatim substring of the named `source_doc` in
`data/technology_store/manifest.json`, and every manifest document must be
used by at least one QA pair. `evaluate_answers.py` additionally requires
`golden_dataset.json` and `artifacts/actual_answers.json` to share the same
`corpus_id` and to have matching questions per id — a stale
`actual_answers.json` after editing the golden dataset will fail loudly
rather than silently score against mismatched data.

## Two evaluation metric groups, only one feeds `passed`

`RAGASEvaluator` computes answer-side metrics (faithfulness, relevance,
completeness) and, only when `contexts` is passed into `run_full_eval`,
retrieval-side metrics (context recall, context precision — precision is
rank-aware Average Precision@K, rewarding relevant chunks ranked earlier).
`EvalResult.passed` and `overall_score()` are defined purely from the three
answer-side metrics; `context_recall`/`context_precision` stay `None` unless
retrieval contexts are supplied and are diagnostic only — they never affect
`passed`. `BenchmarkRunner.run` is required to forward
`pair.retrieved_contexts` into `run_full_eval`, and `generate_report` must
average only the non-`None` retrieval scores across results.

## Documentation workflow — Obsidian notes per task/checkpoint

Whenever a **Task** (Task 1–5 in `README.md`/`template.py`), a **TODO** block,
or a **Checkpoint** (the per-task-group checkpoints in `guide_lab.md` §4.9,
or a golden-dataset/benchmark milestone in Part 3–4) is completed in this
repo, write a companion note into the `Obsidian/` folder at the repo root
(create it if missing) so the student — who has close to no prior background
in AI evaluation — can review what was done and why, independent of the code.

Rules for these notes:

- **One Markdown file per completed unit**, named
  `Obsidian/<NN>-<task-or-checkpoint-slug>.md` (zero-padded sequence number
  so Obsidian's file list stays chronological), e.g.
  `Obsidian/01-task1-data-models.md`,
  `Obsidian/07-checkpoint-task2-metrics.md`,
  `Obsidian/13-golden-dataset-complete.md`.
- **Write for a beginner.** Explain the underlying concept in plain language
  before showing code — e.g. for Task 2, explain *what* faithfulness/
  relevance/completeness mean and *why* word-overlap is a reasonable (if
  crude) stand-in for an LLM judge, not just what the function returns.
  Avoid unexplained jargon; define each term (RAGAS, BM25, Average
  Precision@K, 5 Whys, etc.) the first time it appears in a note.
- **Structure each note** with: what was implemented/decided, the key code
  location (`file:line`), a short "why it matters" tied back to the
  lecture concepts in `README.md`, and what to verify (the relevant
  `pytest` command and expected result from `guide_lab.md` §4.9, or
  `validate_golden_dataset.py` output).
- **Use Vietnamese**, matching the rest of this repo's documentation
  (`README.md`, `guide_lab.md`).
- Link related notes with `[[wikilink]]` syntax so the vault stays navigable
  in Obsidian, and keep a running `Obsidian/00-index.md` linking every note
  in completion order.
- These notes are a learning aid, not a graded deliverable — do not let them
  block or replace the actual required files (`solution/solution.py`,
  `golden_dataset.json`, `exercises.md`, `reflection.md`).
