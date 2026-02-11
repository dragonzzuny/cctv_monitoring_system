"""
ROI (Region of Interest) management module.
"""
import json
import logging
from typing import List, Dict, Any, Optional, Tuple
from shapely.geometry import Point, Polygon

from app.schemas.roi import Point as ROIPoint
from app.schemas.detection import DetectionBox

logger = logging.getLogger(__name__)


class ROIManager:
    """Manages ROI operations and collision detection."""

    def __init__(self):
        """Initialize ROI manager."""
        self._rois: Dict[int, Dict[str, Any]] = {}  # roi_id -> roi_data

    def add_roi(self, roi_id: int, points: List[ROIPoint], name: str = "", color: str = "#FF0000", zone_type: str = "warning"):
        """
        Add a ROI to the manager.

        Args:
            roi_id: Unique ROI identifier
            points: List of Point objects defining the polygon
            name: ROI name
            color: Display color
            zone_type: "warning" or "danger"
        """
        try:
            # Detect if points are in pixel space (e.g., 1280x720) or normalized (0-1)
            # Find max values to determine scaling
            px_maxx = max(p.x for p in points)
            px_maxy = max(p.y for p in points)
            
            # Heuristic for normalization
            scale_x = 1.0
            scale_y = 1.0
            if px_maxx > 1.1:
                # Based on user's ROI bounds (~1093, ~516), it looks like 1280x720
                scale_x = 1280.0 if px_maxx > 1.1 else 1.0
                scale_y = 720.0 if px_maxy > 1.1 else 1.0
                
                # If maxx is even larger (e.g. 1920), adjust
                if px_maxx > 1300: scale_x = 1920.0
                if px_maxy > 800: scale_y = 1080.0

            normalized_points = []
            for p in points:
                nx = p.x / scale_x if scale_x > 1.0 else p.x
                ny = p.y / scale_y if scale_y > 1.0 else p.y
                normalized_points.append({"x": nx, "y": ny})
            
            coords = [(p["x"], p["y"]) for p in normalized_points]
            if len(coords) < 3:
                logger.warning(f"ROI {roi_id} has less than 3 points, skipping")
                return

            polygon = Polygon(coords)
            if not polygon.is_valid:
                polygon = polygon.buffer(0)

            self._rois[roi_id] = {
                "id": roi_id,
                "name": name,
                "color": color,
                "zone_type": zone_type,
                "points": normalized_points,
                "polygon": polygon
            }
            logger.info(f"Added/Updated ROI {roi_id}: {name} ({zone_type}) - Normalized to {scale_x}x{scale_y}")

        except Exception as e:
            logger.error(f"Error adding ROI {roi_id}: {e}")

    def remove_roi(self, roi_id: int):
        """Remove a ROI from the manager."""
        if roi_id in self._rois:
            del self._rois[roi_id]
            logger.debug(f"Removed ROI {roi_id}")

    def clear_rois(self):
        """Clear all ROIs."""
        self._rois.clear()

    def get_roi(self, roi_id: int) -> Optional[Dict[str, Any]]:
        """Get ROI data by ID."""
        roi = self._rois.get(roi_id)
        if roi:
            return {k: v for k, v in roi.items() if k != "polygon"}
        return None

    def get_all_rois(self) -> List[Dict[str, Any]]:
        """Get all ROIs without polygon objects."""
        return [
            {k: v for k, v in roi.items() if k != "polygon"}
            for roi in self._rois.values()
        ]

    def is_point_in_roi(self, roi_id: int, x: float, y: float, canvas_width: float = 0.0, canvas_height: float = 0.0) -> bool:
        """
        Check if a point is inside a ROI.
        Expects x, y as pixel coordinates from the detector.
        Standardizes to normalized space for the comparison.
        """
        roi = self._rois.get(roi_id)
        if roi is None:
            return False

        # Detection frame resolution (standardized in our system)
        # However, we've seen detector output can be aligned with 'canvas_width'
        DET_WIDTH = 640.0
        DET_HEIGHT = 360.0
        
        # Use provided dimensions if available, otherwise fallback to DET_WIDTH/DET_HEIGHT
        eff_width = canvas_width if canvas_width > 0 else DET_WIDTH
        eff_height = canvas_height if canvas_height > 0 else DET_HEIGHT
        
        # Normalize the detection point
        norm_x = x / eff_width
        norm_y = y / eff_height
        
        point = Point(norm_x, norm_y)
        return roi["polygon"].contains(point)

    def is_detection_in_roi(self, roi_id: int, detection: DetectionBox, canvas_width: float = 0.0, canvas_height: float = 0.0) -> bool:
        """
        Check if a detection's bottom-center (feet) is inside a ROI.
        """
        # FOOT BASED: Use bottom-center for ROI check
        res = self.is_point_in_roi(roi_id, detection.center_x, detection.y2, canvas_width, canvas_height)
        return res

    def is_detection_box_in_roi(
        self,
        roi_id: int,
        detection: DetectionBox,
        threshold: float = 0.5
    ) -> bool:
        """
        Check if a detection box overlaps with ROI.

        Args:
            roi_id: ROI identifier
            detection: Detection box
            threshold: Minimum overlap ratio (0-1)

        Returns:
            True if overlap ratio exceeds threshold
        """
        roi = self._rois.get(roi_id)
        if roi is None:
            return False

        try:
            # Create box polygon from detection
            box = Polygon([
                (detection.x1, detection.y1),
                (detection.x2, detection.y1),
                (detection.x2, detection.y2),
                (detection.x1, detection.y2)
            ])

            intersection = roi["polygon"].intersection(box)
            if intersection.is_empty:
                return False

            overlap_ratio = intersection.area / box.area
            return overlap_ratio >= threshold

        except Exception as e:
            logger.error(f"Error checking box overlap: {e}")
            return False

    def get_rois_containing_point(self, x: float, y: float) -> List[int]:
        """
        Get all ROI IDs that contain a point.

        Args:
            x: X coordinate
            y: Y coordinate

        Returns:
            List of ROI IDs
        """
        point = Point(x, y)
        return [
            roi_id
            for roi_id, roi in self._rois.items()
            if roi["polygon"].contains(point)
        ]

    def get_rois_containing_detection(self, detection: DetectionBox) -> List[int]:
        """
        Get all ROI IDs that contain a detection's center.

        Args:
            detection: Detection box

        Returns:
            List of ROI IDs
        """
        return self.get_rois_containing_point(detection.center_x, detection.center_y)

    def check_detections_in_rois(
        self,
        detections: List[DetectionBox],
        class_filter: Optional[List[str]] = None
    ) -> Dict[int, List[DetectionBox]]:
        """
        Check which detections are in which ROIs.

        Args:
            detections: List of detections
            class_filter: Optional list of class names to filter

        Returns:
            Dict mapping roi_id to list of detections inside it
        """
        result: Dict[int, List[DetectionBox]] = {roi_id: [] for roi_id in self._rois}

        for detection in detections:
            if class_filter and detection.class_name not in class_filter:
                continue

            for roi_id in self._rois:
                if self.is_detection_in_roi(roi_id, detection):
                    result[roi_id].append(detection)

        return result

    def load_rois_from_json(self, json_data: str) -> int:
        """
        Load ROIs from JSON string.

        Args:
            json_data: JSON string containing ROI data

        Returns:
            Number of ROIs loaded
        """
        try:
            rois = json.loads(json_data)
            count = 0
            for roi in rois:
                points = [ROIPoint(x=p["x"], y=p["y"]) for p in roi.get("points", [])]
                self.add_roi(
                    roi_id=roi["id"],
                    points=points,
                    name=roi.get("name", ""),
                    color=roi.get("color", "#FF0000"),
                    zone_type=roi.get("zone_type", "warning")
                )
                count += 1
            return count
        except Exception as e:
            logger.error(f"Error loading ROIs from JSON: {e}")
            return 0

    def export_rois_to_json(self) -> str:
        """Export all ROIs to JSON string."""
        rois = self.get_all_rois()
        return json.dumps(rois)


# Global ROI manager instance
_roi_manager_instance: Optional[ROIManager] = None


def get_roi_manager() -> ROIManager:
    """Get or create the global ROI manager instance."""
    global _roi_manager_instance
    if _roi_manager_instance is None:
        _roi_manager_instance = ROIManager()
    return _roi_manager_instance
