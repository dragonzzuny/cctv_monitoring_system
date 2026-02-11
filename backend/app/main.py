"""
FastAPI application entry point.
CCTV Safety Monitoring System
"""
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import settings
from app.db.database import init_db, close_db
from app.api.routes import (
    cameras_router,
    rois_router,
    events_router,
    checklists_router,
    stream_router,
    regulations_router
)
from app.api.websocket import router as websocket_router

# Configure logging
logging.basicConfig(
    level=logging.DEBUG if settings.DEBUG else logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    logger.info(f"Starting {settings.APP_NAME} v{settings.APP_VERSION}")
    await init_db()
    logger.info("Database initialized")

    yield

    # Shutdown
    logger.info("Shutting down...")
    await close_db()
    logger.info("Database connections closed")


# Create FastAPI app
app = FastAPI(
    title=settings.APP_NAME,
    version=settings.APP_VERSION,
    description="CCTV 기반 화기작업 안전관제 시스템 API",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc"
)

# CORS middleware
# TODO: In production, restrict allow_origins to specific domains
# Example: allow_origins=["https://yourdomain.com"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount static files for snapshots
app.mount("/snapshots", StaticFiles(directory=str(settings.SNAPSHOTS_DIR)), name="snapshots")

# Include routers
app.include_router(cameras_router, prefix="/api")
app.include_router(rois_router, prefix="/api")
app.include_router(events_router, prefix="/api")
app.include_router(checklists_router, prefix="/api")
app.include_router(stream_router, prefix="/api")
app.include_router(regulations_router, prefix="/api")
app.include_router(websocket_router)


@app.get("/")
async def root():
    """Root endpoint."""
    return {
        "name": settings.APP_NAME,
        "version": settings.APP_VERSION,
        "status": "running"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {"status": "healthy"}


@app.get("/api/config")
async def get_config():
    """Get system configuration (non-sensitive)."""
    return {
        "video_fps": settings.VIDEO_FPS,
        "detection_classes": settings.CLASS_NAMES,
        "confidence_threshold": settings.YOLO_CONFIDENCE_THRESHOLD,
        "persistence_seconds": settings.DETECTION_PERSISTENCE_SECONDS,
        "cooldown_seconds": settings.DETECTION_COOLDOWN_SECONDS
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=settings.DEBUG
    )
