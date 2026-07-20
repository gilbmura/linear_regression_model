"""
JAMB Score Prediction API (Task 2).

Serves the best-performing regression model trained in
summative/linear_regression/multivariate.ipynb and exposes:

- POST /predict  -> predict a student's JAMB UTME score (0-400)
- POST /retrain  -> upload new rows (CSV) and retrain the model from the
                    existing artifact, hot-swapping it on success
- GET  /         -> redirects to the Swagger UI at /docs

Run locally:  uvicorn prediction:app --reload
"""

from pathlib import Path
from typing import Literal

import joblib
import numpy as np
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from sklearn.linear_model import SGDRegressor
from sklearn.metrics import mean_squared_error
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"
BASE_DATA_PATH = BASE_DIR / "data" / "jamb_exam_results.csv"
UPLOADS_DIR = BASE_DIR / "data" / "uploads"

app = FastAPI(
    title="JAMB Score Prediction API",
    description=(
        "Predicts a Nigerian student's JAMB UTME score (0-400) from study "
        "habits, school characteristics and socioeconomic factors. "
        "Model: linear regression trained on the Kaggle dataset "
        "'Students Performance in 2024 JAMB'."
    ),
    version="1.0.0",
)

# --- CORS -------------------------------------------------------------------
# Reasoning (see README):
# * allow_origins: NOT a wildcard. Only the origins that legitimately call
#   this API from a browser context are listed: local Flutter-web/dev hosts
#   and the Swagger UI served from the deployed domain itself. The native
#   mobile app does not send an Origin header, so it is unaffected by CORS.
# * allow_methods: only POST (predict/retrain), GET (docs/health) and the
#   OPTIONS preflight. Anything else (PUT/DELETE/...) is restricted because
#   no endpoint uses it.
# * allow_headers: only Content-Type is needed (JSON and multipart bodies).
# * allow_credentials: False - the API is stateless and uses no cookies or
#   auth sessions, so credentialed cross-origin requests stay blocked.
ALLOWED_ORIGINS = [
    "http://localhost",
    "http://localhost:8080",
    "http://localhost:3000",
    "http://127.0.0.1:8080",
    "https://jamb-predictor-api.onrender.com",
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["Content-Type"],
)

# --- Model artifact ----------------------------------------------------------
_artifact: dict = joblib.load(MODEL_PATH)


class StudentInput(BaseModel):
    """One student's data. Every field is type- and range-constrained."""

    study_hours_per_week: float = Field(
        ..., ge=0, le=60, description="Hours spent studying per week",
        json_schema_extra={"example": 20},
    )
    attendance_rate: float = Field(
        ..., ge=0, le=100, description="Class attendance percentage",
        json_schema_extra={"example": 85},
    )
    teacher_quality: int = Field(
        ..., ge=1, le=5, description="Teacher quality rating: 1 (poor) to 5 (excellent)",
        json_schema_extra={"example": 3},
    )
    distance_to_school: float = Field(
        ..., ge=0, le=50, description="Distance from home to school in km",
        json_schema_extra={"example": 5.5},
    )
    parent_involvement: int = Field(
        ..., ge=0, le=2, description="Parental involvement: 0=Low, 1=Medium, 2=High",
        json_schema_extra={"example": 1},
    )
    it_knowledge: int = Field(
        ..., ge=0, le=2, description="IT knowledge: 0=Low, 1=Medium, 2=High",
        json_schema_extra={"example": 1},
    )
    extra_tutorials: int = Field(
        ..., ge=0, le=1, description="Attends extra tutorials: 0=No, 1=Yes",
        json_schema_extra={"example": 1},
    )
    access_to_learning_materials: int = Field(
        ..., ge=0, le=1, description="Has access to learning materials: 0=No, 1=Yes",
        json_schema_extra={"example": 1},
    )

    def to_feature_row(self, feature_order: list[str]) -> pd.DataFrame:
        values = {
            "Study_Hours_Per_Week": self.study_hours_per_week,
            "Attendance_Rate": self.attendance_rate,
            "Teacher_Quality": self.teacher_quality,
            "Distance_To_School": self.distance_to_school,
            "Parent_Involvement": self.parent_involvement,
            "IT_Knowledge": self.it_knowledge,
            "Extra_Tutorials": self.extra_tutorials,
            "Access_To_Learning_Materials": self.access_to_learning_materials,
        }
        return pd.DataFrame([[values[f] for f in feature_order]], columns=feature_order)


class PredictionResponse(BaseModel):
    prediction: float = Field(description="Predicted JAMB score (0-400)")
    model_name: str
    unit: Literal["JAMB score points"] = "JAMB score points"


class RetrainResponse(BaseModel):
    message: str
    rows_added: int
    total_training_rows: int
    old_test_mse: float
    new_test_mse: float
    model_swapped: bool


@app.get("/", include_in_schema=False)
def root() -> RedirectResponse:
    return RedirectResponse(url="/docs")


@app.get("/health", tags=["Monitoring"])
def health() -> dict:
    return {"status": "ok", "model": _artifact["model_name"]}


@app.post("/predict", response_model=PredictionResponse, tags=["Prediction"])
def predict(student: StudentInput) -> PredictionResponse:
    """Predict the JAMB UTME score for one student."""
    row = student.to_feature_row(_artifact["features"])
    row_scaled = _artifact["scaler"].transform(row)
    raw = float(_artifact["model"].predict(row_scaled)[0])
    return PredictionResponse(
        prediction=round(float(np.clip(raw, 0, 400)), 1),
        model_name=_artifact["model_name"],
    )


def _load_training_frame() -> pd.DataFrame:
    """Base dataset plus every accepted upload."""
    frames = [pd.read_csv(BASE_DATA_PATH)]
    if UPLOADS_DIR.exists():
        frames += [pd.read_csv(p) for p in sorted(UPLOADS_DIR.glob("*.csv"))]
    return pd.concat(frames, ignore_index=True)


def _prepare_xy(df: pd.DataFrame) -> tuple[pd.DataFrame, pd.Series]:
    df = df.copy()
    if "Parent_Education_Level" in df.columns and df["Parent_Education_Level"].isna().any():
        df["Parent_Education_Level"] = df["Parent_Education_Level"].fillna(
            df["Parent_Education_Level"].mode()[0]
        )
    for col, mapping in {**_artifact["ordinal_maps"], **_artifact["binary_maps"]}.items():
        if col in df.columns and not pd.api.types.is_numeric_dtype(df[col]):
            df[col] = df[col].map(mapping)
    missing = [c for c in _artifact["features"] + [_artifact["target"]] if c not in df.columns]
    if missing:
        raise HTTPException(
            status_code=422,
            detail=f"Uploaded data is missing required columns: {missing}",
        )
    X = df[_artifact["features"]]
    y = df[_artifact["target"]]
    if X.isna().any().any() or y.isna().any():
        raise HTTPException(
            status_code=422,
            detail="Uploaded data contains missing or un-mappable values in model columns.",
        )
    return X, y


@app.post("/retrain", response_model=RetrainResponse, tags=["Model management"])
async def retrain(file: UploadFile = File(...)) -> RetrainResponse:
    """
    Upload a CSV of new observations (same schema as the original dataset,
    including the JAMB_Score column) and retrain the model.

    The new model replaces the current one only if it does not perform worse
    than the existing model on the fresh held-out test split.
    """
    global _artifact

    if not (file.filename or "").lower().endswith(".csv"):
        raise HTTPException(status_code=422, detail="Please upload a .csv file.")

    UPLOADS_DIR.mkdir(parents=True, exist_ok=True)
    upload_path = UPLOADS_DIR / f"upload_{len(list(UPLOADS_DIR.glob('*.csv'))) + 1}.csv"
    content = await file.read()
    upload_path.write_bytes(content)

    try:
        new_rows = pd.read_csv(upload_path)
        _prepare_xy(new_rows)  # validate the upload on its own before training
        full = _load_training_frame()
        X, y = _prepare_xy(full)
    except HTTPException:
        upload_path.unlink(missing_ok=True)  # reject bad uploads entirely
        raise
    except Exception as exc:
        upload_path.unlink(missing_ok=True)
        raise HTTPException(status_code=422, detail=f"Could not parse CSV: {exc}") from exc

    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    scaler = StandardScaler()
    X_train_s = scaler.fit_transform(X_train)
    X_test_s = scaler.transform(X_test)

    new_model = SGDRegressor(
        loss="squared_error", penalty="l2", alpha=1e-4,
        learning_rate="invscaling", eta0=0.01,
        max_iter=2000, tol=1e-4, random_state=42,
    )
    new_model.fit(X_train_s, y_train)
    new_mse = float(mean_squared_error(y_test, new_model.predict(X_test_s)))

    old_mse = float(_artifact.get("test_mse", np.inf))
    # Hot-swap unless the retrained model is clearly worse (>10% loss increase)
    swap = new_mse <= old_mse * 1.10

    if swap:
        _artifact = {
            **_artifact,
            "model": new_model,
            "model_name": "SGD Linear Regression (retrained)",
            "scaler": scaler,
            "test_mse": new_mse,
        }
        joblib.dump(_artifact, MODEL_PATH)

    return RetrainResponse(
        message=(
            "Model retrained and deployed."
            if swap
            else "Model retrained but NOT deployed (worse than current model)."
        ),
        rows_added=len(new_rows),
        total_training_rows=len(X),
        old_test_mse=round(old_mse, 3),
        new_test_mse=round(new_mse, 3),
        model_swapped=swap,
    )
