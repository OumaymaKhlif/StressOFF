from fastapi import FastAPI, File, UploadFile, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from typing import Optional, List, Dict
import base64
import json
import requests
import os
from datetime import datetime
from io import BytesIO
from pydantic import BaseModel
from PIL import Image

# Create FastAPI app
app = FastAPI(title="CSTAM Meal Analysis API")

# # Enable CORS for all origins (allow cross-origin requests)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# OpenRouter API config
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

# --------------------- Pydantic Models ---------------------
# Nutrition info
class Nutrition(BaseModel):
    calories: float
    proteins: float
    carbs: float
    fats: float
    fibers: float

# Meal analysis data
class MealAnalysis(BaseModel):
    userId: str
    mealType: str
    timestamp: str
    dishName: str
    ingredients: List[str]
    nutrition: Nutrition
    healthAdvice: str
    recommendation: str
    allergiesDetected: Optional[List[str]] = []  # <- nouveau champ

# Daily meal analysis request
class DailyAnalysisRequest(BaseModel):
    userId: str
    date: str
    meals: List[MealAnalysis]

# Coaching request for AI coach
class CoachingRequest(BaseModel):
    userId: str
    message: str
    userProfile: Optional[Dict] = None
    conversationHistory: Optional[List[Dict]] = None

# Health metric data
class HealthMetric(BaseModel):
    timestamp: str
    heartRate: float
    restingHeartRate: float
    hrv: float
    steps: int
    calories: float
    activeMinutes: int
    spo2: Optional[float] = None

# Sleep data
class SleepData(BaseModel):
    durationHours: float
    qualityScore: float
    deepSleepMinutes: int
    remSleepMinutes: int
    lightSleepMinutes: int

# Health analysis request
class HealthAnalysisRequest(BaseModel):
    userId: str
    date: str
    metrics: List[HealthMetric]
    sleepData: Optional[SleepData] = None
    userProfile: Optional[Dict] = None

# Event data model
class EventRequest(BaseModel):
    eventTitle: str
    startTime: datetime
    endTime: datetime

# Event recommendation response model
class EventRecommendationResponse(BaseModel):
    eventTitle: str
    eventTime: str
    practices: str
    nutritionSuggestion: str
    purpose: str

# --------------------- API ENDPOINTS ---------------------
@app.post("/generate-event-recommendation", response_model=EventRecommendationResponse)
async def generate_event_recommendation(request: EventRequest):
    event_title = request.eventTitle
    start_time = request.startTime
    end_time = request.endTime
    hour = start_time.hour
    duration_minutes = (end_time - start_time).total_seconds() / 60

    # Determine meal type based on event time
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

    # Prepare prompt for AI
    prompt = f"""
    Calendar Event: {event_title}
    Time: {start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')} ({int(duration_minutes)} minutes)

    Generate a JSON response with:
    1. "practices": 2-3 short quick professional sentences with practical tips to reduce stress and improve focus before this event
    2. "nutritionSuggestion": a quick suggestion for {meal_type} ({meal_examples}) to optimize energy
    3. "purpose": the main objective in one sentence

    Be concise and professional.
    """

    # Set headers for OpenRouter request
    headers = {
        "Authorization": f"Bearer {OPENROUTER_API_KEY}",
        "Content-Type": "application/json"
    }

    payload = {
        "model": "qwen/qwen2.5-vl-32b-instruct:free",
        "messages": [{"role": "user", "content": prompt}],
        "temperature": 0.1,
        "response_format": {"type": "json_object"}
    }

    # Call OpenRouter API
    response = requests.post(OPENROUTER_URL, headers=headers, json=payload)
    if not response.ok:
        print("[OpenRouter] generate-event-recommendation error:", response.status_code, response.text)
        raise HTTPException(status_code=502, detail="OpenRouter provider error")
    try:
        result_json = response.json()
        choices = result_json.get("choices", [])
        if not choices:
            raise HTTPException(status_code=502, detail="No choices returned by OpenRouter")
        content_str = choices[0]["message"]["content"]
        result = json.loads(content_str)

    except json.JSONDecodeError as e:
        print("[OpenRouter] JSON parse error:", e)
        raise HTTPException(status_code=502, detail="Réponse inattendue d'OpenRouter.")

    # Return structured response
    return EventRecommendationResponse(
        eventTitle=event_title,
        eventTime=f"{start_time.strftime('%H:%M')} - {end_time.strftime('%H:%M')}",
        practices="\n".join([f"✔️ {p}" for p in result.get("practices", [])]),
        nutritionSuggestion=result.get("nutritionSuggestion", ""),
        purpose=result.get("purpose", "")
    )

# --------------------- Helper functions ---------------------

def _coerce_text(value) -> str:
    """Force AI output fields into readable strings."""
    if value is None:
        return ""
    if isinstance(value, list):
        return " ".join(str(item) for item in value if item not in (None, ""))
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False)
    return str(value)


def compress_image(image_bytes: bytes, max_side: int = 800, quality: int = 75) -> bytes:
    """Downscale large pictures and re-encode as JPEG to stay within model limits."""
    try:
        with Image.open(BytesIO(image_bytes)) as img:
            if img.mode != "RGB":
                img = img.convert("RGB")

            # Always resize to max_side to ensure consistent small size
            if max(img.size) > max_side:
                img.thumbnail((max_side, max_side))

            buffer = BytesIO()
            img.save(buffer, format="JPEG", quality=quality, optimize=True)
            return buffer.getvalue()
    except Exception as exc:
        print("[Backend] image compression skipped:", exc)
    return image_bytes

def create_meal_prompt(user_profile: dict, meal_type: Optional[str] = None, user_allergies: Optional[list] = None) -> str:
    """Create a professional English prompt for meal analysis."""

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
            'breakfast': 'Breakfast',
            'lunch': 'Lunch',
            'dinner': 'Dinner',
            'snack': 'Snack'
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

# --------------------- /analyze-meal endpoint ---------------------
@app.post("/analyze-meal")
async def analyze_meal(
    image: UploadFile = File(...),
    userId: str = Form(...),
    mealType: Optional[str] = Form(None),
    userProfile: Optional[str] = Form(None)
):
    """Analyze a meal image and return professional English analysis."""
    try:
        # Read and encode the image
        image_data = await image.read()
        compressed_image_data = compress_image(image_data)
        if len(compressed_image_data) != len(image_data):
            print(
                f"[Backend] analyze-meal image compressed from {len(image_data)} to {len(compressed_image_data)} bytes"
            )
        image_base64 = base64.b64encode(compressed_image_data).decode('utf-8')

        # Parse user profile
        profile = json.loads(userProfile) if userProfile else {}

        # create Prompt
        user_allergies = profile.get("allergies", [])
        prompt_text = create_meal_prompt(profile, mealType, user_allergies)
        # Build OpenRouter request payload
        messages = [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt_text},
                    {
                        "type": "image_url",
                        "image_url": {
                            "url": f"data:image/jpeg;base64,{image_base64}"
                        }
                    }
                ]
            }
        ]
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json"
        }
        data = {
            "model": "qwen/qwen2.5-vl-32b-instruct:free",
            "messages": messages,
            "temperature": 0.1,
            "response_format": {"type": "json_object"}
            # Don't specify max_tokens - let model use default to avoid exceeding context limit
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
        # Result extraction
        result = response.json()
        choices = result.get("choices")
        if not choices:
            print("[OpenRouter] analyze-meal unexpected payload:", result)
            error_detail = result.get("error", {}).get("message") if isinstance(result, dict) else None
            raise HTTPException(
                status_code=502,
                detail=error_detail or "Réponse inattendue du fournisseur OpenRouter.",
            )
        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        analysis_text = (message or {}).get("content") if isinstance(message, dict) else None
        if not analysis_text:
            print("[OpenRouter] analyze-meal missing content:", result)
            raise HTTPException(status_code=502, detail="Réponse vide d'OpenRouter. Réessayez ultérieurement.")
        analysis_json = json.loads(analysis_text)
        return analysis_json
    except json.JSONDecodeError as e:
        raise HTTPException(status_code=500, detail=f"Erreur de décodage JSON: {str(e)}")
    except HTTPException:
        raise
    except Exception as e:
        print("[Backend] analyze-meal exception:", str(e))
        raise HTTPException(status_code=500, detail=f"Erreur d'analyse: {str(e)}")

# --------------------- Root endpoint ---------------------
@app.post("/analyze-daily")
async def analyze_daily(request: DailyAnalysisRequest):
    """Analyze daily meals and provide a summary in English"""
    try:
        # Calculate total nutrition
        total_calories = sum(meal.nutrition.calories for meal in request.meals)
        total_proteins = sum(meal.nutrition.proteins for meal in request.meals)
        total_carbs = sum(meal.nutrition.carbs for meal in request.meals)
        total_fats = sum(meal.nutrition.fats for meal in request.meals)
        total_fibers = sum(meal.nutrition.fibers for meal in request.meals)

        # create prompt
        meals_summary = "\n".join([
            f"- {meal.mealType}: {meal.dishName} ({meal.nutrition.calories:.0f} kcal)"
            for meal in request.meals
        ])
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
            "Content-Type": "application/json"
        }

        data = {
            "model": "qwen/qwen2.5-vl-32b-instruct:free",
            "messages": [{"role": "user", "content": prompt}],
            "temperature": 0.2,
            "response_format": {"type": "json_object"}
            # Don't specify max_tokens - let model use default
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
                detail=error_detail or "Réponse inattendue du fournisseur OpenRouter.",
            )
        message = choices[0].get("message") if isinstance(choices[0], dict) else None
        content = (message or {}).get("content") if isinstance(message, dict) else None
        if not content:
            print("[OpenRouter] analyze-daily missing content:", result)
            raise HTTPException(status_code=502, detail="Réponse vide d'OpenRouter. Réessayez ultérieurement.")

        daily_analysis = json.loads(content)

        needs_met = daily_analysis.get("needsMet", False)
        if isinstance(needs_met, str):
            needs_met = needs_met.strip().lower() in {"true", "oui", "yes", "1"}

        # the complete summary
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
                "fibers": total_fibers
            },
            "globalAdvice": _coerce_text(daily_analysis.get("globalAdvice")),
            "recommendations": _coerce_text(daily_analysis.get("recommendations")),
            "needsMet": bool(needs_met)
        }
        return summary
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur d'analyse journalière: {str(e)}")

# --------------------- Coach AI ---------------------
@app.post("/coach")
async def ai_coach(request: CoachingRequest):
    """Streaming AI health coaching in professional English."""
    try:
        # Build personalized system prompt
        profile = request.userProfile or {}

        system_prompt = f"""You are a professional AI health coach.
                            Analyze the user's health and lifestyle data and provide clear, concise, and professional guidance in English.

User Profile:
- Gender: {profile.get('gender', 'Not specified')}
- Weight: {profile.get('weight', 'Not specified')} kg
- Height: {profile.get('height', 'Not specified')} cm
- Goal: {profile.get('goal', 'General wellness')}

Your role:
- Provide personalized nutrition and lifestyle advice and encouragement
- Answer questions about healthy eating, Tunisian cuisine, Mediterranean diet and fitness
- Be positive, warm, supportive, and motivating
- Keep responses concise (2-3 sentences unless more detail is needed)
- Use simple, friendly English

Guidelines:
- Focus on sustainable, healthy habits
- Respect cultural food preferences
- Encourage balanced Mediterranean diet principles
- Be positive and non-judgmental
"""
        # Build conversation history
        messages = [{"role": "system", "content": system_prompt}]
        if request.conversationHistory:
            messages.extend(request.conversationHistory)
        messages.append({"role": "user", "content": request.message})
        # Prepare streaming request to OpenRouter
        headers = {
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
        }
        data = {
            "model": "meta-llama/llama-3.3-70b-instruct:free",
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 500,
            "stream": True,
        }
        # Stream generator
        def generate_stream():
            try:
                with requests.post(
                    OPENROUTER_URL,
                    headers=headers,
                    json=data,
                    stream=True,
                    timeout=60
                ) as response:
                    if not response.ok:
                        error_msg = f"OpenRouter error: {response.status_code}"
                        yield f"data: {json.dumps({'error': error_msg})}\n\n"
                        return

                    for line in response.iter_lines():
                        if line:
                            decoded = line.decode('utf-8')
                            if decoded.startswith('data: '):
                                data_str = decoded[6:]  # Remove 'data: ' prefix
                                if data_str.strip() == '[DONE]':
                                    yield f"data: [DONE]\n\n"
                                    break

                                try:
                                    chunk = json.loads(data_str)
                                    if 'choices' in chunk and len(chunk['choices']) > 0:
                                        delta = chunk['choices'][0].get('delta', {})
                                        content = delta.get('content', '')
                                        if content:
                                            yield f"data: {json.dumps({'content': content})}\n\n"
                                except json.JSONDecodeError:
                                    continue

            except Exception as e:
                print(f"[Backend] Streaming error: {e}")
                yield f"data: {json.dumps({'error': str(e)})}\n\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no"
            }
        )

    except Exception as e:
        print(f"[Backend] AI Coach error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --------------------- Analyze Health ---------------------
@app.post("/analyze-health")
async def analyze_health(request: HealthAnalysisRequest):
    """Analyze daily health data and provide AI recommendations"""
    try:
        # Aggregate metrics
        if not request.metrics:
            raise HTTPException(status_code=400, detail="No health metrics provided")

        # Calculate daily statistics
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

        # Calculate stress level (HRV variance → stress)
        hrv_variance = sum((x - median_hrv) ** 2 for x in hrv_values) / len(hrv_values)
        stress_level = min(10, hrv_variance / 10)

        # Detect threshold violations
        alerts = []

        # HRV drop > 20%
        if len(hrv_values) > 1:
            hrv_baseline = sum(hrv_values[:len(hrv_values)//2]) / (len(hrv_values)//2)
            hrv_recent = sum(hrv_values[len(hrv_values)//2:]) / (len(hrv_values) - len(hrv_values)//2)
            if hrv_baseline > 0 and (hrv_baseline - hrv_recent) / hrv_baseline > 0.20:
                alerts.append("HRV dropped more than 20% - possible stress or overtraining")

        # Sleep < 6h
        if request.sleepData and request.sleepData.durationHours < 6:
            alerts.append(f"Sleep duration low: {request.sleepData.durationHours:.1f}h (recommended: 7-9h)")

        # SpO2 < 94%
        if avg_spo2 and avg_spo2 < 94:
            alerts.append(f"Low blood oxygen: {avg_spo2:.1f}% (normal: >95%)")

        # Sedentary > 2h (check for long gaps in activity)
        sedentary_hours = (24 * 60 - total_active_minutes) / 60
        if sedentary_hours > 22:  # Less than 2h active
            alerts.append("Very low activity detected - try to move more throughout the day")

        # Build LLM prompt
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
        # -> AJOUTEZ CE BLOC DE CODE ICI
        sleep_quality_description = ""
        if request.sleepData:
            score = request.sleepData.qualityScore
            duration = request.sleepData.durationHours
            if score >= 85 and duration >= 7:
                sleep_quality_description = "excellent and restful"
            elif score >= 70:
                sleep_quality_description = "good"
            elif score >= 50:
                        # Utiliser des termes plus nuancés
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
    "sleepRemark": "A short, encouraging sentence for the sleep card, in the format: 'Your sleep quality was {sleep_quality_description}. Let\\'s start a day with a ... breakfast 💪'.",
        "sleepPractices": "If sleep was poor or decent, provide 2-3 bullet-pointed tips to improve it. If sleep was excellent, provide a brief encouraging message about maintaining good habits. Use \\n for new lines."
}}
"""
        # Call OpenRouter LLM
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

        # Build response
        return {
            "summary": _coerce_text(analysis.get("summary")),
            "action": _coerce_text(analysis.get("action")),
            "breakfastSuggestion": _coerce_text(analysis.get("breakfastSuggestion")),
            "indicatorToWatch": _coerce_text(analysis.get("indicatorToWatch")),
            # --- AJOUTEZ CES DEUX LIGNES ICI ---
            "sleepRemark": _coerce_text(analysis.get("sleepRemark")),
            "sleepPractices": _coerce_text(analysis.get("sleepPractices")),
            # ------------------------------------
            "alerts": alerts,
            "dailyStats": {
                "avgRestingHR": round(avg_resting_hr, 1),
                "medianHRV": round(median_hrv, 1),
                "totalSteps": total_steps,
                "totalCalories": round(total_calories, 1),
                "totalActiveMinutes": total_active_minutes,
                "avgSpO2": round(avg_spo2, 1) if avg_spo2 else None,
                "stressLevel": round(stress_level, 1),
            }
        }

    except HTTPException:
        raise
    except Exception as e:
        print(f"[Backend] Health analysis error: {e}")
        raise HTTPException(status_code=500, detail=f"Health analysis failed: {str(e)}")

@app.get("/")
async def root():
    return {
        "message": "StressOFF Meal Analysis API",
        "version": "1.0.0",
        "endpoints": [
            "/analyze-meal",
            "/analyze-daily",
            "/coach",
            "/analyze-health"
        ]
    }

# --------------------- Run server ---------------------
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
