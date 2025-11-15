"""Health coaching microservice for StressOFF."""
from __future__ import annotations

import json
import os
from typing import Dict, List, Optional

import requests
from fastapi import APIRouter, FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY")
OPENROUTER_URL = "https://openrouter.ai/api/v1/chat/completions"

router = APIRouter(tags=["coach"])


class CoachingRequest(BaseModel):
    userId: str
    message: str
    userProfile: Optional[Dict] = None
    conversationHistory: Optional[List[Dict]] = None


@router.post("/coach")
async def ai_coach(request: CoachingRequest) -> StreamingResponse:
    try:
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
        messages: List[Dict] = [{"role": "system", "content": system_prompt}]
        if request.conversationHistory:
            messages.extend(request.conversationHistory)
        messages.append({"role": "user", "content": request.message})

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

        def generate_stream():
            try:
                with requests.post(
                    OPENROUTER_URL,
                    headers=headers,
                    json=data,
                    stream=True,
                    timeout=60,
                ) as response:
                    if not response.ok:
                        error_msg = f"OpenRouter error: {response.status_code}"
                        yield f"data: {json.dumps({'error': error_msg})}\\n\\n"
                        return

                    for line in response.iter_lines():
                        if line:
                            decoded = line.decode("utf-8")
                            if decoded.startswith("data: "):
                                data_str = decoded[6:]
                                if data_str.strip() == "[DONE]":
                                    yield "data: [DONE]\\n\\n"
                                    break
                                try:
                                    chunk = json.loads(data_str)
                                    if "choices" in chunk and len(chunk["choices"]) > 0:
                                        delta = chunk["choices"][0].get("delta", {})
                                        content = delta.get("content", "")
                                        if content:
                                            yield f"data: {json.dumps({'content': content})}\\n\\n"
                                except json.JSONDecodeError:
                                    continue
            except Exception as exc:
                print(f"[CoachService] Streaming error: {exc}")
                yield f"data: {json.dumps({'error': str(exc)})}\\n\\n"

        return StreamingResponse(
            generate_stream(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )
    except Exception as exc:
        print(f"[CoachService] AI Coach error: {exc}")
        raise HTTPException(status_code=500, detail=str(exc)) from exc


def create_app() -> FastAPI:
    app = FastAPI(title="StressOFF Coach Service")
    app.include_router(router)

    @app.get("/")
    async def root() -> dict[str, str]:
        return {
            "message": "StressOFF Coach Service",
            "version": "1.0.0",
        }

    return app


app = create_app()
