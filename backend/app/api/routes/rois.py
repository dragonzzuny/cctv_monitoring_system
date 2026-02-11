"""
ROI REST API routes.
"""
import json
from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db.models import ROI, Camera
from app.schemas.roi import ROICreate, ROIUpdate, ROIResponse, Point
from app.core.roi_manager import get_roi_manager

router = APIRouter(prefix="/rois", tags=["rois"])


def points_to_json(points: List[Point]) -> str:
    """Convert points list to JSON string."""
    return json.dumps([{"x": p.x, "y": p.y} for p in points])


def json_to_points(json_str: str) -> List[Point]:
    """Convert JSON string to points list."""
    data = json.loads(json_str)
    return [Point(x=p["x"], y=p["y"]) for p in data]


@router.post("/", response_model=ROIResponse, status_code=status.HTTP_201_CREATED)
async def create_roi(
    roi: ROICreate,
    db: AsyncSession = Depends(get_db)
):
    """Create a new ROI."""
    # Verify camera exists
    result = await db.execute(select(Camera).where(Camera.id == roi.camera_id))
    camera = result.scalar_one_or_none()
    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {roi.camera_id} not found"
        )

    db_roi = ROI(
        camera_id=roi.camera_id,
        name=roi.name,
        points=points_to_json(roi.points),
        color=roi.color,
        zone_type=roi.zone_type
    )
    db.add(db_roi)
    await db.commit()
    await db.refresh(db_roi)

    # Add to ROI manager
    roi_manager = get_roi_manager()
    roi_manager.add_roi(db_roi.id, roi.points, roi.name, roi.color)

    response = ROIResponse(
        id=db_roi.id,
        camera_id=db_roi.camera_id,
        name=db_roi.name,
        points=roi.points,
        color=db_roi.color,
        zone_type=db_roi.zone_type or "warning",
        is_active=db_roi.is_active,
        created_at=db_roi.created_at,
        updated_at=db_roi.updated_at
    )
    return response


@router.get("/", response_model=List[ROIResponse])
async def get_rois(
    camera_id: int = None,
    active_only: bool = False,
    db: AsyncSession = Depends(get_db)
):
    """Get all ROIs, optionally filtered by camera."""
    query = select(ROI)
    if camera_id:
        query = query.where(ROI.camera_id == camera_id)
    if active_only:
        query = query.where(ROI.is_active == True)

    result = await db.execute(query)
    rois = result.scalars().all()

    responses = []
    for roi in rois:
        response = ROIResponse(
            id=roi.id,
            camera_id=roi.camera_id,
            name=roi.name,
            points=json_to_points(roi.points),
            color=roi.color,
            zone_type=roi.zone_type or "warning",
            is_active=roi.is_active,
            created_at=roi.created_at,
            updated_at=roi.updated_at
        )
        responses.append(response)

    return responses


@router.get("/{roi_id}", response_model=ROIResponse)
async def get_roi(
    roi_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific ROI."""
    result = await db.execute(select(ROI).where(ROI.id == roi_id))
    roi = result.scalar_one_or_none()

    if not roi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ROI {roi_id} not found"
        )

    return ROIResponse(
        id=roi.id,
        camera_id=roi.camera_id,
        name=roi.name,
        points=json_to_points(roi.points),
        color=roi.color,
        is_active=roi.is_active,
        created_at=roi.created_at,
        updated_at=roi.updated_at
    )


@router.put("/{roi_id}", response_model=ROIResponse)
async def update_roi(
    roi_id: int,
    roi_update: ROIUpdate,
    db: AsyncSession = Depends(get_db)
):
    """Update a ROI."""
    result = await db.execute(select(ROI).where(ROI.id == roi_id))
    roi = result.scalar_one_or_none()

    if not roi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ROI {roi_id} not found"
        )

    update_data = roi_update.model_dump(exclude_unset=True)

    if "points" in update_data:
        update_data["points"] = points_to_json(update_data["points"])

    for field, value in update_data.items():
        setattr(roi, field, value)

    await db.commit()
    await db.refresh(roi)

    # Update ROI manager
    roi_manager = get_roi_manager()
    if roi.is_active:
        points = json_to_points(roi.points)
        roi_manager.add_roi(roi.id, points, roi.name, roi.color, zone_type=roi.zone_type or "warning")
    else:
        roi_manager.remove_roi(roi.id)

    return ROIResponse(
        id=roi.id,
        camera_id=roi.camera_id,
        name=roi.name,
        points=json_to_points(roi.points),
        color=roi.color,
        zone_type=roi.zone_type or "warning",
        is_active=roi.is_active,
        created_at=roi.created_at,
        updated_at=roi.updated_at
    )


@router.delete("/{roi_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_roi(
    roi_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Delete a ROI."""
    result = await db.execute(select(ROI).where(ROI.id == roi_id))
    roi = result.scalar_one_or_none()

    if not roi:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"ROI {roi_id} not found"
        )

    # Remove from ROI manager
    roi_manager = get_roi_manager()
    roi_manager.remove_roi(roi_id)

    await db.delete(roi)
    await db.commit()


@router.post("/camera/{camera_id}/load", status_code=status.HTTP_200_OK)
async def load_camera_rois(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Load all active ROIs for a camera into the ROI manager."""
    result = await db.execute(
        select(ROI).where(ROI.camera_id == camera_id, ROI.is_active == True)
    )
    rois = result.scalars().all()

    roi_manager = get_roi_manager()

    loaded_count = 0
    for roi in rois:
        points = json_to_points(roi.points)
        roi_manager.add_roi(roi.id, points, roi.name, roi.color)
        loaded_count += 1

    return {"loaded": loaded_count, "camera_id": camera_id}
