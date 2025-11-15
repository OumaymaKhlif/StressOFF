"""Daily meal summary microservice for StressOFF."""
from __future__ import annotations

import json
import os
from typing import List

import requests
from fastapi import APIRouter, FastAPI, HTTPException
from pydantic import BaseModel

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

router = APIRouter(tags=["daily-analysis"])


class Nutrition(BaseModel):
    calories: float
    proteins: float
    carbs: float
    fats: float
    fibers: float


class MealAnalysis(BaseModel):
    userId: str
    mealType: str
    timestamp: str
    dishName: str
    ingredients: List[str]
    nutrition: Nutrition
    healthAdvice: str
    recommendation: str
    allergiesDetected: List[str] = []


class DailyAnalysisRequest(BaseModel):
    userId: str
    date: str
    meals: List[MealAnalysis]


@router.post("/analyze-daily")
async def analyze_daily(request: DailyAnalysisRequest) -> dict:
    try:
        total_calories = sum(meal.nutrition.calories for meal in request.meals)
        total_proteins = sum(meal.nutrition.proteins for meal in request.meals)
        total_carbs = sum(meal.nutrition.carbs for meal in request.meals)
        total_fats = sum(meal.nutrition.fats for meal in request.meals)
        total_fibers = sum(meal.nutrition.fibers for meal in request.meals)

        meals_summary = "\n".join(
            f"- {meal.mealType}: {meal.dishName} ({meal.nutrition.calories:.0f} kcal)"
            for meal in request.meals
        )
        prompt = f"""You are a professional AI nutritionist.
                     Analyze the following daily meals and provide a detailed nutritional summary in professional English.
**Daily Meals**:
{meals_summary}

**Total Nutrition**:
- Calories: {total_calories:.0f} kcal
- Proteins: {total_proteins:.1f}g
- Carbs: {total_carbs:.1f}g
- Fats: {total_fats:.1f}g
- Fibers: {total_fibers:.1f}g

**Recommended Daily Targets**:
- Calories: 2000 kcal
- Proteins: 60g
- Carbs: 250g
- Fats: 70g
- Fibers: 30g

Return ONLY a strict JSON object:

{{
    "globalAdvice": "Detailed nutritional summary",
    "recommendations": "Recommendations to improve balance",
    "needsMet": true/false
}}
"""
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "qwen/qwen2.5-vl-32b-instruct:free",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
            "response_format": {"type": "json_object"},
        }
        response = requests.post(OPENROUTER_URL, headers=headers, json=data)
        response.raise_for_status()

        result = response.json()
        choices = result.get("choices")
        if not choices:
            print("[OpenRouter] analyze-daily unexpected payload:", result)
            error_detail = result.get("error", {}).get("message") if isinstance(result, dict) else None
            raise HTTPException(
                status_code=502,
                detail=error_detail or "Unexpected response from OpenRouter.",
            )
        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        content = (message or {}).get("content") if isinstance(message, dict) else None
        if not content:
            print("[OpenRouter] analyze-daily missing content:", result)
            raise HTTPException(status_code=502, detail="Empty response from OpenRouter. Please retry later.")

        daily_analysis = json.loads(content)
        needs_met = daily_analysis.get("needsMet", False)
        if isinstance(needs_met, str):
            needs_met = needs_met.strip().lower() in {"true", "oui", "yes", "1"}

        summary = {
            "id": f"{request.userId}_{request.date}",
            "userId": request.userId,
            "date": request.date,
            "mealAnalysisIds": [str(meal.timestamp) for meal in request.meals],
            "totalNutrition": {
                "calories": total_calories,
                "proteins": total_proteins,
                "carbs": total_carbs,
                "fats": total_fats,
                "fibers": total_fibers,
            },
            "globalAdvice": daily_analysis.get("globalAdvice", ""),
            "recommendations": daily_analysis.get("recommendations", ""),
            "needsMet": bool(needs_met),
        }
        return summary
    except Exception as exc:
        raise HTTPException(status_code=500, detail=f"Daily analysis error: {exc}") from exc


def create_app() -> FastAPI:
    app = FastAPI(title="StressOFF Daily Analysis Service")
    app.include_router(router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {
            "message": "StressOFF Daily Analysis Service",
            "version": "1.0.0",
        }

    return app


app = create_app()
