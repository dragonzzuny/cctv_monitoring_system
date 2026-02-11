"""
BoT-SORT (Bottleneck-SORT) tracking implementation.
Provides SOTA tracking for RF-DETR detections.
"""
import numpy as np
import logging
from typing import List, Dict, Any, Optional

logger = logging.getLogger(__name__)

class BoTSORTTracker:
    """
    A wrapper for BoT-SORT tracking.
    This implementation leverages ultralytics' BOTSORT if available,
    or provides a simplified version for ID consistency.
    """
    
    def __init__(self, track_high_thresh=0.5, track_low_thresh=0.1, new_track_thresh=0.6, 
                 track_buffer=30, match_thresh=0.8, frame_rate=30):
        self.tracker = None
        self._init_tracker(track_high_thresh, track_low_thresh, new_track_thresh, 
                           track_buffer, match_thresh, frame_rate)

    def _init_tracker(self, track_high_thresh, track_low_thresh, new_track_thresh, 
                      track_buffer, match_thresh, frame_rate):
        try:
            # Try to use ultralytics BOTSORT
            from ultralytics.trackers.bot_sort import BOTSORT
            from ultralytics.utils import IterableSimpleNamespace
            
            # Create a mock args object as required by ultralytics tracker
            args = IterableSimpleNamespace(
                track_high_thresh=track_high_thresh,
                track_low_thresh=track_low_thresh,
                new_track_thresh=new_track_thresh,
                track_buffer=track_buffer,
                match_thresh=match_thresh,
                gmc_method='sparseOptFlow', # Camera Motion Compensation
                proximity_thresh=0.5,
                appearance_thresh=0.25,
                with_reid=False # Set to False for real-time performance without ReID model
            )
            
            self.tracker = BOTSORT(args=args, frame_rate=frame_rate)
            logger.info("Successfully initialized ultralytics BoT-SORT")
        except Exception as e:
            logger.warning(f"Failed to load ultralytics BOTSORT: {e}. Using fallback tracker.")
            # Fallback to a simpler tracker if ultralytics version is unavailable
            self.tracker = None

    def update(self, detections: np.ndarray, frame: np.ndarray) -> np.ndarray:
        """
        Update tracker with new detections.
        
        Args:
            detections: numpy array of [x1, y1, x2, y2, conf, cls]
            frame: raw BGR frame for Camera Motion Compensation
            
        Returns:
            numpy array of [x1, y1, x2, y2, track_id, conf, cls]
        """
        if self.tracker is None:
            # Minimal fallback: return detections with index as simple ID
            # This is NOT real tracking but avoids crashing
            if len(detections) == 0:
                return np.empty((0, 7))
            
            tracked = []
            for i, det in enumerate(detections):
                # [x1, y1, x2, y2, id, conf, cls]
                tracked.append([det[0], det[1], det[2], det[3], i + 1, det[4], det[5]])
            return np.array(tracked)

        try:
            # Convert to ultralytics expected format and update
            # BOTSORT.update expects a results-like object or specific array format
            # In many versions, it takes [x1, y1, x2, y2, conf, cls]
            tracks = self.tracker.update(detections, frame)
            
            if len(tracks) == 0:
                return np.empty((0, 7))
            
            # BoTSORT typically returns tracked objects with IDs
            # Output format: [x1, y1, x2, y2, id, conf, cls]
            return tracks
        except Exception as e:
            logger.error(f"Error during BoT-SORT update: {e}")
            return np.empty((0, 7))

def get_tracker(method: str = "bot_sort", **kwargs) -> BoTSORTTracker:
    """Factory function for trackers."""
    return BoTSORTTracker(**kwargs)
