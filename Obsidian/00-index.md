# Index — Day 14 AI Evaluation

Ghi chú học tập theo từng Task/TODO/Checkpoint đã hoàn thành, viết cho người
gần như chưa có nền tảng về AI evaluation. Đọc theo thứ tự bên dưới.

1. [[01-checkpoint1-part1-warmup]] — Hiểu 3 thành phần của pipeline, 4 nhóm
   metrics, và hoàn thành Exercises 1.1–1.3 (RAGAS thresholds, bias trong
   LLM-as-a-Judge, evaluation trong CI/CD).
2. [[02-checkpoint2-part2-core-coding]] — Cài đặt 5 Task bắt buộc trong
   `template.py`: Data Models, RAGASEvaluator (bao gồm rank-aware Context
   Precision), LLMJudge, BenchmarkRunner, FailureAnalyzer. Kết quả:
   `pytest tests/ -v` → 41 passed, 1 skipped.
3. [[03-checkpoint3-golden-dataset-rag-benchmark]] — Corpus thật của repo là
   OrbitTech Store (`data/technology_store/`, không phải "student services").
   20 QA golden dataset, validator PASS, 20 actual answers từ RAG thật, và vì
   sao pass rate 60% không đồng nghĩa với lỗi hệ thống.
4. [[04-checkpoint4-failure-analysis-reflection]] — Bài học cốt lõi: điểm số
   thấp nhất (A01/A03) là false alarm của metric, còn case nguy hiểm thật
   (H02 — trả lời sai Yes/No) lại có điểm khá vì heuristic không phát hiện
   được kết luận bị đảo ngược. Ba phân tích 5 Whys, clustering, regression
   strategy đầy đủ trong `reflection.md`.
5. [[05-hoan-tat-kiem-tra-cuoi-nop-bai]] — Checklist nộp bài cuối cùng:
   `solution/solution.py` copy từ `template.py`, 41 passed/1 skipped,
   validator PASS, không secret trong diff, ba điểm cần nhớ để demo.
