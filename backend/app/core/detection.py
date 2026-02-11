"""
Multi-backend detection module for object detection and tracking.
Supports YOLO and RF-DETR with BoT-SORT tracking.
"""
import logging
import time
import os
from pathlib import Path
from typing import List, Optional, Dict, Any, Union
import numpy as np
import torch
from abc import ABC, abstractmethod

from app.config import settings
from app.schemas.detection import DetectionBox, DetectionResult
from app.core.tracker import get_tracker

logger = logging.getLogger(__name__)

# Try to import RF-DETR
try:
    from rfdetr import RFDETRSmall, RFDETRMedium, RFDETRLarge, RFDETRXLarge
    RF_DETR_AVAILABLE = True
except ImportError:
    RF_DETR_AVAILABLE = False

# Base Detector Interface
class BaseDetector(ABC):
    @abstractmethod
    def load_model(self) -> bool:
        pass

    @abstractmethod
    def detect(self, frame: np.ndarray, frame_number: int = 0, timestamp: float = 0.0) -> DetectionResult:
        pass

    @property
    @abstractmethod
    def is_loaded(self) -> bool:
        pass

# YOLO Detector Implementation
class YOLODetector(BaseDetector):
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or settings.YOLO_MODEL_PATH
        self.model = None
        self.class_names = settings.CLASS_NAMES
        self.confidence_threshold = settings.YOLO_CONFIDENCE_THRESHOLD
        self.iou_threshold = settings.YOLO_IOU_THRESHOLD
        self._is_loaded = False

    def load_model(self) -> bool:
        try:
            from ultralytics import YOLO
            model_file = settings.BASE_DIR / self.model_path
            if not model_file.exists():
                self.model = YOLO("yolov8n.pt")
            else:
                self.model = YOLO(str(model_file))
            self._is_loaded = True
            return True
        except Exception as e:
            logger.error(f"Failed to load YOLO model: {e}")
            return False

    def detect(self, frame: np.ndarray, frame_number: int = 0, timestamp: float = 0.0) -> DetectionResult:
        if not self._is_loaded:
            self.load_model()
        
        detections: List[DetectionBox] = []
        counts = {"persons_count": 0, "helmets_count": 0, "masks_count": 0, "fire_extinguishers_count": 0}
        
        try:
            results = self.model.track(frame, conf=0.5, iou=self.iou_threshold, verbose=False, persist=True)
            for result in results:
                if result.boxes is None: continue
                for box in result.boxes:
                    cls_id = int(box.cls[0])
                    conf = float(box.conf[0])
                    xyxy = box.xyxy[0].cpu().numpy()
                    track_id = int(box.id[0]) if box.id is not None else None
                    
                    class_name = result.names[cls_id] if hasattr(result, 'names') else str(cls_id)
                    category, counts = self._map_category(class_name, counts)
                    
                    detections.append(DetectionBox(
                        class_id=cls_id, class_name=category, confidence=conf,
                        x1=float(xyxy[0]), y1=float(xyxy[1]), x2=float(xyxy[2]), y2=float(xyxy[3]),
                        center_x=float((xyxy[0]+xyxy[2])/2), center_y=float((xyxy[1]+xyxy[3])/2),
                        track_id=track_id
                    ))
        except Exception as e:
            logger.error(f"YOLO Detection error: {e}")

        return DetectionResult(frame_number=frame_number, timestamp=timestamp, detections=detections, **counts)

    def _map_category(self, class_name: str, counts: Dict) -> tuple:
        class_name_lower = class_name.lower().strip()
        if any(word in class_name_lower for word in ["person", "worker"]):
            counts["persons_count"] += 1
            return "person", counts
        elif "helmet" in class_name_lower:
            counts["helmets_count"] += 1
            return "helmet", counts
        elif "mask" in class_name_lower:
            counts["masks_count"] += 1
            return "mask", counts
        elif "fire_extinguisher" in class_name_lower:
            counts["fire_extinguishers_count"] += 1
            return "fire_extinguisher", counts
        return class_name, counts

    @property
    def is_loaded(self) -> bool:
        return self._is_loaded

# RF-DETR Detector Implementation with BoT-SORT
class RFDETRDetector(BaseDetector):
    def __init__(self, model_path: Optional[str] = None):
        self.model_path = model_path or settings.RFDETR_MODEL_PATH
        self.model = None
        self._is_loaded = False
        self.tracker = None
        self._setup_tracker()

    def _setup_tracker(self):
        """Initialize BoT-SORT tracker."""
        try:
            self.tracker = get_tracker("bot_sort", frame_rate=settings.VIDEO_FPS)
            logger.info("BoT-SORT tracker integrated with RF-DETR")
        except Exception as e:
            logger.warning(f"Failed to load BoT-SORT: {e}")

    def load_model(self) -> bool:
        if not RF_DETR_AVAILABLE:
            logger.error("RF-DETR not installed")
            return False
        try:
            self.model = RFDETRMedium()
            # Extract state_dict from checkpoint (supports various formats)
            checkpoint = torch.load(settings.BASE_DIR / self.model_path, map_location='cpu', weights_only=False)
            if isinstance(checkpoint, dict):
                if 'model_ema' in checkpoint:
                    state_dict = checkpoint['model_ema']
                elif 'model' in checkpoint:
                    state_dict = checkpoint['model']
                elif 'state_dict' in checkpoint:
                    state_dict = checkpoint['state_dict']
                else:
                    state_dict = checkpoint
            else:
                state_dict = checkpoint
            self.model.load_state_dict(state_dict, strict=False)
            self.model.eval()
            if torch.cuda.is_available():
                self.model.cuda()
            self._is_loaded = True
            return True
        except Exception as e:
            logger.error(f"Failed to load RF-DETR model: {e}")
            return False

    def detect(self, frame: np.ndarray, frame_number: int = 0, timestamp: float = 0.0) -> DetectionResult:
        if not self._is_loaded:
            if not self.load_model():
                return DetectionResult(frame_number=frame_number, timestamp=timestamp, detections=[])

        detections: List[DetectionBox] = []
        counts = {"persons_count": 0, "helmets_count": 0, "masks_count": 0, "fire_extinguishers_count": 0}

        try:
            # Prepare frame for DETR (standard preprocessing)
            # This is a simplified version; real RF-DETR might need sahi slicing or specific transforms
            results = self.model.predict(frame, conf=settings.RFDETR_CONFIDENCE_THRESHOLD)
            
            # results here should be converted to a format BoT-SORT expects: [x1, y1, x2, y2, score, cls]
            raw_detections = []
            for res in results:
                raw_detections.append([res.x1, res.y1, res.x2, res.y2, res.confidence, res.class_id])

            # Apply BoT-SORT tracking
            tracked_objects = []
            if self.tracker:
                tracked_objects = self.tracker.update(np.array(raw_detections), frame)
            
            # Map tracked objects back to DetectionBox
            # tracked_objects: [x1, y1, x2, y2, track_id, score, cls] (typical BoT-SORT output)
            for obj in tracked_objects:
                x1, y1, x2, y2, tid, conf, cls_id = obj
                cls_id = int(cls_id)
                class_name = settings.CLASS_NAMES[cls_id] if cls_id < len(settings.CLASS_NAMES) else f"obj_{cls_id}"
                
                category, counts = self._map_category(class_name, counts)
                
                detections.append(DetectionBox(
                    class_id=cls_id, class_name=category, confidence=conf,
                    x1=float(x1), y1=float(y1), x2=float(x2), y2=float(y2),
                    center_x=float((x1+x2)/2), center_y=float((y1+y2)/2),
                    track_id=int(tid)
                ))

        except Exception as e:
            logger.error(f"RF-DETR Detection error: {e}")

        return DetectionResult(frame_number=frame_number, timestamp=timestamp, detections=detections, **counts)

    def _map_category(self, class_name: str, counts: Dict) -> tuple:
        # standard mapping for 11 classes
        class_name_lower = class_name.lower().strip().replace("_", "").replace(" ", "")
        
        mapping = {
            "person": ["person", "worker", "man", "woman"],
            "helmet": ["helmet", "hardhat", "safetyhelmet"],
            "gloves": ["gloves", "glove"],
            "vest": ["vest", "safetyvest"],
            "boots": ["boots", "safetyboots", "shoes"],
            "goggles": ["goggles", "safetyglass", "eyeprotection"],
            "mask": ["mask", "safetymask", "facemask"],
            "machinery": ["machinery", "machine", "equipment"],
            "vehicle": ["vehicle", "car", "truck", "forklift"],
            "safety_cone": ["safetycone", "cone"],
            "fire_extinguisher": ["fireextinguisher", "extinguisher"]
        }
        
        for category, keywords in mapping.items():
            if any(k in class_name_lower for k in keywords):
                count_key = f"{category}s_count" if not category.endswith('y') else f"{category[:-1]}ies_count"
                # Note: schema only has 4 specific count fields, we skip others or add them if needed
                if count_key in counts:
                    counts[count_key] += 1
                return category, counts
                
        return class_name, counts

    @property
    def is_loaded(self) -> bool:
        return self._is_loaded

# Factory function
def get_detector() -> BaseDetector:
    if settings.DETECTOR_TYPE == "rfdetr":
        return RFDETRDetector()
    return YOLODetector()
