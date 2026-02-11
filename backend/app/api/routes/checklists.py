"""
Checklist REST API routes.
"""
from datetime import datetime
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.db.database import get_db
from app.db.models import Checklist, ChecklistItem, Camera
from app.schemas.checklist import (
    ChecklistCreate,
    ChecklistResponse,
    ChecklistItemResponse,
    ChecklistItemUpdate
)

router = APIRouter(prefix="/checklists", tags=["checklists"])


@router.post("/", response_model=ChecklistResponse, status_code=status.HTTP_201_CREATED)
async def create_checklist(
    checklist: ChecklistCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new checklist with items."""
    # Verify camera exists
    result = await db.execute(select(Camera).where(Camera.id == checklist.camera_id))
    camera = result.scalar_one_or_none()
    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {checklist.camera_id} not found"
        )

    # Create checklist
    db_checklist = Checklist(
        camera_id=checklist.camera_id,
        name=checklist.name
    )
    db.add(db_checklist)
    await db.flush()

    # Create items
    for item in checklist.items:
        db_item = ChecklistItem(
            checklist_id=db_checklist.id,
            item_type=item.item_type,
            description=item.description
        )
        db.add(db_item)

    await db.commit()

    # Reload with items
    result = await db.execute(
        select(Checklist)
        .options(selectinload(Checklist.items))
        .where(Checklist.id == db_checklist.id)
    )
    db_checklist = result.scalar_one()

    return db_checklist


@router.post("/camera/{camera_id}/default", response_model=ChecklistResponse)
async def create_default_checklist(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Create a default safety checklist for a camera."""
    # Verify camera exists
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()
    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    # Create checklist
    db_checklist = Checklist(
        camera_id=camera_id,
        name="안전 점검 체크리스트"
    )
    db.add(db_checklist)
    await db.flush()

    # Default items
    default_items = [
        ("PPE_HELMET", "안전모 착용 확인"),
        ("PPE_MASK", "마스크 착용 확인"),
        ("FIRE_EXTINGUISHER", "소화기 비치 확인"),
        ("ROI_CLEAR", "작업구역 안전 확인"),
    ]

    for item_type, description in default_items:
        db_item = ChecklistItem(
            checklist_id=db_checklist.id,
            item_type=item_type,
            description=description
        )
        db.add(db_item)

    await db.commit()

    # Reload with items
    result = await db.execute(
        select(Checklist)
        .options(selectinload(Checklist.items))
        .where(Checklist.id == db_checklist.id)
    )
    db_checklist = result.scalar_one()

    return db_checklist


@router.get("/", response_model=List[ChecklistResponse])
async def get_checklists(
    camera_id: Optional[int] = None,
    active_only: bool = False,
    db: AsyncSession = Depends(get_db)
):
    """Get all checklists, optionally filtered by camera."""
    query = select(Checklist).options(selectinload(Checklist.items))

    if camera_id is not None:
        query = query.where(Checklist.camera_id == camera_id)
    if active_only:
        query = query.where(Checklist.is_active == True)

    result = await db.execute(query)
    checklists = result.scalars().all()
    return checklists


@router.get("/{checklist_id}", response_model=ChecklistResponse)
async def get_checklist(
    checklist_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific checklist."""
    result = await db.execute(
        select(Checklist)
        .options(selectinload(Checklist.items))
        .where(Checklist.id == checklist_id)
    )
    checklist = result.scalar_one_or_none()

    if not checklist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist {checklist_id} not found"
        )
    return checklist


@router.delete("/{checklist_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_checklist(
    checklist_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Delete a checklist."""
    result = await db.execute(select(Checklist).where(Checklist.id == checklist_id))
    checklist = result.scalar_one_or_none()

    if not checklist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist {checklist_id} not found"
        )

    await db.delete(checklist)
    await db.commit()


@router.put("/items/{item_id}", response_model=ChecklistItemResponse)
async def update_checklist_item(
    item_id: int,
    item_update: ChecklistItemUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Update a checklist item (check/uncheck)."""
    result = await db.execute(select(ChecklistItem).where(ChecklistItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist item {item_id} not found"
        )

    item.is_checked = item_update.is_checked
    item.auto_checked = False  # Manual check
    item.checked_at = datetime.utcnow() if item_update.is_checked else None

    await db.commit()
    await db.refresh(item)
    return item


@router.post("/items/{item_id}/auto-check", response_model=ChecklistItemResponse)
async def auto_check_item(
    item_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Auto-check a checklist item (called by detection system)."""
    result = await db.execute(select(ChecklistItem).where(ChecklistItem.id == item_id))
    item = result.scalar_one_or_none()

    if not item:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist item {item_id} not found"
        )

    item.is_checked = True
    item.auto_checked = True
    item.checked_at = datetime.utcnow()

    await db.commit()
    await db.refresh(item)
    return item


@router.post("/{checklist_id}/reset", response_model=ChecklistResponse)
async def reset_checklist(
    checklist_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Reset all items in a checklist to unchecked."""
    result = await db.execute(
        select(Checklist)
        .options(selectinload(Checklist.items))
        .where(Checklist.id == checklist_id)
    )
    checklist = result.scalar_one_or_none()

    if not checklist:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Checklist {checklist_id} not found"
        )

    for item in checklist.items:
        item.is_checked = False
        item.auto_checked = False
        item.checked_at = None

    await db.commit()
    await db.refresh(checklist)
    return checklist
