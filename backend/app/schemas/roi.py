"""
ROI (Region of Interest) schemas for API request/response validation.
"""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class Point(BaseModel):
    """Single point coordinate."""
    x: float
    y: float


class ROIBase(BaseModel):
    """Base ROI schema."""
    name: str = Field(..., min_length=1, max_length=100, description="ROI name")
    points: List[Point] = Field(..., min_length=3, description="Polygon points (at least 3)")
    color: str = Field(default="#FF0000", description="ROI display color")
    zone_type: str = Field(default="warning", description="Type of zone: warning or danger")


class ROICreate(ROIBase):
    """Schema for creating a ROI."""
    camera_id: int = Field(..., description="Camera ID")


class ROIUpdate(BaseModel):
    """Schema for updating a ROI."""
    name: Optional[str] = Field(None, min_length=1, max_length=100)
    points: Optional[List[Point]] = Field(None, min_length=3)
    color: Optional[str] = None
    is_active: Optional[bool] = None


class ROIResponse(ROIBase):
    """Schema for ROI response."""
    id: int
    camera_id: int
    is_active: bool
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
