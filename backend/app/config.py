"""
Application configuration settings.
"""
from pathlib import Path
from pydantic_settings import BaseSettings
from typing import List


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    # Application
    APP_NAME: str = "CCTV Safety Monitoring System"
    APP_VERSION: str = "1.0.0"
    DEBUG: bool = False  # Set to True for development via environment variable

    # Server
    HOST: str = "0.0.0.0"
    PORT: int = 8001

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./safety_monitor.db"

    # Paths
    BASE_DIR: Path = Path(__file__).resolve().parent.parent
    MODELS_DIR: Path = BASE_DIR / "models"
    SNAPSHOTS_DIR: Path = BASE_DIR / "snapshots"

    # Detector Settings
    DETECTOR_TYPE: str = "rfdetr"  # "yolo" or "rfdetr"
    
    # YOLO Model
    YOLO_MODEL_PATH: str = "models/best.pt"
    YOLO_CONFIDENCE_THRESHOLD: float = 0.5
    YOLO_IOU_THRESHOLD: float = 0.45

    # RF-DETR Model
    RFDETR_MODEL_PATH: str = "models/checkpoint_best_ema.pth"
    RFDETR_CONFIDENCE_THRESHOLD: float = 0.15
    
    # BoT-SORT Tracker Settings
    TRACKER_CONFIG: str = "bot_sort.yaml" # Placeholder or path

    # Detection classes (standardized across models)
    CLASS_NAMES: List[str] = [
        "helmet", "gloves", "vest", "boots", "goggles", 
        "mask", "person", "machinery", "vehicle", 
        "safety_cone", "fire_extinguisher"
    ]

    # Video processing
    VIDEO_FPS: int = 15
    VIDEO_QUALITY: int = 80  # JPEG quality for streaming

    # Rule engine - False positive prevention
    DETECTION_PERSISTENCE_SECONDS: float = 2.0  # Must persist for N seconds
    DETECTION_COOLDOWN_SECONDS: float = 30.0  # Cooldown between same alarms
    DETECTION_FRAME_THRESHOLD: int = 20  # Out of 30 frames
    DETECTION_FRAME_WINDOW: int = 30

    # Alarm settings
    ALARM_SOUND_ENABLED: bool = True

    class Config:
        env_file = ".env"
        case_sensitive = True


# Global settings instance
settings = Settings()

# Ensure directories exist
settings.MODELS_DIR.mkdir(parents=True, exist_ok=True)
settings.SNAPSHOTS_DIR.mkdir(parents=True, exist_ok=True)
