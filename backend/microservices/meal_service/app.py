"""Meal analysis microservice for StressOFF."""
from __future__ import annotations

import base64
import json
import os
from io import BytesIO
from typing import Optional

import requests
from fastapi import APIRouter, FastAPI, File, Form, HTTPException, UploadFile
from pydantic import BaseModel
from PIL import Image

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

router = APIRouter(tags=["meal-analysis"])


class Nutrition(BaseModel):
    calories: float
    proteins: float
    carbs: float
    fats: float
    fibers: float


class MealAnalysis(BaseModel):
    dishName: str
    ingredients: list[str]
    nutrition: Nutrition
    healthAdvice: str
    recommendation: str
    allergiesDetected: list[str] = []


def compress_image(image_bytes: bytes, max_side: int = 800, quality: int = 75) -> bytes:
    """Downscale and compress user-provided images."""
    try:
        with Image.open(BytesIO(image_bytes)) as img:
            if img.mode != "RGB":
                img = img.convert("RGB")
            if max(img.size) > max_side:
                img.thumbnail((max_side, max_side))
            buffer = BytesIO()
            img.save(buffer, format="JPEG", quality=quality, optimize=True)
            return buffer.getvalue()
    except Exception as exc:  # pragma: no cover - defensive
        print("[MealService] image compression skipped:", exc)
    return image_bytes


def create_meal_prompt(user_profile: dict, meal_type: Optional[str] = None, user_allergies: Optional[list[str]] = None) -> str:
    """Create the LLM prompt for meal analysis."""
    context = f"""You are a professional AI dietitian specialized in Mediterranean, Tunisian, and French cuisine.
                  Analyze the provided meal image and respond strictly in professional English with clear, accurate, and coherent output.

**Profil Utilisateur** :
- Genre: {user_profile.get('gender', 'Non spécifié')}
- Poids: {user_profile.get('weight', 'Non spécifié')} kg
- Taille: {user_profile.get('height', 'Non spécifié')} cm
- Objectif: {user_profile.get('goal', 'Non spécifié')}
"""
    if user_allergies:
        context += f"- Known allergies: {', '.join(user_allergies)}\n"
    if meal_type:
        meal_types = {
            "breakfast": "Breakfast",
            "lunch": "Lunch",
            "dinner": "Dinner",
            "snack": "Snack",
        }
        context += f"- Meal type: {meal_types.get(meal_type, meal_type)}\n"
    context += """
**Task**:
1. Identify the dish name in English (exact Tunisian name if applicable, otherwise a description, all in english)
2. List main ingredients
3. Estimate macronutrients (typical portions)
4. Provide personalized health advice based on user profile
5. Suggest possible improvements or adjustments
6. Detect if any of the user's known allergies are present. If yes, list them clearly in `allergiesDetected`.

**IMPORTANT**: Return ONLY a strict JSON object without extra text:

{
    "dishName": "Dish name",
    "ingredients": ["ingredient1", "ingredient2", ...],
    "nutrition": {
        "calories": 0,
        "proteins": 0,
        "carbs": 0,
        "fats": 0,
        "fibers": 0
    },
    "healthAdvice": "Personalized health advice",
    "recommendation": "Suggested adjustments",
    "allergiesDetected": ["allergen1", "allergen2"]
}
"""
    return context


@router.post("/analyze-meal", response_model=MealAnalysis)
async def analyze_meal(
    image: UploadFile = File(...),
    userId: str = Form(...),  # noqa: ARG001  - kept for compatibility with clients
    mealType: Optional[str] = Form(None),
    userProfile: Optional[str] = Form(None),
) -> dict:
    try:
        image_data = await image.read()
        compressed_image_data = compress_image(image_data)
        if len(compressed_image_data) != len(image_data):
            print(
                f"[MealService] image compressed from {len(image_data)} to {len(compressed_image_data)} bytes"
            )
        image_base64 = base64.b64encode(compressed_image_data).decode("utf-8")

        profile = json.loads(userProfile) if userProfile else {}
        user_allergies = profile.get("allergies", [])
        prompt_text = create_meal_prompt(profile, mealType, user_allergies)

        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {"url": f"data:image/jpeg;base64,{image_base64}"},
                    },
                ],
            }
        ]
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "qwen/qwen2.5-vl-32b-instruct:free",
            "messages": messages,
            "temperature": 0.1,
            "response_format": {"type": "json_object"},
        }
        response = requests.post(OPENROUTER_URL, headers=headers, json=data)
        if not response.ok:
            print("[OpenRouter] analyze-meal error:", response.status_code, response.text)
            if response.status_code == 429:
                raise HTTPException(
                    status_code=429,
                    detail=(
                        "The analysis service is temporarily overloaded. "
                        "Please try again in a minute or use your own OpenRouter key."
                    ),
                )
            raise HTTPException(status_code=502, detail="OpenRouter provider error. Please try again later.")

        result = response.json()
        choices = result.get("choices")
        if not choices:
            print("[OpenRouter] analyze-meal unexpected payload:", result)
            error_detail = result.get("error", {}).get("message") if isinstance(result, dict) else None
            raise HTTPException(
                status_code=502,
                detail=error_detail or "Unexpected response from OpenRouter.",
            )
        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        analysis_text = (message or {}).get("content") if isinstance(message, dict) else None
        if not analysis_text:
            print("[OpenRouter] analyze-meal missing content:", result)
            raise HTTPException(status_code=502, detail="Empty response from OpenRouter. Please retry later.")
        analysis_json = json.loads(analysis_text)
        return analysis_json
    except json.JSONDecodeError as exc:
        raise HTTPException(status_code=500, detail=f"JSON decoding error: {exc}") from exc
    except HTTPException:
        raise
    except Exception as exc:  # pragma: no cover - defensive
        print("[MealService] analyze-meal exception:", str(exc))
        raise HTTPException(status_code=500, detail=f"Analysis error: {exc}") from exc


def create_app() -> FastAPI:
    app = FastAPI(title="StressOFF Meal Analysis Service")
    app.include_router(router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {
            "message": "StressOFF Meal Analysis Service",
            "version": "1.0.0",
        }

    return app


app = create_app()
