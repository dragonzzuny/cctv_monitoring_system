"""
Event REST API routes.
"""
from datetime import datetime, timezone
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db.models import Event
from app.schemas.event import EventResponse, EventAcknowledge
from app.core.alarm_manager import get_alarm_manager

router = APIRouter(prefix="/events", tags=["events"])


@router.get("/", response_model=List[EventResponse])
async def get_events(
    camera_id: Optional[int] = None,
    event_type: Optional[str] = None,
    severity: Optional[str] = None,
    acknowledged: Optional[bool] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    skip: int = 0,
    limit: int = 100,
    db: AsyncSession = Depends(get_db)
):
    """
    Get events with optional filters.

    - **camera_id**: Filter by camera
    - **event_type**: Filter by event type
    - **severity**: Filter by severity (INFO, WARNING, CRITICAL)
    - **acknowledged**: Filter by acknowledgement status
    - **start_date**: Filter events after this date
    - **end_date**: Filter events before this date
    """
    query = select(Event)

    if camera_id is not None:
        query = query.where(Event.camera_id == camera_id)
    if event_type is not None:
        query = query.where(Event.event_type == event_type)
    if severity is not None:
        query = query.where(Event.severity == severity)
    if acknowledged is not None:
        query = query.where(Event.is_acknowledged == acknowledged)
    if start_date is not None:
        query = query.where(Event.created_at >= start_date)
    if end_date is not None:
        query = query.where(Event.created_at <= end_date)

    query = query.order_by(desc(Event.created_at)).offset(skip).limit(limit)

    result = await db.execute(query)
    events = result.scalars().all()
    return events


@router.get("/unacknowledged", response_model=List[EventResponse])
async def get_unacknowledged_events(
    camera_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """Get all unacknowledged events."""
    query = select(Event).where(Event.is_acknowledged == False)

    if camera_id is not None:
        query = query.where(Event.camera_id == camera_id)

    query = query.order_by(desc(Event.created_at))

    result = await db.execute(query)
    events = result.scalars().all()
    return events


@router.get("/recent", response_model=List[EventResponse])
async def get_recent_events(
    count: int = Query(default=10, le=100),
    camera_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """Get most recent events."""
    query = select(Event)

    if camera_id is not None:
        query = query.where(Event.camera_id == camera_id)

    query = query.order_by(desc(Event.created_at)).limit(count)

    result = await db.execute(query)
    events = result.scalars().all()
    return events


@router.get("/statistics")
async def get_event_statistics(
    camera_id: Optional[int] = None,
    start_date: Optional[datetime] = None,
    end_date: Optional[datetime] = None,
    db: AsyncSession = Depends(get_db)
):
    """Get event statistics."""
    from sqlalchemy import func

    # Base query
    filters = []
    if camera_id is not None:
        filters.append(Event.camera_id == camera_id)
    if start_date is not None:
        filters.append(Event.created_at >= start_date)
    if end_date is not None:
        filters.append(Event.created_at <= end_date)

    # Total count
    total_query = select(func.count(Event.id))
    if filters:
        total_query = total_query.where(*filters)
    total_result = await db.execute(total_query)
    total_count = total_result.scalar()

    # Count by severity
    severity_query = select(
        Event.severity,
        func.count(Event.id).label("count")
    ).group_by(Event.severity)
    if filters:
        severity_query = severity_query.where(*filters)
    severity_result = await db.execute(severity_query)
    by_severity = {row[0]: row[1] for row in severity_result.fetchall()}

    # Count by event type
    type_query = select(
        Event.event_type,
        func.count(Event.id).label("count")
    ).group_by(Event.event_type)
    if filters:
        type_query = type_query.where(*filters)
    type_result = await db.execute(type_query)
    by_type = {row[0]: row[1] for row in type_result.fetchall()}

    # Unacknowledged count
    unack_query = select(func.count(Event.id)).where(Event.is_acknowledged == False)
    if filters:
        unack_query = unack_query.where(*filters)
    unack_result = await db.execute(unack_query)
    unacknowledged_count = unack_result.scalar()

    return {
        "total": total_count,
        "unacknowledged": unacknowledged_count,
        "by_severity": by_severity,
        "by_type": by_type
    }


@router.get("/{event_id}", response_model=EventResponse)
async def get_event(
    event_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific event."""
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event {event_id} not found"
        )
    return event


@router.post("/{event_id}/acknowledge", response_model=EventResponse)
async def acknowledge_event(
    event_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Acknowledge an event."""
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event {event_id} not found"
        )

    event.is_acknowledged = True
    event.acknowledged_at = datetime.now(timezone.utc)
    await db.commit()
    await db.refresh(event)

    # Also acknowledge in alarm manager
    alarm_manager = get_alarm_manager()
    await alarm_manager.acknowledge_event(event_id)

    return event


@router.post("/acknowledge-all", status_code=status.HTTP_200_OK)
async def acknowledge_all_events(
    camera_id: Optional[int] = None,
    db: AsyncSession = Depends(get_db)
):
    """Acknowledge all unacknowledged events."""
    query = select(Event).where(Event.is_acknowledged == False)

    if camera_id is not None:
        query = query.where(Event.camera_id == camera_id)

    result = await db.execute(query)
    events = result.scalars().all()

    now = datetime.now(timezone.utc)
    count = 0
    alarm_manager = get_alarm_manager()

    for event in events:
        event.is_acknowledged = True
        event.acknowledged_at = now
        await alarm_manager.acknowledge_event(event.id)
        count += 1

    await db.commit()

    return {"acknowledged": count}


@router.delete("/{event_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_event(
    event_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Delete an event."""
    result = await db.execute(select(Event).where(Event.id == event_id))
    event = result.scalar_one_or_none()

    if not event:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"Event {event_id} not found"
        )

    await db.delete(event)
    await db.commit()
