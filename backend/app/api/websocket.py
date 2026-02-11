"""
WebSocket endpoints for real-time video streaming and events.
"""
import asyncio
import json
import logging
from typing import Dict, Set
from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Depends
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import AsyncSessionLocal
from app.db.models import Camera, ROI
from app.core.video_processor import VideoProcessor
from app.core.detection import get_detector
from app.core.roi_manager import get_roi_manager, ROIManager
from app.core.rule_engine import RuleEngine, create_rule_engine
from app.core.alarm_manager import get_alarm_manager
from app.schemas.roi import Point

logger = logging.getLogger(__name__)

router = APIRouter()


class ConnectionManager:
    """Manages WebSocket connections with thread safety."""

    def __init__(self):
        # camera_id -> set of connected websockets
        self._connections: Dict[int, Set[WebSocket]] = {}
        # All event subscribers
        self._event_subscribers: Set[WebSocket] = set()
        # Locks for thread safety
        self._connections_lock = asyncio.Lock()
        self._events_lock = asyncio.Lock()

    async def connect_stream(self, websocket: WebSocket, camera_id: int):
        """Connect to a camera stream."""
        await websocket.accept()
        async with self._connections_lock:
            if camera_id not in self._connections:
                self._connections[camera_id] = set()
            self._connections[camera_id].add(websocket)
        logger.info(f"Client connected to camera {camera_id}")

    async def connect_events(self, websocket: WebSocket):
        """Connect to event notifications."""
        await websocket.accept()
        async with self._events_lock:
            self._event_subscribers.add(websocket)
        logger.info("Client connected to events")

    async def disconnect_stream(self, websocket: WebSocket, camera_id: int):
        """Disconnect from camera stream."""
        async with self._connections_lock:
            if camera_id in self._connections:
                self._connections[camera_id].discard(websocket)
                if not self._connections[camera_id]:
                    del self._connections[camera_id]
        logger.info(f"Client disconnected from camera {camera_id}")

    async def disconnect_events(self, websocket: WebSocket):
        """Disconnect from events."""
        async with self._events_lock:
            self._event_subscribers.discard(websocket)
        logger.info("Client disconnected from events")

    async def send_frame(self, camera_id: int, data: dict):
        """Send frame to all connected clients for a camera."""
        async with self._connections_lock:
            if camera_id not in self._connections:
                return
            connections = list(self._connections[camera_id])

        message = json.dumps(data)
        disconnected = set()

        for websocket in connections:
            try:
                await websocket.send_text(message)
            except Exception:
                disconnected.add(websocket)

        if disconnected:
            async with self._connections_lock:
                for ws in disconnected:
                    if camera_id in self._connections:
                        self._connections[camera_id].discard(ws)

    async def broadcast_event(self, event_data: dict):
        """Broadcast event to all event subscribers."""
        async with self._events_lock:
            subscribers = list(self._event_subscribers)

        message = json.dumps(event_data)
        disconnected = set()

        for websocket in subscribers:
            try:
                await websocket.send_text(message)
            except Exception:
                disconnected.add(websocket)

        if disconnected:
            async with self._events_lock:
                for ws in disconnected:
                    self._event_subscribers.discard(ws)

    def get_viewer_count(self, camera_id: int) -> int:
        """Get number of viewers for a camera."""
        return len(self._connections.get(camera_id, set()))


# Global connection manager
manager = ConnectionManager()


async def load_camera_rois(camera_id: int, roi_manager: ROIManager):
    """Load ROIs for a camera from database."""
    async with AsyncSessionLocal() as db:
        result = await db.execute(
            select(ROI).where(ROI.camera_id == camera_id, ROI.is_active == True)
        )
        rois = result.scalars().all()

        for roi in rois:
            points_data = json.loads(roi.points)
            points = [Point(x=p["x"], y=p["y"]) for p in points_data]
            roi_manager.add_roi(
                roi.id, 
                points, 
                roi.name, 
                roi.color, 
                zone_type=getattr(roi, "zone_type", "warning")
            )

        return [roi.id for roi in rois]


@router.websocket("/ws/stream/{camera_id}")
async def websocket_stream(websocket: WebSocket, camera_id: int):
    """
    WebSocket endpoint for video streaming with detection.

    Sends JSON messages with:
    - frame_base64: Base64 encoded JPEG frame
    - detection: Detection results (if enabled)
    - events: New safety events (if any)
    """
    # Get camera from database
    async with AsyncSessionLocal() as db:
        result = await db.execute(select(Camera).where(Camera.id == camera_id))
        camera = result.scalar_one_or_none()

        if not camera:
            await websocket.close(code=4004, reason="Camera not found")
            return

    await manager.connect_stream(websocket, camera_id)

    # Initialize components - use unique ROI manager per camera stream
    roi_manager = ROIManager()  # Each camera needs its own ROI manager
    rule_engine = create_rule_engine(roi_manager)
    alarm_manager = get_alarm_manager()

    # Store current frame for snapshot
    current_frame = None

    # Load ROIs
    active_roi_ids = await load_camera_rois(camera_id, roi_manager)
    logger.info(f"Loaded {len(active_roi_ids)} ROIs for camera {camera_id}")

    # Create video processor
    processor = VideoProcessor(
        camera_id=camera.id,
        source=camera.source,
        source_type=camera.source_type
    )

    streaming = False

    try:
        while True:
            try:
                # Receive command from client
                data = await asyncio.wait_for(websocket.receive_text(), timeout=0.1)
                command = json.loads(data)

                if command.get("action") == "start":
                    streaming = True
                    logger.info(f"Starting stream for camera {camera_id}")
                    
                    # Send metadata
                    metadata = {
                        "type": "metadata",
                        "camera_id": camera_id,
                        "width": processor.width,
                        "height": processor.height,
                        "fps": processor.original_fps,
                        "total_frames": processor.total_frames,
                        "total_duration_ms": processor.total_duration_ms
                    }
                    await websocket.send_text(json.dumps(metadata))

                elif command.get("action") == "stop":
                    streaming = False
                    processor.is_running = False
                    logger.info(f"Stopping stream for camera {camera_id}")

                elif command.get("action") == "seek":
                    position_ms = command.get("position_ms", 0)
                    processor.seek(position_ms)

                elif command.get("action") == "reload_rois":
                    roi_manager.clear_rois()
                    active_roi_ids = await load_camera_rois(camera_id, roi_manager)

            except asyncio.TimeoutError:
                pass

            if streaming:
                # Stream frames
                async for stream_frame in processor.stream_frames(with_detection=True):
                    if not streaming:
                        break

                    # Evaluate safety rules
                    if stream_frame.detection:
                        events = rule_engine.evaluate(
                            stream_frame.detection,
                            camera_id,
                            active_roi_ids
                        )

                        # Process events with frame for snapshots
                        if events:
                            raw_frame = processor.get_current_frame()
                            async with AsyncSessionLocal() as db_session:
                                for event in events:
                                    event.camera_id = camera_id
                                    event_data = await alarm_manager.process_event(
                                        event,
                                        frame=raw_frame,
                                        db_session=db_session,
                                        position_ms=stream_frame.current_ms
                                    )
                                    stream_frame.events.append(event_data)

                                    # Broadcast to event subscribers
                                    await manager.broadcast_event(event_data)

                    # Add ROI overlay data
                    rois_data = roi_manager.get_all_rois()
                    
                    # Add real-time metrics (counts and stay times)
                    roi_metrics = rule_engine.get_roi_metrics(active_roi_ids)

                    # Send frame
                    frame_data = {
                        "type": "frame",
                        "camera_id": camera_id,
                        "frame": stream_frame.frame_base64,
                        "current_ms": stream_frame.current_ms,
                        "total_ms": stream_frame.total_ms,
                        "detection": stream_frame.detection.model_dump() if stream_frame.detection else None,
                        "events": stream_frame.events,
                        "rois": rois_data,
                        "roi_metrics": roi_metrics
                    }

                    await websocket.send_text(json.dumps(frame_data))

                    # Check for new commands
                    try:
                        data = await asyncio.wait_for(websocket.receive_text(), timeout=0.01)
                        command = json.loads(data)
                        if command.get("action") == "stop":
                            streaming = False
                            processor.is_running = False
                        elif command.get("action") == "seek":
                            position_ms = command.get("position_ms", 0)
                            processor.seek(position_ms)
                            logger.info(f"Seeking to {position_ms}ms during stream")
                        elif command.get("action") == "reload_rois":
                            roi_manager.clear_rois()
                            active_roi_ids = await load_camera_rois(camera_id, roi_manager)
                    except asyncio.TimeoutError:
                        pass

                # Stream ended
                streaming = False

            await asyncio.sleep(0.01)

    except WebSocketDisconnect:
        logger.info(f"Client disconnected from camera {camera_id}")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        processor.close()
        await manager.disconnect_stream(websocket, camera_id)


@router.websocket("/ws/events")
async def websocket_events(websocket: WebSocket):
    """
    WebSocket endpoint for event notifications only.

    Receives real-time safety event notifications.
    """
    await manager.connect_events(websocket)

    # Subscribe to alarm manager
    alarm_manager = get_alarm_manager()
    subscriber_id = f"ws_{id(websocket)}"

    async def on_event(event_data):
        try:
            await websocket.send_text(json.dumps({
                "type": "event",
                **event_data
            }))
        except Exception:
            pass

    alarm_manager.subscribe(subscriber_id, on_event)

    try:
        # Send initial unacknowledged events
        unack_events = alarm_manager.get_unacknowledged_events()
        if unack_events:
            await websocket.send_text(json.dumps({
                "type": "initial",
                "unacknowledged": unack_events
            }))

        while True:
            try:
                # Handle incoming commands
                data = await websocket.receive_text()
                command = json.loads(data)

                if command.get("action") == "acknowledge":
                    event_id = command.get("event_id")
                    if event_id:
                        await alarm_manager.acknowledge_event(event_id)
                        await websocket.send_text(json.dumps({
                            "type": "acknowledged",
                            "event_id": event_id
                        }))

            except WebSocketDisconnect:
                break
            except Exception as e:
                logger.error(f"Event WebSocket error: {e}")
                break

    finally:
        alarm_manager.unsubscribe(subscriber_id)
        await manager.disconnect_events(websocket)


@router.get("/ws/status")
async def get_websocket_status():
    """Get WebSocket connection status."""
    return {
        "event_subscribers": len(manager._event_subscribers),
        "stream_connections": {
            camera_id: len(connections)
            for camera_id, connections in manager._connections.items()
        }
    }
