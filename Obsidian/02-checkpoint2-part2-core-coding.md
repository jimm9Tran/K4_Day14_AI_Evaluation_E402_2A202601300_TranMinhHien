# Checkpoint 2 — Part 2 Core Coding

**Hoàn thành:** [[00-index|Index]] · sau [[01-checkpoint1-part1-warmup]] · File thay
đổi: `template.py` (toàn bộ 5 Task) · Kết quả: `pytest tests/ -v` → **41 passed,
1 skipped**

Ghi chú này giải thích **cách** 5 Task được cài đặt và **vì sao** chọn công
thức đó — dành cho người chưa quen đọc code chấm điểm AI.

---

## Tổng quan: mỗi Task giải quyết một câu hỏi khác nhau

| Task | Câu hỏi trả lời | Vị trí code |
|---|---|---|
| 1 — Data Models | "Một câu hỏi + một kết quả chấm điểm cần lưu những gì?" | `template.py:38` (`QAPair`), `template.py:64` (`EvalResult`) |
| 2 — RAGASEvaluator | "Đo độ tốt của một câu trả lời bằng con số như thế nào?" | `template.py:144` |
| 3 — LLMJudge | "Dùng một AI khác để chấm điểm theo rubric ra sao?" | `template.py:384` |
| 4 — BenchmarkRunner | "Chạy hàng loạt câu hỏi và tổng hợp báo cáo thế nào?" | `template.py:509` |
| 5 — FailureAnalyzer | "Từ các câu trả lời sai, tìm nguyên nhân và đề xuất sửa ra sao?" | `template.py:618` |

## Task 1 — Data Models

`QAPair` (`template.py:57-61`) là **một dòng trong đề thi**: câu hỏi
(`question`), đáp án mẫu (`expected_answer`), đoạn văn bản nguồn
(`context`), thông tin phụ (`metadata`, ví dụ độ khó), và danh sách chunk
retriever thực sự lấy được (`retrieved_contexts`).

`EvalResult` (`template.py:92-100`) là **một dòng kết quả chấm bài**: giữ lại
`qa_pair` gốc, câu trả lời thật (`actual_answer`), ba điểm answer-side, cờ
`passed`, loại lỗi nếu có, và hai điểm retrieval-side (`context_recall`,
`context_precision` — mặc định `None`).

`overall_score()` chỉ đơn giản là trung bình cộng ba điểm answer-side —
**không** gồm hai điểm retrieval, vì retrieval chỉ dùng để *chẩn đoán*, theo
đúng thiết kế đã ghi trong docstring gốc.

## Task 2 — RAGASEvaluator: đo "độ tốt" bằng đếm từ trùng nhau

Đây là phần quan trọng nhất để hiểu. Lab dùng một heuristic đơn giản: **đếm
số từ khóa chung** giữa hai đoạn văn bản, thay vì gọi một AI khác để chấm
(cách đó tốn tiền và chậm hơn nhiều — dùng để dạy khái niệm trước khi dùng
công cụ thật như RAGAS/DeepEval ở môi trường production).

```
faithfulness = |từ trong answer ∩ từ trong context| / |từ trong answer|
relevance    = |từ trong answer ∩ từ trong question| / |từ trong question|
completeness = |từ trong answer ∩ từ trong expected| / |từ trong expected|
```

Ví dụ dễ hiểu: nếu answer là "Paris is the capital of France" và context có
chứa đúng các từ đó, hầu hết từ trong answer đều "tìm thấy" trong context →
faithfulness gần 1.0. Nếu answer nói về "bananas" trong khi context nói về
"Python programming", gần như không từ nào trùng → faithfulness gần 0.

Code dùng `_tokenize()` có sẵn (`template.py:136`) để cắt câu thành tập hợp
từ, đã tự động bỏ qua các từ nối vô nghĩa như "is", "a", "the" (`STOPWORDS`,
`template.py:129`) — nếu không loại các từ này, mọi câu đều "trùng nhau" giả
tạo vì câu nào cũng có "is"/"a"/"the".

**Điểm quan trọng khi cài đặt** (`template.py:165-170` và tương tự cho hai
hàm kia): luôn kiểm tra tập từ ở **mẫu số** có rỗng không trước khi chia, trả
về `1.0` nếu rỗng (theo đúng yêu cầu trong docstring) để tránh
`ZeroDivisionError` — đây là lỗi runtime hay gặp nhất nếu code thiếu bước
này.

### Context Recall & Context Precision — chấm điểm retriever, không phải generator

Hai hàm này (`template.py:216`, `template.py:236`) khác chỗ: chúng nhận vào
**một danh sách chunk** (`contexts: list[str]`) thay vì một đoạn văn bản, vì
chúng đánh giá bước *Retriever* trong pipeline, không phải bước *Generator*.

- `evaluate_context_recall`: gộp tất cả chunk lại (`union_tokens`), rồi hỏi
  "trong đống từ đã gộp đó, có đủ từ của `expected_answer` không?" — đo khả
  năng **tìm đủ** bằng chứng của retriever.
- `evaluate_context_precision`: đây là phần khó nhất — **rank-aware Average
  Precision (AP@K)**. Khác với recall (không quan tâm thứ tự), precision
  quan tâm **chunk liên quan có đứng sớm không**. Cách tính
  (`template.py:260-277`): đánh dấu từng chunk là "relevant" hay không (dựa
  trên % từ trùng với expected), rồi với mỗi vị trí `k` mà chunk đó relevant,
  cộng dồn `(số relevant tính đến k) / k`, cuối cùng chia cho tổng số chunk
  relevant. Chunk relevant đứng ở vị trí 1 đóng góp `1/1 = 1.0` vào tổng,
  còn cũng chunk đó đứng ở vị trí 2 chỉ đóng góp `1/2 = 0.5` — đây chính là
  cơ chế "thưởng" cho thứ tự tốt.

## Task 3 — LLMJudge: dùng một AI để chấm một AI khác

`LLMJudge` không tự tính điểm — nó nhận một hàm callable (`judge_llm_fn`,
`template.py:389`) đại diện cho lời gọi tới một model chấm điểm (có thể là
OpenAI thật, hoặc trong test chỉ là một hàm giả trả về chuỗi JSON cố định —
đây gọi là **mocking**, giúp test không cần gọi API thật).

`score_response()` (`template.py:402`) làm 3 bước: (1) ghép câu hỏi + câu trả
lời + rubric thành một prompt (`_build_prompt`, `template.py:392`), (2) gọi
`judge_llm_fn(prompt)`, (3) thử `json.loads()` kết quả trả về — nếu parse
được và toàn số thì dùng làm điểm, nếu không (model trả lời bằng văn xuôi
thay vì JSON, chuyện thường gặp với LLM thật) thì **fallback về điểm mặc
định 0.5** cho mọi tiêu chí thay vì crash chương trình.

`detect_bias()` (`template.py:447`) implement 3 kiểm tra từ Exercise 1.2:
`leniency_bias`/`severity_bias` chỉ là so trung bình điểm với 0.8/0.3.
`positional_bias` giả định `scores_batch` được truyền vào theo cặp xen kẽ
"chấm lần 1 / chấm lần 2" của cùng một thí nghiệm đảo vị trí (đúng thiết kế
experiment ở Exercise 1.2 Câu 1) — so trung bình các vị trí chẵn (lần đầu)
với vị trí lẻ (lần sau), lệch quá 0.2 thì coi là có bias.

## Task 4 — BenchmarkRunner: chạy hàng loạt và tổng hợp

`run()` (`template.py:514`) là vòng lặp đơn giản: với mỗi `QAPair`, gọi
`agent_fn(question)` để lấy câu trả lời thật, rồi đưa vào
`evaluator.run_full_eval()`. Điểm cần chú ý:
`contexts=pair.retrieved_contexts or None` — nếu pair không có dữ liệu
retrieval nào (danh sách rỗng, ví dụ dữ liệu test thủ công), truyền `None`
thay vì `[]`, để hai điểm retrieval-side giữ nguyên `None` thay vì bị tính
sai thành 0 trên "chứng cứ rỗng".

`generate_report()` (`template.py:545`) tổng hợp trung bình các điểm —
riêng hai điểm retrieval chỉ tính trung bình trên các `EvalResult` **có**
giá trị (không phải `None`), nếu không có kết quả nào mang retrieval data
thì trả về `None` cho cả trung bình đó.

`run_regression()` (`template.py:590`) so sánh điểm trung bình giữa lần chạy
mới và baseline; một metric bị coi là "regression" (thụt lùi) nếu **giảm quá
0.05** — đây là logic điển hình của CI/CD quality gate: nếu deploy mới làm
model tệ đi rõ rệt so với bản đang chạy, chặn lại.

`identify_failures()` (`template.py:636`) chỉ lọc các `EvalResult` có **bất
kỳ** điểm nào (faithfulness/relevance/completeness) dưới ngưỡng.

## Task 5 — FailureAnalyzer: từ điểm số tới hành động sửa

`categorize_failures()` (`template.py:681`) đếm số lần mỗi `failure_type`
xuất hiện — đây là bước "clustering" nói trong bài giảng: nhóm các lỗi giống
nhau lại trước khi sửa, vì một root cause có thể giải quyết nhiều failure
cùng lúc.

`find_root_cause()` (`template.py:697`) áp dụng đúng logic đã phân tích ở
[[01-checkpoint1-part1-warmup]] mục 4: tìm điểm **thấp nhất** trong ba điểm
answer-side, rồi map sang một trong 4 câu giải thích cố định. Nếu có từ hai
điểm đồng thấp nhất trở lên (ví dụ faithfulness và relevance bằng nhau) —
trả về `"Multiple issues detected"` vì không thể quy trách nhiệm rõ ràng cho
một bước duy nhất trong pipeline.

`generate_improvement_suggestions()` (`template.py:754`) map mỗi loại lỗi
sang một gợi ý cụ thể (ví dụ `hallucination` → "thêm bộ lọc hallucination"),
rồi bổ sung thêm gợi ý chung chung ở cuối nếu danh sách chưa đủ 3 mục — đúng
yêu cầu "ít nhất 3 gợi ý".

`generate_improvement_log()` (`template.py:725`) ghép mọi thứ trên thành một
bảng Markdown — đây chính là artifact dùng trong `reflection.md` Phần 4
(Improvement Log) sau này.

## Cách tự kiểm chứng

```bash
pytest tests/ -v
# 41 passed, 1 skipped — 1 skip là rerank_by_overlap() (bonus Exercise 3.5,
# chưa cài đặt, không bắt buộc)

python template.py
# Chạy mock_agent trên 5 câu hỏi mẫu — không gọi API, không phải benchmark
# thật, chỉ để xem toàn bộ pipeline (RAGASEvaluator → BenchmarkRunner →
# FailureAnalyzer) chạy nối tiếp nhau không lỗi.
```

Từng Task đã được xác nhận bằng đúng targeted test tương ứng (không chỉ nhìn
tổng số cuối), khớp tiêu chí nghiệm thu CP2:

- Task 1: `TestEvalResultOverallScore` → 3 passed
- Task 2: `TestRAGASEvaluator` + `TestContextMetrics` +
  `test_run_full_eval_connects_optional_retrieval_metrics` → 14 passed, 1
  skipped
- Task 3: `TestLLMJudge` → 4 passed
- Task 4: `TestBenchmarkRunner` + `TestRunRegression` +
  `test_runner_forwards_retrieved_contexts` +
  `test_report_includes_retrieval_averages` → 11 passed
- Task 5: `TestFailureAnalyzer` + `TestGenerateImprovementLog` → 9 passed

Bước tiếp theo: `guide_lab.md` Mục 5 — Part 3, xây Golden Dataset thật
(`golden_dataset.json`) và chạy RAG thật qua `domain_assistant.py`.
`template.py` **chưa** copy sang `solution/solution.py` — bước đó nằm ở Mục
13, sau khi Part 3–4 hoàn thành.
