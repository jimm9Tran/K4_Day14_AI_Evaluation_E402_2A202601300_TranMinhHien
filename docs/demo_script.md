# Kịch bản Demo — AI Evaluation & Benchmarking Pipeline

**Thời lượng đề xuất:** ~7 phút trình bày + Q&A. Mở sẵn 4 file trước khi bắt
đầu: `golden_dataset.json`, `solution/solution.py`, `exercises.md`,
`reflection.md`. Chạy sẵn `pytest tests/ -v` một lần trước giờ demo để không
mất thời gian chờ cài đặt.

> Mẹo: nếu muốn có màn hình trực quan song song, mở thêm
> [`docs/demo.html`](demo.html) trong trình duyệt — bảng điều khiển này tóm
> tắt toàn bộ 5 bước dưới đây bằng biểu đồ, có thể chiếu thay vì scroll file
> nếu giám khảo thích nhìn tổng quan trước.

---

## 0. Mở đầu (30 giây)

> "Em xin demo lab AI Evaluation — xây dựng pipeline đánh giá cho một trợ lý
> RAG hỗ trợ khách hàng của OrbitTech Store. Em sẽ đi qua 5 phần: golden
> dataset, evaluation engine, kết quả benchmark thật, một ca lỗi tiêu biểu,
> và chiến lược chống tụt chất lượng."

---

## 1. Golden Dataset (1 phút)

**Show:** `golden_dataset.json`

**Nói:**
> "Em viết 20 câu hỏi theo đúng phân bổ 5 Easy – 7 Medium – 5 Hard – 3
> Adversarial, dựa trên corpus thật `data/technology_store/` — 10 tài liệu
> synthetic về OrbitTech Store."

Cuộn nhanh qua 3 case, mỗi case nói 1 câu:

| Case | Nói gì |
|---|---|
| `E01` (Easy) | "Factual lookup đơn giản, một document." |
| `H02` (Hard) | "Đây là một cái bẫy em cố tình thiết kế: order đặt 28/8, còn active membership — nhưng vì đặt *trước* 1/9/2026 nên vẫn chỉ được 21 ngày trả hàng, không phải 45 ngày. Em sẽ quay lại case này ở phần lỗi." |
| `A03` (Adversarial) | "False-premise trap — câu hỏi giả định assistant có thể xem đơn hàng live, việc mà `00_system_scope.md` cấm rõ." |

**Chạy lệnh (nếu muốn chứng minh evidence không bịa):**
```bash
python validate_golden_dataset.py
```
→ đọc to kết quả: `PASS`, `Document coverage: 10/10`.

---

## 2. Evaluation Pipeline (1.5 phút)

**Show:** `solution/solution.py`

**Nói:**
> "Đây là engine chấm điểm — 5 Task: Data Models, RAGASEvaluator, LLMJudge,
> BenchmarkRunner, FailureAnalyzer. Toàn bộ heuristic dùng word-overlap,
> không gọi LLM, để chấm nhanh và tái lập được."

Cuộn nhanh tới `evaluate_context_precision` (dòng ~236) — điểm kỹ thuật đáng
nói nhất:

> "Đây là phần khó nhất: Context Precision không chỉ đếm chunk đúng, mà tính
> **rank-aware Average Precision** — chunk liên quan đứng càng sớm càng được
> điểm cao, mô phỏng đúng cách RAGAS thật đánh giá retriever."

**Chạy lệnh:**
```bash
pytest tests/ -v
```
→ đọc to dòng cuối: `41 passed, 1 skipped`.

> "1 skip là `rerank_by_overlap()` — bonus Exercise 3.5, không bắt buộc."

---

## 3. Kết quả Benchmark (2 phút)

**Show:** `exercises.md` → mục **Exercise 3.2 — Benchmark Run**

**Nói:**
> "Đây là benchmark chạy thật — không mock. `domain_assistant.py` gọi
> gpt-4o-mini thật trên corpus thật cho cả 20 câu."

Đọc to **Aggregate Report**:

```
Overall pass rate: 60.0%
Avg Context Recall: 0.833
Avg Context Precision: 0.958
Avg Faithfulness: 0.607
Avg Relevance: 0.626
Avg Completeness: 0.617
```

> "Điểm đáng chú ý: retrieval rất tốt — Precision 0.958, gần như luôn xếp
> đúng chunk lên đầu. Nhưng answer-side (Faithfulness, Relevance,
> Completeness) đều dưới 0.65 — điều này gợi ý vấn đề nghiêng về
> **generation** hơn retrieval."

Đọc to **3 case Overall Score thấp nhất**:

```
1. A01 | 0.216 | hallucination
2. A03 | 0.385 | off_topic
3. M04 | 0.451 | hallucination
```

> "Nhưng — và đây là điều quan trọng nhất em rút ra từ cả bài lab — ba con
> số thấp nhất **không đồng nghĩa với ba lỗi nghiêm trọng nhất**. Em sẽ demo
> ngay sau đây."

---

## 4. Một Failure Tiêu Biểu (2 phút)

**Show:** `reflection.md` → mục **2. Top 3 Worst Failures** → **Failure 3
(M04)**

Đây là case rõ nhất để trình bày vì: **evidence trace + điểm số đồng thuận
100%** — không cần giải thích thêm ngoại lệ nào, đúng một câu chuyện kỹ
thuật sạch từ đầu đến cuối.

**Nói theo đúng thứ tự trong file:**

> "Câu hỏi: *'NovaBook của tôi có lỗi bảo hành nhưng đã hết hạn trả hàng —
> quy trình nào áp dụng, và repair request cần gì?'*
>
> Expected answer có **hai phần**: (1) đi theo quy trình sửa chữa, (2) cần
> serial number, contact info, symptoms, proof of purchase.
>
> Actual answer trả lời đúng phần 1, nhưng **hoàn toàn thiếu phần 2** — thay
> vào đó nói về backup dữ liệu và loaner device.
>
> Em kiểm tra evidence trace: retriever lấy đúng chunk cho phần 1
> (`06_warranty_policy.md`, rank 1). Nhưng cho phần 2, thay vì lấy đúng câu
> *'A repair request requires the product serial number...'* trong
> `07_repair_and_technical_support.md`, retriever lại lấy một đoạn **khác**
> trong CÙNG document — về backup dữ liệu — vì đoạn đó khớp từ khóa câu hỏi
> tốt hơn theo BM25.
>
> Đi qua 5 Whys: retriever lấy sai đoạn → BM25 là lexical thuần, không hiểu
> ý định 'repair request cần gì' → không có bước rerank để bù khi một câu
> hỏi cần nhiều sub-fact từ cùng document → **root cause: retrieval/chunking
> hiện tại không tách đủ tốt các sub-fact trong cùng document cho câu hỏi
> nhiều phần**.
>
> Fix đề xuất: thêm reranking hoặc tăng `top_k` có kiểm soát. Verify bằng
> Context Recall của M04 — mục tiêu ≥ 0.7 mà không làm giảm Precision."

**Bonus 30 giây (nếu còn thời gian) — điểm nhấn của cả bài lab:**

> "Case nguy hiểm nhất thực ra **không nằm trong top 3** — đó là H02, case
> bẫy em nói ở phần 1. Model trả lời **'Yes, được 45 ngày'** trong khi đúng
> phải là **'No, chỉ 21 ngày'** — nhưng vì các từ xung quanh vẫn khớp với
> câu trả lời đúng, Faithfulness của nó vẫn đạt 0.706, Overall 0.618 — cao
> hơn hẳn A01, A03, M04. Đây là giới hạn quan trọng nhất em học được: điểm
> trung bình có thể **không phát hiện được một kết luận Yes/No bị đảo
> ngược**."

---

## 5. Cách Ngăn Chất Lượng Giảm (1 phút)

**Show:** `reflection.md` → mục **5. Regression Testing Strategy**

**Nói, tóm tắt 4 câu trả lời:**

> "Em dùng `run_regression()` đã cài trong `BenchmarkRunner` làm quality
> gate:
>
> 1. **Khi nào chạy:** trước mỗi lần merge có đổi prompt, retriever, model,
>    hoặc corpus — so với baseline đã lưu, đúng tinh thần CI/CD.
> 2. **Threshold 0.05 có đủ không:** chưa đủ cho domain này — Faithfulness
>    đang ở 0.607, sát ranh giới nghiêm trọng, nên em đề xuất threshold chặt
>    hơn (0.03) riêng cho Faithfulness/Completeness.
> 3. **Block vs Alert:** Faithfulness giảm quá threshold, hoặc bất kỳ case
>    Hard 'policy trap' nào bị lật kết luận Yes/No — như H02 vừa nói — thì
>    **block deploy**. Relevance/Completeness dao động nhẹ chỉ **alert**.
> 4. **Pipeline 3 tầng:** offline benchmark tự động → LLM-as-a-Judge review
>    riêng cho case adversarial/version-trap → human spot-check cuối cùng —
>    trước khi deploy."

---

## Kết (15 giây)

> "Tóm lại: pipeline chạy đúng, 41/42 test pass, benchmark thật trên 20 câu
> hỏi, và quan trọng nhất — em không dừng ở pass rate 60%, mà lần theo từng
> case để phân biệt lỗi thật với giới hạn của công cụ đo. Em sẵn sàng trả
> lời câu hỏi."

---

## Câu hỏi khả năng cao & gợi ý trả lời

| Câu hỏi giám khảo có thể hỏi | Gợi ý trả lời ngắn |
|---|---|
| "Tại sao pass rate chỉ 60%, không cao hơn?" | 8/20 case fail — nhưng 3/8 (A01, A02, A03) là false alarm của heuristic word-overlap, không phải lỗi hệ thống thật (dẫn evidence trace). |
| "Sao biết evidence trong golden dataset là đúng?" | `validate_golden_dataset.py` kiểm tra máy (substring nguyên văn) — nhưng "evidence có đủ chứng minh claim không" phải tự review thủ công, máy không làm được (ví dụ tự phát hiện ở case A01). |
| "Nếu chỉ sửa được một thứ, sửa gì trước?" | Sửa prompt buộc model xác nhận điều kiện trước khi kết luận cho câu hỏi phụ thuộc policy version — giải quyết H02, rủi ro tài chính thật cho khách, ưu tiên High trong failure clustering. |
| "LLMJudge đã cài nhưng dùng chưa?" | Đã cài (Task 3, 4/4 test pass) nhưng chưa nối vào benchmark pipeline chính — đề xuất bổ sung làm lớp chấm thứ hai cho case adversarial. |
| "Sao chọn ngưỡng 0.5 để pass?" | Là ngưỡng có sẵn trong core gốc (`run_full_eval`); em có phân tích riêng ở Exercise 1.3 rằng Faithfulness nên chặt hơn (0.7) do rủi ro tài chính cao hơn Relevance/Completeness. |
