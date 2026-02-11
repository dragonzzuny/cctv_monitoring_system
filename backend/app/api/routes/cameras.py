"""
Camera REST API routes.
"""
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db.models import Camera, Checklist
from app.schemas.camera import CameraCreate, CameraUpdate, CameraResponse

router = APIRouter(prefix="/cameras", tags=["cameras"])


@router.post("/", response_model=CameraResponse, status_code=status.HTTP_201_CREATED)
async def create_camera(
    camera: CameraCreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new camera."""
    db_camera = Camera(
        name=camera.name,
        source=camera.source,
        source_type=camera.source_type
    )
    db.add(db_camera)
    await db.commit()
    await db.refresh(db_camera)
    return db_camera


@router.get("/", response_model=List[CameraResponse])
async def get_cameras(
    skip: int = 0,
    limit: int = 100,
    active_only: bool = False,
    db: AsyncSession = Depends(get_db)
):
    """Get all cameras."""
    query = select(Camera)
    if active_only:
        query = query.where(Camera.is_active == True)
    query = query.offset(skip).limit(limit)

    result = await db.execute(query)
    cameras = result.scalars().all()
    return cameras


@router.get("/{camera_id}", response_model=CameraResponse)
async def get_camera(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific camera."""
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )
    return camera


@router.put("/{camera_id}", response_model=CameraResponse)
async def update_camera(
    camera_id: int,
    camera_update: CameraUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Update a camera."""
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    update_data = camera_update.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(camera, field, value)

    await db.commit()
    await db.refresh(camera)
    return camera


@router.delete("/{camera_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_camera(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Delete a camera and all related data."""
    # Eager load relationships to avoid async lazy loading failure
    result = await db.execute(
        select(Camera).where(Camera.id == camera_id).options(
            selectinload(Camera.rois),
            selectinload(Camera.events),
            selectinload(Camera.checklists).selectinload(Checklist.items)
        )
    )
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    await db.delete(camera)
    await db.commit()


@router.post("/{camera_id}/activate", response_model=CameraResponse)
async def activate_camera(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Activate a camera."""
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    camera.is_active = True
    await db.commit()
    await db.refresh(camera)
    return camera


@router.post("/{camera_id}/deactivate", response_model=CameraResponse)
async def deactivate_camera(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Deactivate a camera."""
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    camera.is_active = False
    await db.commit()
    await db.refresh(camera)
    return camera
