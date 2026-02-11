from app.schemas.camera import CameraCreate, CameraUpdate, CameraResponse
from app.schemas.roi import ROICreate, ROIUpdate, ROIResponse
from app.schemas.event import EventCreate, EventResponse, EventAcknowledge
from app.schemas.checklist import ChecklistCreate, ChecklistResponse, ChecklistItemUpdate
from app.schemas.detection import DetectionResult, DetectionBox, StreamFrame

__all__ = [
    "CameraCreate",
    "CameraUpdate",
    "CameraResponse",
    "ROICreate",
    "ROIUpdate",
    "ROIResponse",
    "EventCreate",
    "EventResponse",
    "EventAcknowledge",
    "ChecklistCreate",
    "ChecklistResponse",
    "ChecklistItemUpdate",
    "DetectionResult",
    "DetectionBox",
    "StreamFrame",
]
