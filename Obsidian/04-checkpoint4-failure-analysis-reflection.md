# Checkpoint 4 — Failure Analysis & Reflection

**Hoàn thành:** [[00-index|Index]] · sau [[03-checkpoint3-golden-dataset-rag-benchmark]] ·
File thay đổi: `reflection.md` (toàn bộ 7 mục)

Ghi chú này tóm tắt phát hiện quan trọng nhất của cả lab — dành cho người
muốn hiểu **tại sao** phân tích thất bại (failure analysis) quan trọng hơn
việc chỉ nhìn con số pass rate.

---

## Phát hiện quan trọng nhất: điểm số "tệ nhất" không phải là vấn đề nghiêm
trọng nhất

Ba case điểm thấp nhất theo Overall Score là A01 (0.216), A03 (0.385), M04
(0.451). Nhưng sau khi soi kỹ evidence trace (câu hỏi, expected answer,
actual answer, retrieved chunks) trong `reflection.md`:

- **A01 và A03** hoá ra là **false alarm**: assistant đã từ chối đúng theo
  chính sách (`00_system_scope.md`), retriever lấy đúng evidence ở rank 1
  với Context Precision = 1.000 — nhưng heuristic đếm-từ-trùng của
  `RAGASEvaluator` chấm gần 0 vì câu trả lời diễn đạt khác hoàn toàn từ ngữ
  trong câu tham chiếu. Đây là giới hạn của công cụ đo, không phải lỗi hệ
  thống thật.
- **H02** — một case **không** nằm trong top-3 tệ nhất (Overall 0.618, đứng
  giữa bảng) — mới thực sự là case nguy hiểm nhất: model trả lời **"Yes"**
  cho câu hỏi mà đáp án đúng là **"No"** (nhầm lẫn giữa Return Policy version
  1.0 và 2.0 — đúng cái "trap" đã cố ý thiết kế ở [[03-checkpoint3-golden-dataset-rag-benchmark]]).
  Nhưng vì phần giải thích xung quanh vẫn dùng nhiều từ giống câu trả lời
  đúng, Faithfulness (0.706) và Relevance (0.778) vẫn ở mức khá — heuristic
  **không hề phát hiện được kết luận bị đảo ngược**.

Đây là bài học cốt lõi của cả bài lab: **một metric trung bình có thể "che"
đúng loại lỗi nguy hiểm nhất** (thông tin sai lệch ảnh hưởng quyết định tài
chính của khách hàng) trong khi lại "phóng đại" các case thực ra vô hại (từ
chối đúng nhưng diễn đạt khác). Failure analysis (đọc từng case, không chỉ
nhìn bảng xếp hạng) là bước bắt buộc, không phải tùy chọn.

## Ba nhóm lỗi (clustering) — ưu tiên sửa theo root cause, không theo tên metric

| Cluster | Root cause | Case | Ưu tiên |
|---|---|---|---|
| 1 | Model kết luận sai hoặc bỏ sót một phần câu hỏi nhiều điều kiện | H02, M01 | **High** — rủi ro tài chính thật cho khách |
| 2 | Retriever đúng document, sai đoạn con cụ thể (BM25 thuần lexical) | M04, M06 | Medium |
| 3 | Answer đúng ý, sai từ ngữ — heuristic đo sai, hệ thống không sai | A01, A02, A03 | Medium (ảnh hưởng độ tin cậy của benchmark, không ảnh hưởng khách hàng trực tiếp) |

Nếu chỉ sửa được một cluster, chọn **Cluster 1** — vì đây là cluster duy
nhất mà khách hàng có thể bị thiệt hại thật (ví dụ tin rằng còn 45 ngày để
trả hàng trong khi thực tế chỉ có 21 ngày).

## 5 Whys — ví dụ rút gọn cho case M04 (case retrieval thật)

```
Symptom: Context Recall thấp (0.435), answer thiếu "serial number,
         contact info, symptoms, proof of purchase"
  → Why 1: Retriever không lấy đúng câu chứa yêu cầu đó trong
           07_repair_and_technical_support.md
    → Why 2: BM25 lấy một đoạn KHÁC trong CÙNG document (về backup dữ liệu)
             vì đoạn đó khớp từ khóa câu hỏi tốt hơn
      → Why 3: BM25 là retriever thuần từ khóa, không hiểu ý định
               "repair request cần gì" nếu không trùng từ trực tiếp
        → Why 4: Không có bước rerank để bù khi một câu hỏi cần nhiều
                 sub-fact từ cùng một document
          → Root cause (có thể sửa): thiếu reranking/tăng top_k có kiểm
            soát cho câu hỏi multi-part — ĐÂY là root cause hành động được,
            không phải "AI trả lời sai" chung chung.
```

Đầy đủ ba case (A01, A03, M04) — bao gồm cả việc so sánh với
`find_root_cause()` (đồng ý hay không, dẫn evidence) — nằm trong
`reflection.md` Mục 2.

## Regression strategy — điểm mấu chốt

`run_regression()` (đã cài ở [[02-checkpoint2-part2-core-coding]]) so trung
bình 3 metric answer-side giữa lần chạy mới và baseline, cảnh báo khi giảm
> 0.05. `reflection.md` Mục 5 đề xuất tinh chỉnh: threshold 0.05 tuyệt đối
chưa đủ nhạy khi metric đã ở gần ranh giới "significant issues" (Faithfulness
hiện tại 0.607, chỉ cách 0.6 một chút) — nên dùng threshold chặt hơn (0.03)
cho Faithfulness/Completeness, và quan trọng hơn: **block deployment cứng**
nếu bất kỳ case Hard "policy version trap" nào bị lật kết luận Yes/No so với
baseline — vì đây chính là loại lỗi mà điểm trung bình có thể không phát
hiện được (bài học từ H02).

## Cách tự kiểm chứng

`reflection.md` đã có đủ:

- Mục 1: Benchmark summary với min/max/nhận xét cho cả 5 metric.
- Mục 2: Ba phân tích 5 Whys đầy đủ (A01, A03, M04), mỗi case đều đi tới
  root cause cụ thể + so sánh với `find_root_cause()` + fix + metric verify.
- Mục 3: Failure clustering 3 nhóm với priority.
- Mục 4: Improvement log (paste từ `generate_improvement_log()` thật) + 3
  suggestion ưu tiên kèm metric/cách verify.
- Mục 5: Regression strategy đầy đủ 4 câu hỏi.
- Mục 6–7: Continuous improvement loop + final reflection.

Đây là mục cuối cùng trong 4 checkpoint của lab. Bước tiếp theo (theo
`guide_lab.md` Mục 13): copy `template.py` → `solution/solution.py`, chạy
lại `pytest tests/ -v` một lần cuối trên bản solution, rà soát checklist
trong `README.md` trước khi nộp bài.
