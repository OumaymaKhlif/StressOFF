"""Event recommendation microservice for StressOFF."""
from __future__ import annotations

from datetime import datetime
import json
import os
from typing import Optional

import requests
from fastapi import APIRouter, FastAPI, HTTPException
from pydantic import BaseModel

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

router = APIRouter(tags=["event-recommendation"])


class EventRequest(BaseModel):
    eventTitle: str
    startTime: datetime
    endTime: datetime


class EventRecommendationResponse(BaseModel):
    eventTitle: str
    eventTime: str
    practices: str
    nutritionSuggestion: str
    purpose: str


@router.post("/generate-event-recommendation", response_model=EventRecommendationResponse)
async def generate_event_recommendation(request: EventRequest) -> EventRecommendationResponse:
    """Generate recommendations for a calendar event using OpenRouter."""
    event_title = request.eventTitle
    start_time = request.startTime
    end_time = request.endTime
    hour = start_time.hour
    duration_minutes = (end_time - start_time).total_seconds() / 60

    if hour < 12:
        meal_type = "nutritious breakfast"
        meal_examples = "eggs, oatmeal, fresh fruits, yogurt"
    elif hour < 14:
        meal_type = "balanced lunch"
        meal_examples = "lean protein, whole grains, vegetables"
    elif hour < 17:
        meal_type = "light snack"
        meal_examples = "yogurt, fruit, nuts, energy bar"
    else:
        meal_type = "light evening snack"
        meal_examples = "calming tea, whole grain biscuit"

    prompt = f"""
    Calendar Event: {event_title}
    Time: {start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')} ({int(duration_minutes)} minutes)

    Generate a JSON response with:
    1. \"practices\": 2-3 short quick professional sentences with practical tips to reduce stress and improve focus before this event
    2. \"nutritionSuggestion\": a quick suggestion for {meal_type} ({meal_examples}) to optimize energy
    3. \"purpose\": the main objective in one sentence

    Be concise and professional.
    """

    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": "qwen/qwen2.5-vl-32b-instruct:free",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "response_format": {"type": "json_object"},
    }

    response = requests.post(OPENROUTER_URL, headers=headers, json=payload)
    if not response.ok:
        print("[OpenRouter] generate-event-recommendation error:", response.status_code, response.text)
        raise HTTPException(status_code=502, detail="OpenRouter provider error")

    try:
        result_json = response.json()
        choices = result_json.get("choices", [])
        if not choices:
            raise HTTPException(status_code=502, detail="No choices returned by OpenRouter")
        content_str: Optional[str] = choices[0]["message"].get("content")
        if content_str is None:
            raise HTTPException(status_code=502, detail="Empty response from OpenRouter")
        result = json.loads(content_str)
    except (ValueError, KeyError) as exc:
        print("[OpenRouter] JSON parse error:", exc)
        raise HTTPException(status_code=502, detail="Unexpected response from OpenRouter") from exc

    return EventRecommendationResponse(
        eventTitle=event_title,
        eventTime=f"{start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')}",
        practices="\n".join([f"✔️ {p}" for p in result.get("practices", [])]),
        nutritionSuggestion=result.get("nutritionSuggestion", ""),
        purpose=result.get("purpose", ""),
    )


def create_app() -> FastAPI:
    app = FastAPI(title="StressOFF Event Recommendation Service")
    app.include_router(router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {
            "message": "StressOFF Event Recommendation Service",
            "version": "1.0.0",
        }

    return app


app = create_app()
