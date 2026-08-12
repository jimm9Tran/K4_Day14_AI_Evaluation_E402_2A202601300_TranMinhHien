# Checkpoint 3 — Golden Dataset, RAG & Benchmark

**Hoàn thành:** [[00-index|Index]] · sau [[02-checkpoint2-part2-core-coding]] ·
File thay đổi: `golden_dataset.json`, `exercises.md` (Exercises 3.1–3.3) ·
Artifact: `artifacts/actual_answers.json`, `artifacts/benchmark_results.json`

Ghi chú này giải thích corpus thật của lab, cách 20 câu hỏi được thiết kế, và
**vì sao** kết quả benchmark trông "tệ" (pass rate 60%) lại không có nghĩa là
có bug — dành cho người chưa quen đọc kết quả evaluation.

---

## ⚠️ Sửa một nhầm lẫn quan trọng

Hướng dẫn Part 3 mà bạn dán vào mô tả một corpus **"student services"**
(academic calendar, tuition, scholarships...) — nhưng repo này thực tế dùng
corpus **OrbitTech Store Customer Support** tại `data/technology_store/`
(xem `README.md` dòng 7, `guide_lab.md` Mục 5.1). Toàn bộ golden dataset dưới
đây được viết theo đúng corpus thật của repo, không phải theo ví dụ
student-services đã dán nhầm.

## 1. Corpus: 10 documents, một domain support cửa hàng công nghệ hư cấu

`data/technology_store/manifest.json` liệt kê 10 file Markdown, mỗi file phủ
một mảng chủ đề (xem bảng trong `guide_lab.md` Mục 5.1). Toàn bộ nội dung là
**synthetic** (giả lập) — quan trọng nhất: đây là **nguồn sự thật duy nhất**
của lab, kể cả khi nó khác kiến thức thực tế của bạn về chính sách cửa hàng
thật. Nếu expected answer không được corpus hỗ trợ, phải sửa câu hỏi/answer,
**không** sửa corpus (nguyên tắc chống "hack benchmark bằng cách sửa đề").

## 2. Golden dataset: 20 câu, 4 mức độ khó, "trap" có chủ đích

`golden_dataset.json` (`validate_golden_dataset.py` → `PASS`, 20/20, phủ
10/10 documents) được thiết kế theo đúng 4 nhóm:

- **Easy (E01–E05)** — factual lookup 1 document, ví dụ E05: "Initial repair
  diagnosis takes how long?" → trả lời trực tiếp từ một câu duy nhất trong
  `07_repair_and_technical_support.md`.
- **Medium (M01–M07)** — mỗi câu cố tình ghép evidence từ **2 document khác
  nhau** (ví dụ M01 ghép `08_accounts_privacy_and_security.md` +
  `02_orders_and_payments.md` cho tình huống "tài khoản bị hack, đơn hàng
  chưa xử lý"), buộc retriever phải lấy đúng cả hai nguồn và generator phải
  tổng hợp chúng lại.
- **Hard (H01–H05)** — tập trung vào **policy version theo ngày hiệu lực**
  (`09_escalation_and_policy_updates.md`): H02 là một cái bẫy thật — dễ nghĩ
  "member đang active thì luôn được 45 ngày trả hàng", nhưng rule thật đòi
  hỏi *đơn hàng phải đặt từ 1/9/2026* (version 2.0) **và** membership active
  tại thời điểm đặt hàng; đơn đặt trước 1/9 giữ nguyên cửa sổ 21 ngày dù có
  là member hay không.
- **Adversarial (A01–A03)** — ba loại tấn công đã khóa sẵn: A01 hỏi ngoài
  scope (tư vấn y tế), A02 chèn prompt injection ("ignore your previous
  instructions..."), A03 là false-premise trap (giả định assistant có thể
  "xem đơn hàng live" và "unlock account" — hai việc bị cấm rõ trong
  `00_system_scope.md`).

**Bài học thiết kế quan trọng nhất:** evidence (`contexts[].text`) phải là
**substring nguyên văn** của file Markdown gốc — không được tự sửa dấu câu,
khoảng trắng hay từ ngữ, dù chỉ một ký tự. `validate_golden_dataset.py` kiểm
tra điều này bằng phép so khớp chuỗi con chính xác; đây là lý do
"evidence provenance" là một khái niệm riêng biệt với "câu trả lời nghe có
vẻ đúng" — evidence phải **chứng minh được** answer, không chỉ hỗ trợ ý
tưởng chung chung.

## 3. Sinh actual answers: không data leakage

`python domain_assistant.py` chạy RAG thật (BM25 retriever + `gpt-4o-mini`)
trên cả 20 câu, chỉ đọc `id` và `question` — **không đọc `expected_answer`
hay gold `contexts`** (đã giải thích lý do ở
[[01-checkpoint1-part1-warmup]] mục 2: tránh "học sinh cầm đáp án đi thi").
Kết quả: `artifacts/actual_answers.json` — 20/20 câu có `actual_answer` không
rỗng, có `retrieved_contexts`, `error: null`.

## 4. Đọc kết quả benchmark: vì sao pass rate 60% KHÔNG có nghĩa là lỗi

Đây là phần dễ hiểu lầm nhất. Kết quả tổng hợp:

```
Pass rate: 60.0%
Avg Context Recall:    0.833   ← retriever khá tốt
Avg Context Precision: 0.958   ← retriever RẤT tốt (chunk đúng gần như luôn đứng đầu)
Avg Faithfulness:      0.607   ← YẾU NHẤT
Avg Relevance:         0.626
Avg Completeness:      0.617
```

Retrieval gần như hoàn hảo (Precision 0.958!) nhưng Faithfulness lại thấp
nhất — theo đúng logic đã học ở Checkpoint 1: **retrieval tốt + faithfulness
thấp → nghi ngờ generation**, không phải retriever. Nhưng đào sâu từng case
lại lộ ra một điều quan trọng hơn — **giới hạn của chính công cụ đo**:

- **M04** (Recall 0.435, Completeness 0.391 — cả hai đều thấp, trong khi
  Precision vẫn 1.000): đây **mới thực sự** là lỗi retriever — nó bỏ sót
  evidence cần thiết (recall thấp), nên câu trả lời thiếu thông tin
  (completeness thấp đi theo). Khác hẳn cơ chế của M06.
- **M06** (Recall 0.759, Precision 0.756 — ổn — nhưng Faithfulness 0.295):
  retriever lấy đúng evidence, nhưng model "diễn giải thêm" bằng từ ngữ
  không khớp context → đúng mẫu lỗi generation.
- **A01, A03 — hai case điểm thấp nhất (0.216 và 0.385)**: đây **không phải
  hallucination thật**. Assistant từ chối đúng theo policy (`00_system_scope.md`),
  nhưng heuristic word-overlap của `template.py` chỉ đếm từ trùng nhau giữa
  answer và context/expected_answer tham chiếu — một lời từ chối lịch sự
  diễn đạt khác hoàn toàn so với câu tham chiếu sẽ bị chấm gần 0 dù **hành vi
  hoàn toàn đúng**. Đây chính là lý do bài học nhấn mạnh: heuristic đơn giản
  (đếm từ) không thay thế được LLM-as-a-Judge cho các case cần đánh giá
  *ý nghĩa/hành vi* thay vì *độ giống câu chữ* — xem rubric ở mục 5.

**Kết luận:** không nên dừng lại ở "pass rate 60% → RAG kém". Phải bóc tách
từng metric cho từng case mới biết vấn đề nằm ở retriever (M04), generator
(M06), hay ở chính giới hạn của cách đo (A01/A03). README cũng nói rõ:
benchmark score không quyết định điểm lab — cách phân tích mới là thứ được
đánh giá.

## 5. Rubric LLM-as-a-Judge (Exercise 3.3) — chấm "đúng chính sách", không
chấm "giống chữ"

Rubric 1–5 được thiết kế quanh 4 dimension: Correctness, Completeness,
Evidence/citation, Safety/Privacy — với **thứ tự ưu tiên cứng**: vi phạm
Safety/Privacy luôn ép điểm về 1 bất kể phần còn lại tốt thế nào; một claim
không có evidence luôn chặn điểm ở tối đa 2. Đây là cách "phạt claim không
evidence" và "xử lý privacy/safety failure" cụ thể thay vì rubric mơ hồ kiểu
"5 = tốt, 1 = xấu". Ba edge case khó chấm được ghi trong `exercises.md` —
đáng chú ý nhất là edge case đầu tiên: **rubric của LLM judge chính là cách
sửa sai lầm mà A01/A03 vừa lộ ra** — judge chấm theo "có xác định đúng scope
và hướng dẫn đúng không", không so khớp câu chữ với reference string.

## Cách tự kiểm chứng

```bash
python validate_golden_dataset.py
# PASS: dataset structure and evidence provenance are valid.
# Difficulty: easy=5, medium=7, hard=5, adversarial=3
# Document coverage: 10/10

python domain_assistant.py     # cần OPENAI_API_KEY trong .env
python evaluate_answers.py     # in bảng Exercise 3.2, ghi artifacts/benchmark_results.json
```

Tiêu chí nghiệm thu CP3: validator PASS + đủ 5/7/5/3 ✓, 20 actual answers
không lỗi ✓, Exercise 3.2 (5 metrics + 3 case thấp nhất) và Exercise 3.3
(rubric 1–5) đã điền đầy đủ trong `exercises.md` ✓.

Bước tiếp theo: `guide_lab.md` Mục 11 — Part 4, viết `reflection.md` với ba
phân tích 5 Whys cho các failure case (gợi ý: A01/A03 là ví dụ tốt để phân
tích "false failure do giới hạn metric" thay vì lỗi hệ thống thật), improvement
log, và regression strategy.
