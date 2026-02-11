"""
Video streaming REST API routes.
"""
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.responses import StreamingResponse
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db.models import Camera
from app.core.video_processor import VideoProcessor

router = APIRouter(prefix="/stream", tags=["stream"])


@router.get("/{camera_id}/snapshot")
async def get_snapshot(
    camera_id: int,
    with_detection: bool = False,
    db: AsyncSession = Depends(get_db)
):
    """
    Get a single snapshot from camera.

    - **camera_id**: Camera ID
    - **with_detection**: Include YOLO detection results
    """
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    processor = VideoProcessor(
        camera_id=camera.id,
        source=camera.source,
        source_type=camera.source_type
    )

    snapshot = processor.get_snapshot(with_detection=with_detection)

    if not snapshot:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to capture snapshot"
        )

    return snapshot


@router.get("/{camera_id}/info")
async def get_stream_info(
    camera_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get video stream information."""
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    processor = VideoProcessor(
        camera_id=camera.id,
        source=camera.source,
        source_type=camera.source_type
    )

    if not processor.open():
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Failed to open video source"
        )

    info = {
        "camera_id": camera.id,
        "camera_name": camera.name,
        "source": camera.source,
        "source_type": camera.source_type,
        "width": processor.width,
        "height": processor.height,
        "fps": processor.original_fps,
        "total_frames": processor.total_frames,
        "duration_seconds": processor.total_frames / processor.original_fps if processor.original_fps > 0 else 0
    }

    processor.close()
    return info


@router.post("/{camera_id}/seek")
async def seek_video(
    camera_id: int,
    position_ms: int,
    db: AsyncSession = Depends(get_db)
):
    """
    Seek to position in video file.

    Note: This is for REST API testing. Actual seeking should be done via WebSocket.
    """
    result = await db.execute(select(Camera).where(Camera.id == camera_id))
    camera = result.scalar_one_or_none()

    if not camera:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Camera {camera_id} not found"
        )

    if camera.source_type != "file":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Seeking is only supported for file sources"
        )

    return {"message": f"Seek to {position_ms}ms", "camera_id": camera_id}
