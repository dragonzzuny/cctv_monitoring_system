import time
import sys
import os
from unittest.mock import MagicMock

# Add backend to path
sys.path.append(os.path.join(os.getcwd(), 'backend'))

from app.core.rule_engine import RuleEngine, EventType
from app.schemas.detection import DetectionBox, DetectionResult
from app.core.roi_manager import ROIManager, Point as ROIPoint

def test_stay_time_calculation():
    # Setup
    roi_manager = ROIManager()
    # Add a mock ROI (Warning Zone)
    roi_manager.add_roi(
        roi_id=1,
        points=[
            ROIPoint(x=0, y=0),
            ROIPoint(x=100, y=0),
            ROIPoint(x=100, y=100),
            ROIPoint(x=0, y=100)
        ],
        name="Warning Zone",
        zone_type="warning"
    )
    
    # Mock ROI manager is_detection_in_roi
    roi_manager.is_detection_in_roi = MagicMock(return_value=True)
    
    rule_engine = RuleEngine(roi_manager)
    
    # Frame 1 at T=0
    current_time = 1000.0
    person1 = DetectionBox(
        class_id=0, class_name="person", confidence=0.9,
        x1=10, y1=10, x2=20, y2=20,
        center_x=15, center_y=15,
        track_id=1
    )
    
    events = rule_engine.evaluate(
        DetectionResult(
            frame_number=1, timestamp=current_time,
            detections=[person1],
            persons_count=1
        ),
        camera_id=1,
        active_roi_ids=[1],
        current_time=current_time
    )
    
    # Frame 2 at T=5.5
    current_time = 1005.5
    events = rule_engine.evaluate(
        DetectionResult(
            frame_number=2, timestamp=current_time,
            detections=[person1],
            persons_count=1
        ),
        camera_id=1,
        active_roi_ids=[1],
        current_time=current_time
    )
    
    # Verify stay time
    metrics = rule_engine.get_roi_metrics([1])
    stay_time = metrics[1]['people'][0]['stay_time']
    print(f"Calculated Stay Time: {stay_time}s")
    assert stay_time == 5.5
    print("Test Passed: Stay time correctly calculated.")

if __name__ == "__main__":
    test_stay_time_calculation()
