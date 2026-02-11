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
            # Initialize with correct positional encoding size, NO pretrain weights, and correct device
            device_str = "cuda" if torch.cuda.is_available() else "cpu"
            self.model = RFDETRMedium(positional_encoding_size=32, pretrain_weights=None, device=device_str)
            
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

            # RFDETRMedium is a wrapper; reinitialize head to match checkpoint (11 PPE classes + 1 background = 12)
            if hasattr(self.model, 'model') and hasattr(self.model.model, 'reinitialize_detection_head'):
                self.model.model.reinitialize_detection_head(12)
                logger.info("Reinitialized RF-DETR detection head to 12 classes")
            
            # Use safety checks for nested attributes for loading state_dict
            target_model = self.model
            if hasattr(self.model, 'model'):
                target_model = self.model.model
                if hasattr(target_model, 'model'):
                    target_model = target_model.model
            
            if hasattr(target_model, 'load_state_dict'):
                target_model.load_state_dict(state_dict, strict=False)
                logger.info("Loaded RF-DETR state_dict successfully")
                target_model.eval()
                
                # Optimize for inference
                if hasattr(target_model, 'optimize_for_inference'):
                    target_model.optimize_for_inference()
                    logger.info("Optimized RF-DETR for inference")
                
                if torch.cuda.is_available():
                    target_model.cuda()
            else:
                logger.warning("Could not find load_state_dict on RF-DETR model or its internals")
            
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
            # results typically returns sv.Detections or a list of them
            results = self.model.predict(frame, threshold=settings.RFDETR_CONFIDENCE_THRESHOLD)
            
            # Ensure we have a single sv.Detections object
            if isinstance(results, list):
                results = results[0] if len(results) > 0 else None
            
            if results is None or len(results) == 0:
                return DetectionResult(frame_number=frame_number, timestamp=timestamp, detections=[], **counts)

            # Convert sv.Detections to [x1, y1, x2, y2, score, cls] format for tracker
            raw_detections = np.column_stack([
                results.xyxy,
                results.confidence,
                results.class_id
            ])

            # Apply BoT-SORT tracking
            tracked_objects = []
            if self.tracker:
                tracked_objects = self.tracker.update(raw_detections, frame)
            
            # Map tracked objects back to DetectionBox
            # If tracking failed or returned empty, use raw detections with no track_id
            if len(tracked_objects) == 0:
                for i in range(len(raw_detections)):
                    x1, y1, x2, y2, conf, cls_id = raw_detections[i]
                    cls_id = int(cls_id)
                    class_name = settings.CLASS_NAMES[cls_id] if cls_id < len(settings.CLASS_NAMES) else f"obj_{cls_id}"
                    category, counts = self._map_category(class_name, counts)
                    detections.append(DetectionBox(
                        class_id=cls_id, class_name=category, confidence=float(conf),
                        x1=float(x1), y1=float(y1), x2=float(x2), y2=float(y2),
                        center_x=float((x1+x2)/2), center_y=float((y1+y2)/2),
                        track_id=None
                    ))
            else:
                for obj in tracked_objects:
                    # Output format: [x1, y1, x2, y2, id, conf, cls]
                    x1, y1, x2, y2, tid, conf, cls_id = obj
                    cls_id = int(cls_id)
                    class_name = settings.CLASS_NAMES[cls_id] if cls_id < len(settings.CLASS_NAMES) else f"obj_{cls_id}"
                    category, counts = self._map_category(class_name, counts)
                    detections.append(DetectionBox(
                        class_id=cls_id, class_name=category, confidence=float(conf),
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
# Global cache for detector instance
_detector_instance: Optional[BaseDetector] = None

def get_detector() -> BaseDetector:
    global _detector_instance
    if _detector_instance is not None:
        return _detector_instance

    if settings.DETECTOR_TYPE == "rfdetr":
        _detector_instance = RFDETRDetector()
    else:
        _detector_instance = YOLODetector()
    
    return _detector_instance
