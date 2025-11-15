"""Health analysis microservice for StressOFF."""
from __future__ import annotations

import json
import os
from typing import Dict, List, Optional

import requests
from fastapi import APIRouter, FastAPI, HTTPException
from pydantic import BaseModel

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

router = APIRouter(tags=["health-analysis"])


class HealthMetric(BaseModel):
    timestamp: str
    heartRate: float
    restingHeartRate: float
    hrv: float
    steps: int
    calories: float
    activeMinutes: int
    spo2: Optional[float] = None


class SleepData(BaseModel):
    durationHours: float
    qualityScore: float
    deepSleepMinutes: int
    remSleepMinutes: int
    lightSleepMinutes: int


class HealthAnalysisRequest(BaseModel):
    userId: str
    date: str
    metrics: List[HealthMetric]
    sleepData: Optional[SleepData] = None
    userProfile: Optional[Dict] = None


def _coerce_text(value) -> str:
    if value is None:
        return ""
    if isinstance(value, list):
        return " ".join(str(item) for item in value if item not in (None, ""))
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


@router.post("/analyze-health")
async def analyze_health(request: HealthAnalysisRequest) -> dict:
    try:
        if not request.metrics:
            raise HTTPException(status_code=400, detail="No health metrics provided")

        hrv_values = [m.hrv for m in request.metrics]
        hr_values = [m.heartRate for m in request.metrics]
        resting_hr_values = [m.restingHeartRate for m in request.metrics]
        spo2_values = [m.spo2 for m in request.metrics if m.spo2 is not None]

        median_hrv = sorted(hrv_values)[len(hrv_values) // 2]
        avg_resting_hr = sum(resting_hr_values) / len(resting_hr_values)
        avg_spo2 = sum(spo2_values) / len(spo2_values) if spo2_values else None

        total_steps = sum(m.steps for m in request.metrics)
        total_calories = sum(m.calories for m in request.metrics)
        total_active_minutes = sum(m.activeMinutes for m in request.metrics)

        hrv_variance = sum((x - median_hrv) ** 2 for x in hrv_values) / len(hrv_values)
        stress_level = min(10, hrv_variance / 10)

        alerts: List[str] = []
        if len(hrv_values) > 1:
            half = len(hrv_values) // 2
            hrv_baseline = sum(hrv_values[:half]) / max(half, 1)
            hrv_recent = sum(hrv_values[half:]) / max(len(hrv_values) - half, 1)
            if hrv_baseline > 0 and (hrv_baseline - hrv_recent) / hrv_baseline > 0.20:
                alerts.append("HRV dropped more than 20% - possible stress or overtraining")

        if request.sleepData and request.sleepData.durationHours < 6:
            alerts.append(f"Sleep duration low: {request.sleepData.durationHours:.1f}h (recommended: 7-9h)")

        if avg_spo2 and avg_spo2 < 94:
            alerts.append(f"Low blood oxygen: {avg_spo2:.1f}% (normal: >95%)")

        sedentary_hours = (24 * 60 - total_active_minutes) / 60
        if sedentary_hours > 22:
            alerts.append("Very low activity detected - try to move more throughout the day")

        profile = request.userProfile or {}
        sleep_info = ""
        if request.sleepData:
            sleep_info = f"""
Sleep last night:
- Duration: {request.sleepData.durationHours:.1f}h
- Quality score: {request.sleepData.qualityScore:.0f}/100
- Deep sleep: {request.sleepData.deepSleepMinutes} min
- REM sleep: {request.sleepData.remSleepMinutes} min
"""
        sleep_quality_description = ""
        if request.sleepData:
            score = request.sleepData.qualityScore
            duration = request.sleepData.durationHours
            if score >= 85 and duration >= 7:
                sleep_quality_description = "excellent and restful"
            elif score >= 70:
                sleep_quality_description = "good"
            elif score >= 50:
                if duration < 6:
                    sleep_quality_description = "short and likely interrupted"
                else:
                    sleep_quality_description = "fair, possibly light"
            else:
                if duration < 5:
                    sleep_quality_description = "very poor and short"
                else:
                    sleep_quality_description = "poor and likely fitful"

        alerts_text = "\n".join(f"- {alert}" for alert in alerts) if alerts else "No critical alerts"

        prompt = f"""You are a health AI coach. Analyze this user's daily health data and provide brief, actionable advice.

**User Profile:**
- Gender: {profile.get('gender', 'Not specified')}
- Weight: {profile.get('weight', 'Not specified')} kg
- Goal: {profile.get('goal', 'General health')}

**Today's Data (24h):**
{sleep_info}
- Resting HR: {avg_resting_hr:.0f} bpm
- HRV median: {median_hrv:.0f} ms
- Total steps: {total_steps:,}
- Calories burned: {total_calories:.0f} kcal
- Active time: {total_active_minutes} min
- Blood oxygen (SpO2): {avg_spo2:.1f}% if avg_spo2 else 'Not available'
- Estimated stress: {stress_level:.1f}/10

**Alerts:**
{alerts_text}

Provide a brief analysis in JSON format:

{{
    "summary": "One sentence describing today's health state",
    "action": "One concrete action to take today",
    "breakfastSuggestion": "Brief breakfast recommendation based on data",
    "indicatorToWatch": "Which metric to monitor (HR, HRV, steps, etc.)",
    "sleepRemark": "A short, encouraging sentence for the sleep card, in the format: 'Your sleep quality was {sleep_quality_description}. Let's start a day with a ... breakfast 💪'.",
    "sleepPractices": "If sleep was poor or decent, provide 2-3 bullet-pointed tips to improve it. If sleep was excellent, provide a brief encouraging message about maintaining good habits. Use \\n for new lines."
}}
"""
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "qwen/qwen2.5-vl-32b-instruct:free",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.3,
            "response_format": {"type": "json_object"},
            "max_tokens": 400,
        }

        response = requests.post(OPENROUTER_URL, headers=headers, json=data)
        if not response.ok:
            print("[OpenRouter] analyze-health error:", response.status_code, response.text)
            raise HTTPException(status_code=502, detail="Health analysis service temporarily unavailable")

        result = response.json()
        choices = result.get("choices")
        if not choices:
            print("[OpenRouter] analyze-health unexpected payload:", result)
            raise HTTPException(status_code=502, detail="Invalid response from health analysis service")

        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        content = (message or {}).get("content") if isinstance(message, dict) else None
        if not content:
            raise HTTPException(status_code=502, detail="Empty response from health analysis service")

        analysis = json.loads(content)

        return {
            "summary": _coerce_text(analysis.get("summary")),
            "action": _coerce_text(analysis.get("action")),
            "breakfastSuggestion": _coerce_text(analysis.get("breakfastSuggestion")),
            "indicatorToWatch": _coerce_text(analysis.get("indicatorToWatch")),
            "sleepRemark": _coerce_text(analysis.get("sleepRemark")),
            "sleepPractices": _coerce_text(analysis.get("sleepPractices")),
            "alerts": alerts,
            "dailyStats": {
                "avgRestingHR": round(avg_resting_hr, 1),
                "medianHRV": round(median_hrv, 1),
                "totalSteps": total_steps,
                "totalCalories": round(total_calories, 1),
                "totalActiveMinutes": total_active_minutes,
                "avgSpO2": round(avg_spo2, 1) if avg_spo2 else None,
                "stressLevel": round(stress_level, 1),
            },
        }
    except HTTPException:
        raise
    except Exception as exc:
        print(f"[HealthService] Health analysis error: {exc}")
        raise HTTPException(status_code=500, detail=f"Health analysis failed: {exc}") from exc


def create_app() -> FastAPI:
    app = FastAPI(title="StressOFF Health Analysis Service")
    app.include_router(router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {
            "message": "StressOFF Health Analysis Service",
            "version": "1.0.0",
        }

    return app


app = create_app()
