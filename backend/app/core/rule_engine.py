"""
Safety rule engine for evaluating detection results.
"""
import logging
import time
from dataclasses import dataclass, field
from typing import List, Dict, Any, Optional, Set
from collections import defaultdict
from enum import Enum

from app.config import settings
from app.schemas.detection import DetectionResult, DetectionBox
from app.core.roi_manager import ROIManager

logger = logging.getLogger(__name__)


class EventType(str, Enum):
    """Safety event types."""
    ROI_INTRUSION = "ROI_INTRUSION"
    PPE_HELMET_MISSING = "PPE_HELMET_MISSING"
    PPE_MASK_MISSING = "PPE_MASK_MISSING"
    FIRE_EXTINGUISHER_MISSING = "FIRE_EXTINGUISHER_MISSING"
    WARNING_ZONE_INTRUSION = "WARNING_ZONE_INTRUSION"
    DANGER_ZONE_INTRUSION = "DANGER_ZONE_INTRUSION"


class Severity(str, Enum):
    """Event severity levels."""
    INFO = "INFO"
    WARNING = "WARNING"
    CRITICAL = "CRITICAL"


@dataclass
class SafetyEvent:
    """Safety event data."""
    event_type: EventType
    severity: Severity
    message: str
    roi_id: Optional[int] = None
    detection_data: Optional[Dict[str, Any]] = None
    camera_id: Optional[int] = None
    timestamp: float = field(default_factory=time.time)


@dataclass
class DetectionState:
    """Tracks detection state for false positive prevention."""
    first_detected: float = 0.0
    last_detected: float = 0.0
    frame_count: int = 0
    frames_in_window: List[bool] = field(default_factory=list)
    event_fired: bool = False
    last_event_time: float = 0.0
    stay_time: float = 0.0  # Total time in seconds


@dataclass
class PersonState:
    """Tracks state for an individual person (by track_id)."""
    track_id: int
    roi_id: int
    first_detected: float
    last_detected: float
    stay_time: float = 0.0


class RuleEngine:
    """
    Evaluates safety rules based on detection results.

    Implements false positive prevention and stay time tracking.
    """

    def __init__(self, roi_manager: ROIManager):
        """
        Initialize rule engine.

        Args:
            roi_manager: ROI manager instance
        """
        self.roi_manager = roi_manager
        self.persistence_seconds = settings.DETECTION_PERSISTENCE_SECONDS
        self.cooldown_seconds = settings.DETECTION_COOLDOWN_SECONDS
        self.frame_threshold = settings.DETECTION_FRAME_THRESHOLD
        self.frame_window = settings.DETECTION_FRAME_WINDOW

        # State tracking: key -> DetectionState
        # Keys: "roi_{roi_id}_person", "cam_{camera_id}_helmet_missing", etc.
        self._states: Dict[str, DetectionState] = defaultdict(DetectionState)
        
        # Per-person state tracking: (roi_id, track_id) -> PersonState
        self._person_states: Dict[tuple, PersonState] = {}

        # Track which ROIs require fire extinguisher
        self._roi_requires_extinguisher: Set[int] = set()

    def set_roi_requires_extinguisher(self, roi_id: int, required: bool = True):
        """Set whether a ROI requires fire extinguisher presence."""
        if required:
            self._roi_requires_extinguisher.add(roi_id)
        else:
            self._roi_requires_extinguisher.discard(roi_id)

    def _get_state_key(self, event_type: str, roi_id: Optional[int] = None, camera_id: Optional[int] = None, track_id: Optional[int] = None) -> str:
        """Generate state tracking key."""
        parts = [event_type]
        if roi_id is not None:
            parts.append(f"roi_{roi_id}")
        if camera_id is not None:
            parts.append(f"cam_{camera_id}")
        if track_id is not None:
            parts.append(f"track_{track_id}")
        return "_".join(parts)

    def _check_persistence(self, state: DetectionState, current_time: float, detected: bool) -> bool:
        """
        Check if detection persists long enough.

        Args:
            state: Detection state
            current_time: Current timestamp
            detected: Whether detection is present in current frame

        Returns:
            True if persistence threshold met
        """
        if detected:
            if state.first_detected == 0:
                state.first_detected = current_time
            state.last_detected = current_time
            state.frame_count += 1

            # Add to frame window
            state.frames_in_window.append(True)
            if len(state.frames_in_window) > self.frame_window:
                state.frames_in_window.pop(0)

            # Check persistence time
            duration = current_time - state.first_detected
            if duration < self.persistence_seconds:
                return False

            # Check frame threshold
            true_count = sum(state.frames_in_window)
            if true_count < self.frame_threshold:
                return False

            return True
        else:
            # Reset if not detected
            state.frames_in_window.append(False)
            if len(state.frames_in_window) > self.frame_window:
                state.frames_in_window.pop(0)

            # If mostly not detected, reset state
            false_count = state.frames_in_window.count(False)
            if false_count > self.frame_window * 0.7:
                state.first_detected = 0
                state.frame_count = 0

            return False

    def _check_cooldown(self, state: DetectionState, current_time: float) -> bool:
        """
        Check if cooldown period has passed.

        Args:
            state: Detection state
            current_time: Current timestamp

        Returns:
            True if cooldown passed (can fire event)
        """
        if state.last_event_time == 0:
            return True
        return (current_time - state.last_event_time) >= self.cooldown_seconds

    def evaluate(
        self,
        detection: DetectionResult,
        camera_id: int,
        active_roi_ids: Optional[List[int]] = None
    ) -> List[SafetyEvent]:
        """
        Evaluate detection result against safety rules.

        Args:
            detection: Detection result from YOLO
            camera_id: Camera ID
            active_roi_ids: List of active ROI IDs to check

        Returns:
            List of safety events (only new events after persistence/cooldown)
        """
        events: List[SafetyEvent] = []
        current_time = time.time()

        # Get detections by class
        persons = [d for d in detection.detections if d.class_name == "person"]
        helmets = [d for d in detection.detections if d.class_name == "helmet"]
        masks = [d for d in detection.detections if d.class_name == "mask"]
        extinguishers = [d for d in detection.detections if d.class_name == "fire_extinguisher"]

        # Check each active ROI
        if active_roi_ids:
            for roi_id in active_roi_ids:
                roi_events = self._evaluate_roi(
                    roi_id=roi_id,
                    camera_id=camera_id,
                    persons=persons,
                    helmets=helmets,
                    masks=masks,
                    extinguishers=extinguishers,
                    current_time=current_time
                )
                events.extend(roi_events)

        return events

    def _evaluate_roi(
        self,
        roi_id: int,
        camera_id: int,
        persons: List[DetectionBox],
        helmets: List[DetectionBox],
        masks: List[DetectionBox],
        extinguishers: List[DetectionBox],
        current_time: float
    ) -> List[SafetyEvent]:
        """Evaluate rules for a single ROI."""
        events: List[SafetyEvent] = []
        
        # Get ROI info
        roi_data = self.roi_manager.get_roi(roi_id)
        zone_type = roi_data.get("zone_type", "warning") if roi_data else "warning"

        # Find persons in this ROI
        persons_in_roi = [
            p for p in persons
            if self.roi_manager.is_detection_in_roi(roi_id, p)
        ]
        
        # Update individual person stay times
        for person in persons_in_roi:
            if person.track_id is not None:
                key = (roi_id, person.track_id)
                if key not in self._person_states:
                    self._person_states[key] = PersonState(
                        track_id=person.track_id,
                        roi_id=roi_id,
                        first_detected=current_time,
                        last_detected=current_time
                    )
                else:
                    state = self._person_states[key]
                    state.last_detected = current_time
                    state.stay_time = current_time - state.first_detected

        # Rule 1: ROI Intrusion (Warning or Danger)
        event_type = EventType.DANGER_ZONE_INTRUSION if zone_type == "danger" else EventType.WARNING_ZONE_INTRUSION
        severity = Severity.CRITICAL if zone_type == "danger" else Severity.WARNING
        
        intrusion_key = self._get_state_key(event_type.value, roi_id)
        intrusion_state = self._states[intrusion_key]
        has_person = len(persons_in_roi) > 0

        if self._check_persistence(intrusion_state, current_time, has_person):
            if not intrusion_state.event_fired and self._check_cooldown(intrusion_state, current_time):
                intrusion_state.event_fired = True
                intrusion_state.last_event_time = current_time
                
                msg_prefix = "위험" if zone_type == "danger" else "경고"
                events.append(SafetyEvent(
                    event_type=event_type,
                    severity=severity,
                    message=f"{msg_prefix} 영역 작업자 감지 (ROI #{roi_id}, 인원: {len(persons_in_roi)}명)",
                    roi_id=roi_id,
                    camera_id=camera_id,
                    detection_data={
                        "persons_count": len(persons_in_roi),
                        "zone_type": zone_type,
                        "stay_times": {p.track_id: round(current_time - self._person_states[(roi_id, p.track_id)].first_detected, 1) 
                                       for p in persons_in_roi if p.track_id is not None and (roi_id, p.track_id) in self._person_states}
                    }
                ))
        else:
            intrusion_state.event_fired = False

        # Cleanup person states for people who left the ROI
        current_track_ids = {p.track_id for p in persons_in_roi if p.track_id is not None}
        keys_to_remove = []
        for key, state in self._person_states.items():
            if key[0] == roi_id and key[1] not in current_track_ids:
                # If person was not seen for more than 5 seconds, remove state
                if current_time - state.last_detected > 5.0:
                    keys_to_remove.append(key)
        for key in keys_to_remove:
            del self._person_states[key]

        # Only check PPE if person is in ROI
        if not has_person:
            return events

        # Rule 2: Helmet Missing
        helmet_key = self._get_state_key(EventType.PPE_HELMET_MISSING.value, roi_id)
        helmet_state = self._states[helmet_key]

        # Check if any helmet near any person in ROI
        helmet_missing = not self._has_ppe_near_persons(persons_in_roi, helmets)

        if self._check_persistence(helmet_state, current_time, helmet_missing):
            if not helmet_state.event_fired and self._check_cooldown(helmet_state, current_time):
                helmet_state.event_fired = True
                helmet_state.last_event_time = current_time
                events.append(SafetyEvent(
                    event_type=EventType.PPE_HELMET_MISSING,
                    severity=Severity.WARNING,
                    message=f"안전모 미착용 감지 (ROI #{roi_id})",
                    roi_id=roi_id,
                    camera_id=camera_id,
                    detection_data={"persons_count": len(persons_in_roi)}
                ))
        else:
            helmet_state.event_fired = False

        # Rule 3: Mask Missing
        mask_key = self._get_state_key(EventType.PPE_MASK_MISSING.value, roi_id)
        mask_state = self._states[mask_key]

        mask_missing = not self._has_ppe_near_persons(persons_in_roi, masks)

        if self._check_persistence(mask_state, current_time, mask_missing):
            if not mask_state.event_fired and self._check_cooldown(mask_state, current_time):
                mask_state.event_fired = True
                mask_state.last_event_time = current_time
                events.append(SafetyEvent(
                    event_type=EventType.PPE_MASK_MISSING,
                    severity=Severity.WARNING,
                    message=f"마스크 미착용 감지 (ROI #{roi_id})",
                    roi_id=roi_id,
                    camera_id=camera_id,
                    detection_data={"persons_count": len(persons_in_roi)}
                ))
        else:
            mask_state.event_fired = False

        # Rule 4: Fire Extinguisher Missing (only if ROI requires it)
        if roi_id in self._roi_requires_extinguisher:
            ext_key = self._get_state_key(EventType.FIRE_EXTINGUISHER_MISSING.value, roi_id)
            ext_state = self._states[ext_key]

            # Check if any extinguisher in ROI
            ext_in_roi = any(
                self.roi_manager.is_detection_in_roi(roi_id, e)
                for e in extinguishers
            )
            ext_missing = not ext_in_roi

            if self._check_persistence(ext_state, current_time, ext_missing):
                if not ext_state.event_fired and self._check_cooldown(ext_state, current_time):
                    ext_state.event_fired = True
                    ext_state.last_event_time = current_time
                    events.append(SafetyEvent(
                        event_type=EventType.FIRE_EXTINGUISHER_MISSING,
                        severity=Severity.WARNING,
                        message=f"소화기 미비치 감지 (ROI #{roi_id})",
                        roi_id=roi_id,
                        camera_id=camera_id,
                        detection_data={"has_person": True}
                    ))
            else:
                ext_state.event_fired = False

        return events

    def _has_ppe_near_persons(
        self,
        persons: List[DetectionBox],
        ppe_items: List[DetectionBox],
        threshold: float = 100.0
    ) -> bool:
        """
        Check if PPE items are near persons (simple proximity check).

        Args:
            persons: List of person detections
            ppe_items: List of PPE detections (helmet/mask)
            threshold: Maximum distance to consider "near"

        Returns:
            True if PPE found near any person
        """
        if not persons:
            return True  # If no persons, consider PPE check as passed
        if not ppe_items:
            return False  # If persons but no PPE items, PPE is missing

        for person in persons:
            for ppe in ppe_items:
                # Check if PPE is above person (helmet/mask should be near head)
                # PPE should be within person's bounding box horizontally
                # and near the top of person's box vertically
                if (person.x1 <= ppe.center_x <= person.x2 and
                    person.y1 - threshold <= ppe.center_y <= person.y1 + (person.y2 - person.y1) * 0.4):
                    return True

        return False

    def reset_state(self, roi_id: Optional[int] = None):
        """
        Reset detection states.

        Args:
            roi_id: If provided, only reset states for this ROI
        """
        if roi_id is not None:
            keys_to_remove = [k for k in self._states if f"roi_{roi_id}" in k]
            for key in keys_to_remove:
                del self._states[key]
        else:
            self._states.clear()

    def get_roi_metrics(self, active_roi_ids: List[int]) -> Dict[int, Dict[str, Any]]:
        """
        Get real-time metrics for each active ROI.
        
        Returns:
            Dict mapping roi_id to its metrics (count, stay_times).
        """
        metrics = {}
        for roi_id in active_roi_ids:
            roi_data = self.roi_manager.get_roi(roi_id)
            zone_type = roi_data.get("zone_type", "warning") if roi_data else "warning"
            
            # Find people currently in this ROI
            # Note: Using _person_states which is updated during evaluate()
            persons_in_roi = [state for key, state in self._person_states.items() 
                              if key[0] == roi_id]
            
            metrics[roi_id] = {
                "count": len(persons_in_roi),
                "zone_type": zone_type,
                "people": [
                    {
                        "track_id": p.track_id,
                        "stay_time": round(p.stay_time, 1)
                    } for p in persons_in_roi
                ]
            }
        return metrics

    def get_current_status(self, camera_id: int) -> Dict[str, Any]:
        """
        Get current safety status summary.

        Args:
            camera_id: Camera ID

        Returns:
            Dict with current status information
        """
        active_violations = []

        for key, state in self._states.items():
            if state.event_fired:
                parts = key.split("_")
                event_type = parts[0]
                if len(parts) > 1 and "roi" in parts:
                    roi_idx = parts.index("roi") + 1
                    roi_id = int(parts[roi_idx])
                else:
                    roi_id = None

                active_violations.append({
                    "event_type": event_type,
                    "roi_id": roi_id,
                    "duration": time.time() - state.first_detected
                })

        return {
            "camera_id": camera_id,
            "active_violations": active_violations,
            "overall_status": "CRITICAL" if active_violations else "OK"
        }


# Factory function
def create_rule_engine(roi_manager: ROIManager) -> RuleEngine:
    """Create a new rule engine instance."""
    return RuleEngine(roi_manager)
