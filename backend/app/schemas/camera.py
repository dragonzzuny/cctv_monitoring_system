"""
Camera schemas for API request/response validation.
"""
from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field


class CameraBase(BaseModel):
    """Base camera schema."""
    name: str = Field(..., min_length=1, max_length=100, description="Camera name")
    source: str = Field(..., min_length=1, max_length=500, description="File path or RTSP URL")
    source_type: Literal["file", "rtsp"] = Field(default="file", description="Source type")


class CameraCreate(CameraBase):
    """Schema for creating a camera."""
    pass


class CameraUpdate(BaseModel):
    """Schema for updating a camera."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    source: Optional[str] = Field(None, min_length=1, max_length=500)
    source_type: Optional[Literal["file", "rtsp"]] = None
    is_active: Optional[bool] = None


class CameraResponse(CameraBase):
    """Schema for camera response."""
    id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
