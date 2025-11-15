"""API gateway that aggregates the StressOFF microservices."""
from __future__ import annotations

from fastapi import FastAPI

from backend.microservices.coach_service.app import router as coach_router
from backend.microservices.daily_analysis_service.app import router as daily_router
from backend.microservices.event_service.app import router as event_router
from backend.microservices.health_service.app import router as health_router
from backend.microservices.meal_service.app import router as meal_router

app = FastAPI(title="StressOFF API Gateway", version="1.0.0")

app.include_router(event_router)
app.include_router(meal_router)
app.include_router(daily_router)
app.include_router(coach_router)
app.include_router(health_router)


@app.get("/")
async def root() -> dict:
    return {
        "message": "StressOFF API Gateway",
        "services": {
            "event": "/generate-event-recommendation",
            "meal": "/analyze-meal",
            "daily": "/analyze-daily",
            "coach": "/coach",
            "health": "/analyze-health",
        },
        "documentation": {
            "event": "backend/microservices/event_service",
            "meal": "backend/microservices/meal_service",
            "daily": "backend/microservices/daily_analysis_service",
            "coach": "backend/microservices/coach_service",
            "health": "backend/microservices/health_service",
        },
    }


if __name__ == "__main__":  # pragma: no cover
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
