# app.py
from fastapi import FastAPI, File, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from PIL import Image
import io

app = FastAPI()
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST","GET","OPTIONS"],
    allow_headers=["*"],
)

class Prediction(BaseModel):
    label: str
    confidence: float
    kcal: int
    protein_g: float
    fat_g: float
    carbs_g: float

@app.post("/predict", response_model=Prediction)
async def predict(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    # Dummy predictor: return fixed values or simple heuristic based on image size
    width, height = image.size
    area = width * height
    if area > 200000:
        label = "Large portion - rice and chicken"
        kcal = 650
    else:
        label = "Small portion - salad"
        kcal = 220
    # Return JSON
    return Prediction(
        label=label,
        confidence=0.88,
        kcal=kcal,
        protein_g=20.0,
        fat_g=12.0,
        carbs_g=60.0
    )

@app.get("/health")
def health():
    return {"status":"ok","model":"dummy-v0"}
