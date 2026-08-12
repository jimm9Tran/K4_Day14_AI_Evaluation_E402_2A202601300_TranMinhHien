# Hoàn tất — Kiểm tra cuối & Nộp bài

**Hoàn thành:** [[00-index|Index]] · sau [[04-checkpoint4-failure-analysis-reflection]]
· File thay đổi: `solution/solution.py` (mới copy từ `template.py`)

Ghi chú này tổng kết trạng thái nộp bài cuối cùng — dành cho việc rà soát
nhanh trước khi commit/push, không cần đọc lại từng checkpoint trước.

---

## Checklist deliverables bắt buộc (theo `README.md`)

| Deliverable | Trạng thái |
|---|---|
| `solution/solution.py` | ✅ Copy từ `template.py` sau khi cả 5 Task hoàn thành |
| `golden_dataset.json` | ✅ 20/20 QA, đúng schema, 5E+7M+5H+3A, evidence verbatim |
| `exercises.md` | ✅ Part 1–3 đầy đủ (Exercise 1.1–1.3, Task 1–5, Exercise 3.1–3.3) |
| `reflection.md` | ✅ Evaluation report, 3× 5 Whys, improvement log, regression strategy |
| `artifacts/actual_answers.json` | ✅ Đã kiểm tra 20/20 answer, không lỗi (không bắt buộc commit) |
| Không commit `.env`/API key | ✅ `.env` nằm trong `.gitignore`; đã grep diff không thấy secret |

## Kiểm tra cuối — chạy trên `solution/solution.py`

```bash
pytest tests/ -v
# 41 passed, 1 skipped  (test loader ưu tiên solution/solution.py khi file
# này tồn tại — xem tests/test_solution.py dòng 26-32)

python validate_golden_dataset.py
# PASS: dataset structure and evidence provenance are valid.
# Difficulty: easy=5, medium=7, hard=5, adversarial=3
# Document coverage: 10/10
```

**Lưu ý quan trọng đã tự nhắc:** vì `template.py` đã được sửa nhiều lần sau
khi các checkpoint trước hoàn thành, bước copy `cp template.py
solution/solution.py` được làm **lại từ đầu** ở bước này (không dùng bản cũ
nào), nên `solution.py` phản ánh đúng code hiện tại — tránh đúng bẫy "test
chạy trên bản solution cũ" mà hướng dẫn cảnh báo.

## Trước khi commit/push

- `git status --short` cho thấy các file đã sửa: `exercises.md`,
  `golden_dataset.json`, `reflection.md`, `template.py`, cùng file/thư mục
  mới: `CLAUDE.md`, `Obsidian/`, `solution/solution.py`, `artifacts/`,
  `.claude/` (hooks + settings cho quy trình ghi chú Obsidian tự động).
- `git diff --check` → không có lỗi whitespace.
- `git diff | grep -i "api.key\|sk-"` → không có kết quả, xác nhận không rò
  rỉ secret vào diff.
- `artifacts/` không bắt buộc phải commit theo `README.md` — có thể để
  nguyên trong working tree hoặc thêm vào `.gitignore` tuỳ style của lớp;
  quyết định cuối để người nộp bài chọn.

## Chuẩn bị Demo

Ba điểm nên nhớ để trình bày pipeline mà không cần mở lại toàn bộ ghi chú:

1. **Ba thành phần** ([[01-checkpoint1-part1-warmup]]): `domain_assistant.py`
   sinh câu trả lời (không data leakage) → `template.py` chấm điểm →
   `evaluate_answers.py` chỉ nối hai bên.
2. **Benchmark thật**: pass rate 60%, retrieval rất tốt (Context Precision
   0.958) nhưng answer-side yếu hơn (Faithfulness 0.607) —
   ([[03-checkpoint3-golden-dataset-rag-benchmark]]).
3. **Bài học 5 Whys quan trọng nhất** ([[04-checkpoint4-failure-analysis-reflection]]):
   điểm số thấp nhất (A01, A03) là false alarm của metric word-overlap; case
   nguy hiểm thật (H02 — trả lời "Yes" sai cho câu hỏi đáp án đúng là "No")
   lại có điểm giữa bảng vì heuristic không phát hiện được kết luận bị đảo
   ngược. Đây là ví dụ tốt nhất để demo "tại sao failure analysis quan trọng
   hơn pass rate".
