"""
Detection schemas for YOLO results and streaming.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


class DetectionBox(BaseModel):
    """Single detection bounding box."""
    class_id: int = Field(..., description="Class index")
    class_name: str = Field(..., description="Class name")
    confidence: float = Field(..., ge=0, le=1, description="Detection confidence")
    x1: float = Field(..., description="Top-left X coordinate")
    y1: float = Field(..., description="Top-left Y coordinate")
    x2: float = Field(..., description="Bottom-right X coordinate")
    y2: float = Field(..., description="Bottom-right Y coordinate")
    center_x: float = Field(..., description="Center X coordinate")
    center_y: float = Field(..., description="Center Y coordinate")
    track_id: Optional[int] = Field(None, description="Unique tracking ID for the object")


class DetectionResult(BaseModel):
    """Detection result for a single frame."""
    frame_number: int
    timestamp: float
    detections: List[DetectionBox]
    persons_count: int = 0
    helmets_count: int = 0
    masks_count: int = 0
    fire_extinguishers_count: int = 0


class StreamFrame(BaseModel):
    """WebSocket stream frame data."""
    camera_id: int
    frame_base64: str = Field(..., description="Base64 encoded JPEG frame")
    current_ms: float = 0.0
    total_ms: float = 0.0
    detection: Optional[DetectionResult] = None
    events: List[dict] = Field(default_factory=list, description="New events for this frame")


class SafetyStatus(BaseModel):
    """Current safety status for a camera."""
    camera_id: int
    roi_intrusions: List[dict] = Field(default_factory=list)
    ppe_violations: List[dict] = Field(default_factory=list)
    fire_extinguisher_status: bool = Field(default=False, description="Fire extinguisher detected")
    overall_status: str = Field(default="OK", description="OK, WARNING, CRITICAL")
