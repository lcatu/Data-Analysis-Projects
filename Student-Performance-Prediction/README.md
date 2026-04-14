# 🎓 Student Performance Prediction Using Regression Models

<div align="center">

![Python](https://img.shields.io/badge/Python-3.8%2B-3776AB?style=for-the-badge&logo=python&logoColor=white)
![scikit-learn](https://img.shields.io/badge/scikit--learn-1.x-F7931E?style=for-the-badge&logo=scikit-learn&logoColor=white)
![Pandas](https://img.shields.io/badge/Pandas-2.x-150458?style=for-the-badge&logo=pandas&logoColor=white)
![Jupyter](https://img.shields.io/badge/Jupyter-Notebook-F37626?style=for-the-badge&logo=jupyter&logoColor=white)
![Status](https://img.shields.io/badge/Grade-A-brightgreen?style=for-the-badge)

**Ứng dụng các mô hình hồi quy để dự đoán kết quả học tập của sinh viên**  
*Banking Academy of Vietnam — Data Mining & Analytics | 2025*

</div>

---

## 📌 Overview

Đề tài xây dựng mô hình dự đoán điểm thi cuối kỳ của sinh viên dựa trên **6,600+ bản ghi thực tế** từ bộ dữ liệu `StudentPerformanceFactors.csv` (Kaggle). Qua đó phân tích định lượng các yếu tố như thời gian tự học, tỉ lệ tham gia lớp, giấc ngủ, áp lực học tập, v.v.

### 🏆 Key Results

| Model | R² (Valid) | RMSE (Valid) | R² (Test) |
|---|---|---|---|
| Linear Regression | 0.9414 | 0.8091 | 0.8781 |
| Ridge Regression | 0.9414 | 0.8091 | — |
| Lasso Regression | 0.9414 | 0.8088 | — |
| **Polynomial Regression (degree=2)** | **0.9609** | **0.6609** | **0.8936** |

> 🥇 **Polynomial Regression (degree=2)** đạt R² cao nhất trong khi vẫn duy trì thời gian huấn luyện tối ưu (0.19s vs 135s ở degree=5).

---

## 📊 Dataset

**Source:** [StudentPerformanceFactors.csv](https://www.kaggle.com/) — Kaggle

| Thuộc tính | Mô tả |
|---|---|
| `Hours_Studied` | Số giờ tự học mỗi tuần |
| `Attendance` | Tỉ lệ tham gia lớp học (%) |
| `Previous_Scores` | Điểm học kỳ trước |
| `Tutoring_Sessions` | Số buổi học gia sư/tháng |
| `Sleep_Hours` | Giờ ngủ trung bình mỗi đêm |
| `Motivation_Level` | Mức động lực học tập (Low/Medium/High) |
| `Parental_Involvement` | Mức độ hỗ trợ từ gia đình |
| `Access_to_Resources` | Khả năng tiếp cận tài nguyên học tập |
| `Exam_Score` | ⭐ **Biến mục tiêu** — Điểm thi cuối kỳ |
| ... | *(20 features tổng cộng)* |

---

## 🔍 Correlation Highlights

Từ ma trận tương quan Pearson:

```
Exam_Score ← Hours_Studied    : 0.50  ✅ Tương quan mạnh
Exam_Score ← Attendance        : 0.66  ✅ Tương quan mạnh nhất
Exam_Score ← Previous_Scores   : 0.20  ⚠️  Tương quan yếu
Exam_Score ← Sleep_Hours        : -0.01 ❌ Gần như không tương quan
Exam_Score ← Physical_Activity  : 0.04  ❌ Gần như không tương quan
```

---

## 🗂️ Project Structure

```
student-performance-prediction/
│
├── 📓 Final_BTL_Nhóm2.ipynb          # Main notebook (EDA + Modeling + Evaluation)
│
├── 📁 data/
│   └── StudentPerformanceFactors.csv  # Raw dataset (6,607 records × 20 features)
│
├── 📁 reports/
│   └── kq_ptdl.pdf                    # Full project report (Vietnamese)
│
└── 📄 README.md
```

> **Note:** Toàn bộ pipeline (EDA → Preprocessing → Modeling → Evaluation) được thực hiện trong **một notebook duy nhất** phản ánh đúng workflow thực tế của dự án.

---

## ⚙️ Pipeline

```
Raw Data (6,607 rows)
        ↓
1. EDA & Visualization
   ├── Distribution plots (numeric & categorical)
   ├── Boxplot → Outlier detection
   └── Correlation matrix (Pearson)
        ↓
2. Preprocessing
   ├── Missing value imputation (mode)
   ├── Outlier capping (IQR method)
   ├── Label Encoding  → Ordinal features
   ├── One-Hot Encoding → Nominal features
   └── StandardScaler  → Numeric features
        ↓
3. Train / Valid / Test Split (70 / 15 / 15)
        ↓
4. Model Training & Tuning
   ├── Linear Regression   (baseline)
   ├── Ridge Regression    (alpha via 5-fold CV)
   ├── Lasso Regression    (alpha via 5-fold CV)
   └── Polynomial Regression (degree = 2,3,4,5)
        ↓
5. Regression Assumption Tests
   ├── Linearity          ✅ Both models pass
   ├── Independence (DW)  ✅ DW ≈ 2.0
   ├── Homoscedasticity   ❌ Rejected (p < 0.05) — discrete data structure
   └── Normality (QQ-plot) ✅ Both models pass
        ↓
6. Final Evaluation on Test Set
```

---

## 📈 Model Performance Detail

### Polynomial Regression (Degree Comparison)

| Degree | Features | Training Time | R² (Valid) | RMSE (Valid) |
|---|---|---|---|---|
| 2 | 324 | 0.20s | **0.9609** | **0.6609** |
| 3 | 2,924 | 12.08s | 0.8414 | 1.3304 |
| 4 | 20,474 | 37.53s | 0.7310 | 1.7329 |
| 5 | 118,754 | 135.91s | 0.7964 | 1.5074 |

**→ Degree=2 tối ưu nhất:** R² cao nhất + thời gian chạy nhanh nhất.

### Regression Assumption Tests Summary

| Assumption | Linear | Polynomial |
|---|---|---|
| Linearity | ✅ Pass | ✅ Pass |
| Independence (Durbin-Watson) | ✅ DW=1.980 | ✅ DW=2.031 |
| Homoscedasticity | ❌ Rejected | ❌ Rejected |
| Normality (QQ-plot + Histogram) | ✅ Pass | ✅ Pass (more symmetric) |

---

## 🚀 Quick Start

### 1. Clone repo

```bash
git clone https://github.com/<your-username>/student-performance-prediction.git
cd student-performance-prediction
```

### 2. Install dependencies

```bash
pip install -r requirements.txt
```

### 3. Run notebook

```bash
jupyter notebook "Final_BTL_Nhóm2.ipynb"
```

---

## 📦 Requirements

```txt
pandas>=1.5.0
numpy>=1.23.0
matplotlib>=3.6.0
seaborn>=0.12.0
scikit-learn>=1.1.0
statsmodels>=0.13.0
scipy>=1.9.0
jupyter>=1.0.0
```

---

## 💡 Key Insights

1. **Attendance** là yếu tố tác động mạnh nhất đến điểm thi (r = 0.66)
2. **Hours_Studied** đứng thứ hai (r = 0.50)
3. **Sleep_Hours** và **Physical_Activity** gần như không tương quan — dữ liệu có thể không phản ánh thực tế đầy đủ
4. Polynomial Regression (degree=2) nắm bắt được các **mối quan hệ phi tuyến nhẹ** mà Linear Regression bỏ qua
5. Cả Ridge và Lasso đều không cải thiện đáng kể so với Linear — cho thấy dữ liệu sau preprocessing có **đa cộng tuyến thấp**

---

## 🏫 About

| | |
|---|---|
| **Course** | Data Mining & Analytics (Khai phá và Phân tích Dữ liệu) |
| **Institution** | Banking Academy of Vietnam (Học viện Ngân hàng) |
| **Instructor** | ThS. Lê Thị Hồng Nhung |
| **Team** | Nhóm 2 — 5 members |
| **Period** | 11/2025 – 12/2025 |
| **Grade** | A |

---

## 📄 License

This project is for academic purposes only.
