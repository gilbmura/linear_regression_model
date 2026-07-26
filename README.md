# JAMB Score Predictor — Regression Analysis Mobile Application

## Mission and Problem

My mission is to improve education outcomes in Africa through data-driven early intervention.
Every year over 1.5 million Nigerian students sit the JAMB UTME university-entrance exam, and most discover too late that they are below the cut-off for their dream course.
This project predicts a student's JAMB score (0–400) from study habits, school characteristics and socioeconomic factors,
so schools and students can identify risk early and act (extra tutorials, attendance support, learning materials) **before** the real exam.

## Dataset

- **Source:** [Students Performance in 2024 JAMB — Kaggle](https://www.kaggle.com/datasets/idowuadamo/students-performance-in-2024-jamb)
- **Size / richness:** 5,000 students × 17 columns — a mix of numeric variables (study hours per week, attendance rate, distance to school, age) and categorical variables (school type, location, parental involvement, socioeconomic status, parent education level), with real-world imperfections (~18% missing values in `Parent_Education_Level`).
- **Target:** `JAMB_Score` — continuous, 0–400.

The full analysis (visualizations, feature engineering, standardization, and a comparison of
SGD linear regression, OLS linear regression, decision tree and random forest) is in
[`summative/linear_regression/multivariate.ipynb`](summative/linear_regression/multivariate.ipynb).
The best model by test MSE (Linear Regression, test RMSE ≈ 39.1 points) is saved and served by the API.

## Public API (Swagger UI)

- **Swagger UI:** https://jamb-predictor-api.onrender.com/docs
- **Prediction endpoint:** `POST https://jamb-predictor-api.onrender.com/predict`
- **Retraining endpoint:** `POST https://jamb-predictor-api.onrender.com/retrain` (upload a CSV of new observations; the model retrains and hot-swaps if it performs at least as well)

> Note: the API runs on Render's free tier, which sleeps after ~15 minutes of inactivity — the
> first request after a pause can take up to a minute while the service wakes up.

Example request body for `/predict`:

```json
{
  "study_hours_per_week": 20,
  "attendance_rate": 85,
  "teacher_quality": 3,
  "distance_to_school": 5.5,
  "parent_involvement": 1,
  "it_knowledge": 1,
  "extra_tutorials": 1,
  "parent_education_level": 2,
  "assignments_completed": 2,
  "socioeconomic_status": 1,
  "school_type": 0
}
```

Every input is type-enforced and range-constrained with Pydantic (e.g. `attendance_rate` must be a number in 0–100, `teacher_quality` an integer in 1–5). Out-of-range or missing values return a descriptive `422` error.

### CORS configuration reasoning

The API restricts cross-origin access instead of allowing `*`:

- **Allowed origins:** only local development hosts and the deployed API domain itself (for Swagger UI). The Flutter *mobile* app sends no `Origin` header, so it is unaffected.
- **Allowed methods:** `GET`, `POST`, `OPTIONS` only — no endpoint uses PUT/DELETE, so they stay blocked.
- **Allowed headers:** `Content-Type` only, which is all the JSON/multipart requests need.
- **Credentials:** disabled — the API is stateless with no cookies or sessions, so credentialed cross-origin requests are refused.

## Video Demo

- **YouTube:** https://www.youtube.com/watch?v=xjrWaRj3NUY  

## Repository structure

```
summative/
├── linear_regression/
│   ├── multivariate.ipynb    # Task 1: analysis + model training
│   ├── best_model.pkl        # saved best model (with scaler + encodings)
│   └── data/                 # Kaggle dataset
├── API/
│   ├── prediction.py         # Task 2: FastAPI service (predict + retrain)
│   ├── best_model.pkl        # model artifact served by the API
│   └── requirements.txt      # for Render deployment
├── FlutterApp/               # Task 3: mobile app
├── pyproject.toml            # uv-managed project
└── uv.lock
```

## How to run

### 1. Python environment (uv)

```bash
cd summative
pip install uv          # if uv is not installed
uv sync                 # creates .venv and installs everything
```

### 2. Notebook

```bash
cd summative
uv run jupyter lab linear_regression/multivariate.ipynb
```

### 3. API (locally)

```bash
cd summative/API
uv run uvicorn prediction:app --reload --port 8000
# Swagger UI: http://127.0.0.1:8000/docs
```

### 4. Mobile app (Flutter)

Prerequisites: [Flutter SDK](https://docs.flutter.dev/get-started/install) and an Android emulator or physical device.

```bash
cd summative/FlutterApp
flutter pub get
flutter run          # select your emulator/device when prompted
```

The app shows 11 input fields (one per model feature), a **Predict** button, and a display area
that shows the predicted JAMB score or a clear error message for missing/out-of-range values.
The API base URL lives in `lib/config.dart` (`apiBaseUrl`) — it defaults to `http://10.0.2.2:8000`
(local API from the Android emulator) and should be switched to the Render URL for production use.
