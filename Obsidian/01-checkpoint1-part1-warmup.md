# Checkpoint 1 — Part 1 Warm-up

**Hoàn thành:** [[00-index|Index]] · Task liên quan: hiểu kiến trúc pipeline +
`exercises.md` Exercises 1.1–1.3 · File thay đổi: `exercises.md`

Ghi chú này dành cho người **chưa biết gì** về "AI evaluation" — nếu bạn mới
nghe khái niệm RAG, LLM-as-a-Judge lần đầu, đọc phần "Khái niệm nền" trước.

---

## Khái niệm nền: tại sao phải "chấm điểm" một AI?

Một hệ AI trả lời câu hỏi (ở đây gọi là **RAG assistant** — Retrieval-Augmented
Generation) không phải lúc nào cũng trả lời đúng. Nó có thể: bịa thông tin
không có thật (gọi là **hallucination**), trả lời lạc đề, hoặc bỏ sót chi
tiết quan trọng (ví dụ quên nói ngày hết hạn đổi trả). "Evaluation" là quá
trình **đo lường một cách có hệ thống** xem AI trả lời tốt tới đâu, thay vì
chỉ đọc vài câu trả lời bằng mắt rồi "thấy ổn". README gọi đây là *scientific
method cho AI*: Hypothesis → Experiment → Measure → Conclude → Iterate — tức
là đưa ra giả thuyết ("model X tốt hơn"), thử nghiệm, đo bằng số, kết luận,
rồi lặp lại.

---

## 1. Ba thành phần trong pipeline — ai làm gì?

```
domain_assistant.py   →  SINH câu trả lời (system được đánh giá)
template.py            →  CHẤM điểm câu trả lời (evaluation engine)
evaluate_answers.py    →  NỐI hai bên lại + in báo cáo (chỉ làm I/O)
```

- **`domain_assistant.py`** — đây là "học sinh làm bài". Nó nhận một câu hỏi
  (`question`), tìm các đoạn văn bản liên quan trong tài liệu OrbitTech Store
  (`retrieve`, dùng thuật toán BM25 — một cách xếp hạng độ liên quan dựa trên
  từ khóa), rồi đưa các đoạn đó cho model OpenAI để sinh câu trả lời
  (`answer_with_trace`, `domain_assistant.py:312`). Nó **không hề biết** đáp
  án đúng là gì.
- **`template.py`** — đây là "giám khảo". Nó chứa các lớp:
  `RAGASEvaluator` (chấm điểm answer, `template.py:143`), `LLMJudge` (dùng
  một AI khác để chấm theo rubric, `template.py:306`), `BenchmarkRunner`
  (chạy toàn bộ bộ câu hỏi và tổng hợp báo cáo, `template.py:381`), và
  `FailureAnalyzer` (phân tích các câu trả lời sai, `template.py:490`). Đây
  là file học viên phải hoàn thiện TODO.
- **`evaluate_answers.py`** — đây là "người ghép đề thi với bài làm". Nó đọc
  `golden_dataset.json` (đề thi + đáp án mẫu) và `artifacts/actual_answers.json`
  (bài làm của `domain_assistant.py`), ghép chúng lại theo `id`
  (`load_evaluation_inputs`, `evaluate_answers.py:40`), đưa cho `template.py`
  chấm, rồi in bảng kết quả. File này **không tự chấm điểm** — nó chỉ nối dữ
  liệu, giữ đúng ranh giới trách nhiệm.

## 2. Vì sao `domain_assistant.py` không được đọc `expected_answer`?

Hãy tưởng tượng một học sinh đi thi mà được cầm sẵn đáp án khi làm bài — điểm
thi lúc đó không còn phản ánh năng lực thật của học sinh nữa. Với AI cũng
vậy: nếu `domain_assistant.py` được phép đọc `expected_answer` (đáp án mẫu)
hoặc gold context khi sinh câu trả lời, nó có thể "chép" gần đúng đáp án, và
benchmark sẽ luôn cho điểm cao dù hệ thống retrieval/generation thực tế có
thể rất kém khi gặp câu hỏi mới. Đây gọi là **data leakage** (rò rỉ dữ liệu
đánh giá vào quá trình sinh). README nhấn mạnh: `domain_assistant.py` **chỉ
đọc `id` và `question`** — xem README dòng 73–75 và code
`_load_questions` (`domain_assistant.py:345`) chỉ trích xuất đúng hai
trường đó từ dataset.

## 3. Bốn nhóm metrics đo cái gì khác nhau?

| Nhóm | Đo cái gì | Ví dụ trong domain OrbitTech |
|---|---|---|
| **Task Completion** | AI có hoàn thành "nhiệm vụ" hay không — nhị phân pass/fail hoặc partial credit | Khách hỏi cách đổi trả hàng — AI có đưa ra được quy trình hay không (bất kể diễn đạt hay/dở) |
| **Answer Quality** | Chất lượng nội dung câu trả lời: đúng, đủ, mạch lạc | Câu trả lời có đúng chính sách, đủ điều kiện, viết dễ hiểu không |
| **RAG-Specific** | Đo riêng từng bước của pipeline RAG: retriever lấy đúng chưa (faithfulness, relevance, context recall/precision) | Retriever có lấy đúng đoạn văn về "warranty policy" không; answer có bám sát đoạn đó không |
| **Business** | Tác động thực tế ngoài đời: người dùng hài lòng không, tốn bao nhiêu chi phí/thời gian | Tỷ lệ khách hàng không cần liên hệ nhân viên thật sau khi hỏi bot |

Bốn nhóm này **khác tầng đo lường**: Task Completion và Answer Quality nhìn
vào câu trả lời cuối cùng; RAG-Specific mổ xẻ từng bước bên trong pipeline
(retriever vs generator); Business nhìn ra ngoài, đo tác động thật với người
dùng — thứ mà điểm số kỹ thuật không tự động phản ánh.

## 4. Vì sao Recall/Completeness thấp → lỗi retriever, còn Faithfulness thấp
khi retrieval tốt → lỗi generation?

Đây là câu hỏi mấu chốt của Checkpoint 1. Nhớ lại pipeline RAG:

```
Question → Retriever → Context → Generator → Answer
```

- **Context Recall thấp** nghĩa là: trong số các đoạn văn bản cần thiết để
  trả lời đúng (`expected_answer`), retriever **không lấy được** đủ — tức
  lỗi xảy ra ở bước đầu tiên (Retriever → Context), trước khi generator kịp
  làm gì. Nếu context đưa vào generator vốn đã thiếu, thì dù generator "giỏi"
  cỡ nào, answer cũng khó đầy đủ — nên **Completeness thấp thường đi kèm
  Recall thấp**: generator không thể viết ra thông tin nó chưa từng được
  cho xem.
- Ngược lại, nếu **Context Recall cao** (retriever đã lấy đủ evidence) nhưng
  **Faithfulness vẫn thấp**, nghĩa là generator **có** đủ thông tin trong tay
  nhưng vẫn trả lời sai lệch hoặc thêm thắt thông tin ngoài context — lỗi
  nằm ở bước sau (Context → Answer), tức là generation/prompt, không phải
  retrieval. Đây chính là hallucination "kinh điển": không phải vì thiếu dữ
  liệu, mà vì model không bám sát dữ liệu được cho.

Nói ngắn gọn: **Recall/Completeness thấp → hỏi "retriever có tìm đủ không?"
Faithfulness thấp mà Recall cao → hỏi "generator có dùng đúng cái đã tìm
được không?"** Đây cũng là logic đằng sau `find_root_cause()` mà học viên
sẽ cài đặt ở Task 5 (`template.py:508`).

## 5. Đã hoàn thành trong `exercises.md`

- **Exercise 1.1** (dòng 31–37): bảng ngưỡng chấp nhận được / nghiêm trọng
  cho 5 metrics (Faithfulness, Answer Relevance, Context Recall, Context
  Precision, Completeness), kèm hành động cần làm khi điểm thấp là nghiêm
  trọng.
- **Exercise 1.2** (dòng 47–68 cũ, nay đã điền câu trả lời): thiết kế
  experiment phát hiện position bias (đảo vị trí hai answer, so tỷ lệ
  thắng theo vị trí); cách giảm verbosity bias bằng rubric tách tiêu chí
  khỏi độ dài; lý do phải calibrate LLM judge với nhãn người.
- **Exercise 1.3**: bảng threshold chặn deploy (Faithfulness 0.7, Answer
  Relevance 0.6, Completeness 0.6 — bám theo thang điểm chuẩn trong README
  và quy tắc "faithfulness < 0.7 không được deploy" trong `template.py`);
  và khi nào dùng offline / online / human evaluation.

## 6. Cách tự kiểm chứng

Phần Part 1 **chỉ là phân tích**, chưa đụng tới `template.py`, nên không có
lệnh `pytest` riêng cho checkpoint này. Cách xác nhận:

```bash
# Baseline vẫn phải sạch (không lỗi collection) trước khi làm tiếp Part 2
pytest tests/ -v   # kỳ vọng: 42 collected, 42 failed (chưa làm TODO)
```

Đọc lại `exercises.md` mục Part 1 và tự hỏi 3 câu ở đầu ghi chú này (vai trò
3 thành phần, 4 nhóm metrics, vì sao không đọc `expected_answer`) — nếu trả
lời được không cần nhìn lại tài liệu, coi như đạt Checkpoint 1. Bước tiếp
theo: Mục 4 của `guide_lab.md` — Part 2 Core Coding (Task 1: Data Models).
