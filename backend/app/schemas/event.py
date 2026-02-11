"""
Event schemas for API request/response validation.
"""
from datetime import datetime
from typing import Optional, Literal
from pydantic import BaseModel, Field


class EventBase(BaseModel):
    """Base event schema."""
    event_type: str = Field(..., description="Event type (ROI_INTRUSION, PPE_HELMET_MISSING, etc.)")
    severity: Literal["INFO", "WARNING", "CRITICAL"] = Field(..., description="Event severity")
    message: str = Field(..., max_length=500, description="Event message")


class EventCreate(EventBase):
    """Schema for creating an event."""
    camera_id: int
    roi_id: Optional[int] = None
    snapshot_path: Optional[str] = None
    detection_data: Optional[str] = None


class EventResponse(EventBase):
    """Schema for event response."""
    id: int
    camera_id: int
    roi_id: Optional[int]
    snapshot_path: Optional[str]
    detection_data: Optional[str]
    is_acknowledged: bool
    acknowledged_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class EventAcknowledge(BaseModel):
    """Schema for acknowledging an event."""
    event_id: int
