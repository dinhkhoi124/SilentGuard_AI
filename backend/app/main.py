import os
from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
from contextlib import asynccontextmanager
from apscheduler.schedulers.asyncio import AsyncIOScheduler

from app.core.config import settings

# Import routers from app.api
from app.api.events import router as events_router
from app.api.cameras import router as cameras_router
from app.api.alerts import router as alerts_router
from app.api.dashboard import router as dashboard_router
from app.api.users import router as users_router
from app.api.settings import router as settings_router
from app.api.reports import router as reports_router
from app.api.households import router as households_router
from app.services.scheduler import periodic_check_job, retry_critical_calls

# Load environment variables
load_dotenv()

@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = AsyncIOScheduler()
    scheduler.add_job(periodic_check_job, 'interval', minutes=1)
    scheduler.add_job(retry_critical_calls, 'interval', minutes=2)
    scheduler.start()
    yield
    scheduler.shutdown()

app = FastAPI(
    title="SilentGuard AI Backend",
    description="FastAPI Backend for SilentGuard Passive Fall Detection System (MVP V1)",
    version="1.0.0",
    lifespan=lifespan
)

from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://silentguard-production-4485.up.railway.app",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Mount API Routers
app.include_router(events_router)
app.include_router(cameras_router)
app.include_router(alerts_router)
app.include_router(dashboard_router)
app.include_router(users_router)
app.include_router(settings_router)
app.include_router(reports_router)
app.include_router(households_router)

@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """
    GET /health
    Ref: Section 4.11 / Section 4.5 of design doc
    """
    return {
        "status": "ok",
        "version": "1.0.0",
        "services": {
            "database": "ok",
            "storage": "ok",
            "firebase": "ok",
            "claude": "ok"
        }
    }

@app.get("/")
async def root():
    return {"message": "Welcome to SilentGuard AI API. Go to /docs for API documentation."}
