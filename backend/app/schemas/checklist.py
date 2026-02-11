"""
Checklist schemas for API request/response validation.
"""
from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, Field


class ChecklistItemBase(BaseModel):
    """Base checklist item schema."""
    item_type: str = Field(..., description="Item type (PPE_HELMET, PPE_MASK, FIRE_EXTINGUISHER)")
    description: str = Field(..., max_length=200, description="Item description")


class ChecklistItemCreate(ChecklistItemBase):
    """Schema for creating a checklist item."""
    pass


class ChecklistItemResponse(ChecklistItemBase):
    """Schema for checklist item response."""
    id: int
    checklist_id: int
    is_checked: bool
    auto_checked: bool
    checked_at: Optional[datetime]
    created_at: datetime

    class Config:
        from_attributes = True


class ChecklistItemUpdate(BaseModel):
    """Schema for updating a checklist item."""
    is_checked: bool


class ChecklistBase(BaseModel):
    """Base checklist schema."""
    name: str = Field(..., min_length=1, max_length=100, description="Checklist name")


class ChecklistCreate(ChecklistBase):
    """Schema for creating a checklist."""
    camera_id: int
    items: List[ChecklistItemCreate] = Field(default_factory=list)


class ChecklistResponse(ChecklistBase):
    """Schema for checklist response."""
    id: int
    camera_id: int
    is_active: bool
    items: List[ChecklistItemResponse]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True
