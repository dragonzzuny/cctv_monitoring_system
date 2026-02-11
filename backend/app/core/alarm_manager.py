"""
Alarm management module for handling safety events.
"""
import asyncio
import json
import logging
import os
import time
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Callable, Any
import cv2
import numpy as np

from app.config import settings
from app.core.rule_engine import SafetyEvent, Severity

logger = logging.getLogger(__name__)


class AlarmManager:
    """
    Manages safety alarms and event notifications.

    Responsibilities:
    - Save event snapshots
    - Manage event queue
    - Notify WebSocket clients
    - Track unacknowledged alarms
    """

    def __init__(self):
        """Initialize alarm manager."""
        self._event_queue: asyncio.Queue = asyncio.Queue()
        self._subscribers: Dict[str, Callable] = {}  # subscriber_id -> callback
        self._unacknowledged: Dict[int, SafetyEvent] = {}  # event_id -> event
        self._next_event_id = 1
        self._snapshot_dir = settings.SNAPSHOTS_DIR

    async def process_event(
        self,
        event: SafetyEvent,
        frame: Optional[np.ndarray] = None,
        db_session=None
    ) -> Dict[str, Any]:
        """
        Process a safety event.

        Args:
            event: Safety event to process
            frame: Optional video frame for snapshot
            db_session: Optional database session for saving event

        Returns:
            Processed event data
        """
        event_id = self._next_event_id
        self._next_event_id += 1

        # Save snapshot if frame provided
        snapshot_path = None
        if frame is not None:
            snapshot_path = await self._save_snapshot(event_id, event, frame)

        # Build event data
        event_data = {
            "id": event_id,
            "event_type": event.event_type.value,
            "severity": event.severity.value,
            "message": event.message,
            "camera_id": event.camera_id,
            "roi_id": event.roi_id,
            "snapshot_path": snapshot_path,
            "detection_data": event.detection_data,
            "is_acknowledged": False,
            "created_at": datetime.utcnow().isoformat(),
            "timestamp": event.timestamp
        }

        # Track unacknowledged warning/critical events
        if event.severity in [Severity.WARNING, Severity.CRITICAL]:
            self._unacknowledged[event_id] = event

        # Save to database if session provided
        if db_session:
            await self._save_to_db(event_data, db_session)

        # Notify subscribers
        await self._notify_subscribers(event_data)

        # Add to queue
        await self._event_queue.put(event_data)

        logger.info(
            f"Event processed: [{event.severity.value}] {event.event_type.value} - {event.message}"
        )

        return event_data

    async def _save_snapshot(
        self,
        event_id: int,
        event: SafetyEvent,
        frame: np.ndarray
    ) -> Optional[str]:
        """
        Save event snapshot to disk.

        Args:
            event_id: Event ID
            event: Safety event
            frame: Video frame

        Returns:
            Snapshot file path
        """
        try:
            # Create date-based directory
            date_str = datetime.now().strftime("%Y%m%d")
            snapshot_dir = self._snapshot_dir / date_str
            snapshot_dir.mkdir(parents=True, exist_ok=True)

            # Generate filename
            timestamp = datetime.now().strftime("%H%M%S")
            filename = f"event_{event_id}_{event.event_type.value}_{timestamp}.jpg"
            filepath = snapshot_dir / filename

            # Draw event info on frame
            frame_with_info = self._draw_event_info(frame.copy(), event)

            # Save image
            cv2.imwrite(str(filepath), frame_with_info)

            logger.debug(f"Snapshot saved: {filepath}")
            # Return relative path for API access (relative to snapshots directory)
            return f"/snapshots/{date_str}/{filename}"

        except Exception as e:
            logger.error(f"Failed to save snapshot: {e}")
            return None

    def _draw_event_info(self, frame: np.ndarray, event: SafetyEvent) -> np.ndarray:
        """Draw event information on frame."""
        # Color based on severity
        colors = {
            Severity.INFO: (0, 255, 0),      # Green
            Severity.WARNING: (0, 165, 255),  # Orange
            Severity.CRITICAL: (0, 0, 255)    # Red
        }
        color = colors.get(event.severity, (255, 255, 255))

        # Draw header bar
        cv2.rectangle(frame, (0, 0), (frame.shape[1], 60), color, -1)

        # Draw event type and message
        cv2.putText(
            frame,
            f"[{event.severity.value}] {event.event_type.value}",
            (10, 25),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.7,
            (255, 255, 255),
            2
        )
        cv2.putText(
            frame,
            event.message,
            (10, 50),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 255, 255),
            1
        )

        # Draw timestamp
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        cv2.putText(
            frame,
            timestamp,
            (frame.shape[1] - 200, 25),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.5,
            (255, 255, 255),
            1
        )

        return frame

    async def _save_to_db(self, event_data: Dict[str, Any], db_session):
        """Save event to database."""
        try:
            from app.db.models import Event

            db_event = Event(
                camera_id=event_data["camera_id"],
                event_type=event_data["event_type"],
                severity=event_data["severity"],
                message=event_data["message"],
                snapshot_path=event_data.get("snapshot_path"),
                roi_id=event_data.get("roi_id"),
                detection_data=json.dumps(event_data.get("detection_data")) if event_data.get("detection_data") else None,
                is_acknowledged=False
            )
            db_session.add(db_event)
            await db_session.commit()
            await db_session.refresh(db_event)
            event_data["id"] = db_event.id

        except Exception as e:
            logger.error(f"Failed to save event to database: {e}")

    async def _notify_subscribers(self, event_data: Dict[str, Any]):
        """Notify all subscribers of new event."""
        for subscriber_id, callback in self._subscribers.items():
            try:
                if asyncio.iscoroutinefunction(callback):
                    await callback(event_data)
                else:
                    callback(event_data)
            except Exception as e:
                logger.error(f"Error notifying subscriber {subscriber_id}: {e}")

    def subscribe(self, subscriber_id: str, callback: Callable):
        """
        Subscribe to event notifications.

        Args:
            subscriber_id: Unique subscriber identifier
            callback: Function to call on new events
        """
        self._subscribers[subscriber_id] = callback
        logger.debug(f"Subscriber added: {subscriber_id}")

    def unsubscribe(self, subscriber_id: str):
        """Unsubscribe from event notifications."""
        if subscriber_id in self._subscribers:
            del self._subscribers[subscriber_id]
            logger.debug(f"Subscriber removed: {subscriber_id}")

    async def acknowledge_event(self, event_id: int) -> bool:
        """
        Acknowledge an event.

        Args:
            event_id: Event ID to acknowledge

        Returns:
            True if acknowledged successfully
        """
        if event_id in self._unacknowledged:
            del self._unacknowledged[event_id]
            logger.info(f"Event {event_id} acknowledged")
            return True
        return False

    def get_unacknowledged_events(self) -> List[Dict[str, Any]]:
        """Get all unacknowledged events."""
        return [
            {
                "event_type": event.event_type.value,
                "severity": event.severity.value,
                "message": event.message,
                "camera_id": event.camera_id,
                "roi_id": event.roi_id,
                "timestamp": event.timestamp
            }
            for event in self._unacknowledged.values()
        ]

    def get_unacknowledged_count(self) -> int:
        """Get count of unacknowledged events."""
        return len(self._unacknowledged)

    async def get_next_event(self, timeout: Optional[float] = None) -> Optional[Dict[str, Any]]:
        """
        Get next event from queue.

        Args:
            timeout: Optional timeout in seconds

        Returns:
            Event data or None if timeout
        """
        try:
            if timeout:
                return await asyncio.wait_for(
                    self._event_queue.get(),
                    timeout=timeout
                )
            else:
                return await self._event_queue.get()
        except asyncio.TimeoutError:
            return None


# Global alarm manager instance
_alarm_manager_instance: Optional[AlarmManager] = None


def get_alarm_manager() -> AlarmManager:
    """Get or create the global alarm manager instance."""
    global _alarm_manager_instance
    if _alarm_manager_instance is None:
        _alarm_manager_instance = AlarmManager()
    return _alarm_manager_instance
