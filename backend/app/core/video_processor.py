"""
Video processing module for handling video streams.
"""
import asyncio
import base64
import logging
import time
from pathlib import Path
from typing import Optional, Callable, Dict, Any, AsyncGenerator
import cv2
import numpy as np
from PIL import ImageFont, ImageDraw, Image

from app.config import settings
from app.core.detection import BaseDetector, get_detector
from app.schemas.detection import DetectionResult, StreamFrame

logger = logging.getLogger(__name__)

# Load Korean-compatible font (Windows default)
_korean_font_cache: Dict[int, ImageFont.FreeTypeFont] = {}

def _get_korean_font(size: int = 20) -> ImageFont.FreeTypeFont:
    """Get cached Korean font instance."""
    if size not in _korean_font_cache:
        font_paths = [
            "C:/Windows/Fonts/malgun.ttf",      # Malgun Gothic
            "C:/Windows/Fonts/gulim.ttc",        # Gulim
            "C:/Windows/Fonts/batang.ttc",       # Batang
        ]
        for fp in font_paths:
            try:
                _korean_font_cache[size] = ImageFont.truetype(fp, size)
                break
            except (IOError, OSError):
                continue
        if size not in _korean_font_cache:
            _korean_font_cache[size] = ImageFont.load_default()
    return _korean_font_cache[size]


def put_korean_text(
    img: np.ndarray,
    text: str,
    position: tuple,
    font_size: int = 20,
    color: tuple = (255, 255, 255),
    bg_color: tuple = None
) -> np.ndarray:
    """Draw Korean text on OpenCV image using PIL."""
    img_pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    draw = ImageDraw.Draw(img_pil)
    font = _get_korean_font(font_size)

    x, y = position
    bbox = draw.textbbox((x, y), text, font=font)

    if bg_color is not None:
        # BGR to RGB for PIL
        bg_rgb = (bg_color[2], bg_color[1], bg_color[0])
        padding = 4
        draw.rectangle(
            [bbox[0] - padding, bbox[1] - padding, bbox[2] + padding, bbox[3] + padding],
            fill=bg_rgb
        )

    # BGR to RGB for PIL
    color_rgb = (color[2], color[1], color[0])
    draw.text((x, y), text, font=font, fill=color_rgb)

    return cv2.cvtColor(np.array(img_pil), cv2.COLOR_RGB2BGR)


class VideoProcessor:
    """Handles video capture and processing for a single camera."""

    def __init__(self, camera_id: int, source: str, source_type: str = "file"):
        """
        Initialize video processor.

        Args:
            camera_id: Camera ID from database
            source: Video file path or RTSP URL
            source_type: "file" or "rtsp"
        """
        self.camera_id = camera_id
        self.source = source
        self.source_type = source_type
        self.cap: Optional[cv2.VideoCapture] = None
        self.detector: Optional[BaseDetector] = None
        self.is_running = False
        self.frame_count = 0
        self.fps = settings.VIDEO_FPS
        self.target_fps = settings.VIDEO_FPS

        # Video properties
        self.width = 0
        self.height = 0
        self.original_fps = 0
        self.total_frames = 0

        # Current frame storage for snapshot access
        self._current_raw_frame: Optional[np.ndarray] = None

    def open(self) -> bool:
        """
        Open video source or reuse existing session.

        Returns:
            True if opened successfully
        """
        if self.cap is not None and self.cap.isOpened():
            return True

        try:
            if self.source_type == "file":
                self.cap = cv2.VideoCapture(self.source, cv2.CAP_FFMPEG)
            else:
                self.cap = cv2.VideoCapture(self.source)

            if not self.cap.isOpened():
                logger.error(f"Failed to open video source: {self.source}")
                return False

            # Get video properties
            self.width = int(self.cap.get(cv2.CAP_PROP_FRAME_WIDTH))
            self.height = int(self.cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
            self.original_fps = self.cap.get(cv2.CAP_PROP_FPS)
            self.total_frames = int(self.cap.get(cv2.CAP_PROP_FRAME_COUNT))

            # Fallback for FPS
            if self.original_fps is None or self.original_fps <= 0:
                self.original_fps = 30.0

            # If properties are 0, try reading a frame to populate them (some backends need this)
            if self.width <= 0 or self.height <= 0:
                ret, frame = self.cap.read()
                if ret:
                    self.height, self.width = frame.shape[:2]
                    # Reset to beginning
                    self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                else:
                    logger.warning(f"Could not read initial frame to determine video properties for {self.source}")

            # Ensure target_fps is set based on actual original_fps
            self.target_fps = min(self.original_fps, settings.VIDEO_FPS)
            
            logger.info(
                f"Video opened: {self.width}x{self.height} @ {self.original_fps}fps, "
                f"total frames: {self.total_frames}"
            )
            return True

        except Exception as e:
            logger.error(f"Error opening video source: {e}")
            return False

    def close(self):
        """Close video source."""
        self.is_running = False
        if self.cap is not None:
            self.cap.release()
            self.cap = None

    def read_frame(self) -> Optional[np.ndarray]:
        """
        Read a single frame.

        Returns:
            Frame as numpy array or None if failed
        """
        if self.cap is None or not self.cap.isOpened():
            return None

        ret, frame = self.cap.read()
        if not ret:
            # For file source, loop back to beginning
            if self.source_type == "file":
                self.cap.set(cv2.CAP_PROP_POS_FRAMES, 0)
                ret, frame = self.cap.read()
                if not ret:
                    return None
            else:
                return None

        self.frame_count = int(self.cap.get(cv2.CAP_PROP_POS_FRAMES))
        self._current_raw_frame = frame.copy()  # Store raw frame for snapshots
        return frame

    def get_timestamp(self) -> float:
        """Get current video timestamp in seconds."""
        if self.cap is None:
            return 0.0
        return self.cap.get(cv2.CAP_PROP_POS_MSEC) / 1000.0

    def get_current_frame(self) -> Optional[np.ndarray]:
        """Get the current raw frame for snapshot purposes."""
        return self._current_raw_frame.copy() if self._current_raw_frame is not None else None

    @property
    def total_duration_ms(self) -> float:
        """Get total video duration in milliseconds."""
        if self.original_fps == 0:
            return 0.0
        return (self.total_frames / self.original_fps) * 1000.0

    def seek(self, position_ms: int):
        """
        Seek to position in video with high reliability.
        """
        if self.cap is not None and self.source_type == "file":
            # 1. Clear current frame to prevent stale display
            self._current_raw_frame = None
            
            # 2. Calculate target frame index
            target_frame = int((position_ms / 1000.0) * self.original_fps)
            target_frame = max(0, min(target_frame, self.total_frames - 1))
            
            # 3. Apply seek
            # Prioritize POS_FRAMES as it's generally more accurate for indexed files
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, float(target_frame))
            
            # Force codec buffer update
            for _ in range(5):
                self.cap.grab()

    def seek_frame(self, frame_number: int):
        """
        Seek to specific frame.

        Args:
            frame_number: Frame number to seek to
        """
        if self.cap is not None and self.source_type == "file":
            self.cap.set(cv2.CAP_PROP_POS_FRAMES, frame_number)

    @staticmethod
    def encode_frame(frame: np.ndarray, quality: int = 80) -> str:
        """
        Encode frame to base64 JPEG.

        Args:
            frame: BGR frame
            quality: JPEG quality (0-100)

        Returns:
            Base64 encoded string
        """
        encode_params = [cv2.IMWRITE_JPEG_QUALITY, quality]
        _, buffer = cv2.imencode('.jpg', frame, encode_params)
        return base64.b64encode(buffer).decode('utf-8')

    @staticmethod
    def draw_detections(
        frame: np.ndarray,
        detection: DetectionResult,
        draw_labels: bool = True
    ) -> np.ndarray:
        """
        Draw detection boxes on frame.

        Args:
            frame: BGR frame
            detection: Detection result
            draw_labels: Whether to draw class labels

        Returns:
            Frame with drawn detections
        """
        frame_copy = frame.copy()

        # Color mapping for different classes (11 classes)
        colors = {
            "helmet": (31, 119, 180),      # Blue
            "gloves": (255, 127, 14),      # Orange
            "vest": (44, 160, 44),        # Green
            "boots": (214, 39, 40),        # Red
            "goggles": (148, 103, 189),    # Purple
            "mask": (140, 86, 75),         # Brown
            "person": (227, 119, 194),     # Pink
            "machinery": (127, 127, 127),  # Gray
            "vehicle": (188, 189, 34),     # Olive
            "safety_cone": (23, 190, 207), # Cyan
            "fire_extinguisher": (0, 0, 255), # Pure Red
        }

        # Korean label mapping
        korean_labels = {
            "helmet": "안전모",
            "gloves": "장갑",
            "vest": "조끼",
            "boots": "안전화",
            "goggles": "보안경",
            "mask": "마스크",
            "person": "작업자",
            "machinery": "기계",
            "vehicle": "차량",
            "safety_cone": "라바콘",
            "fire_extinguisher": "소화기",
        }

        for det in detection.detections:
            x1, y1, x2, y2 = int(det.x1), int(det.y1), int(det.x2), int(det.y2)
            color = colors.get(det.class_name, (255, 255, 0))

            # Draw bounding box
            cv2.rectangle(frame_copy, (x1, y1), (x2, y2), color, 3) # Thicker box

            if draw_labels:
                # Draw label background
                label_text = f"{det.class_name}: {det.confidence:.2f}"
                font_scale = 0.8
                thickness = 2
                (label_w, label_h), baseline = cv2.getTextSize(
                    label_text, cv2.FONT_HERSHEY_SIMPLEX, font_scale, thickness
                )

                cv2.rectangle(
                    frame_copy,
                    (x1, y1 - label_h - baseline - 5),
                    (x1 + label_w, y1),
                    color,
                    -1
                )

                # Draw label text
                cv2.putText(
                    frame_copy,
                    label_text,
                    (x1, y1 - baseline - 2),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    font_scale,
                    (255, 255, 255),
                    thickness
                )

        return frame_copy

    @staticmethod
    def draw_rois(
        frame: np.ndarray,
        rois: list,
        alpha: float = 0.3
    ) -> np.ndarray:
        """
        Draw ROI polygons on frame with semi-transparent fill.

        Args:
            frame: BGR frame
            rois: List of ROI data with normalized points (0-1) and color
            alpha: Transparency for filled region

        Returns:
            Frame with drawn ROIs
        """
        if not rois:
            return frame

        h, w = frame.shape[:2]
        frame_copy = frame.copy()
        overlay = frame.copy()

        for roi in rois:
            points = roi.get("points", [])
            color_hex = roi.get("color", "#FF0000")
            name = roi.get("name", "")
            zone_type = roi.get("zone_type", "warning")

            # Convert hex color to BGR
            color_hex = color_hex.lstrip('#')
            r, g, b = tuple(int(color_hex[i:i+2], 16) for i in (0, 2, 4))
            color = (b, g, r)  # BGR

            if len(points) >= 3:
                # Scale normalized (0-1) coordinates to pixel coordinates
                pts = np.array([
                    [int(p["x"] * w), int(p["y"] * h)] for p in points
                ], np.int32)
                pts = pts.reshape((-1, 1, 2))

                # Draw filled polygon on overlay
                cv2.fillPoly(overlay, [pts], color)

                # Draw polygon outline (slightly thicker)
                cv2.polylines(frame_copy, [pts], True, color, 2)

                # Draw ROI name label (Korean-compatible)
                if name:
                    min_x = min(p["x"] for p in points)
                    min_y = min(p["y"] for p in points)
                    label_x = int(min_x * w)
                    label_y = int(min_y * h) - 30

                    frame_copy = put_korean_text(
                        frame_copy, name,
                        (label_x, label_y),
                        font_size=18,
                        color=(255, 255, 255),
                        bg_color=color
                    )

        # Blend overlay with frame
        cv2.addWeighted(overlay, alpha, frame_copy, 1 - alpha, 0, frame_copy)

        return frame_copy

    async def stream_frames(
        self,
        with_detection: bool = True,
        callback: Optional[Callable[[StreamFrame], None]] = None,
        rois_provider: Optional[Callable[[], list]] = None
    ) -> AsyncGenerator[StreamFrame, None]:
        """
        Async generator for streaming frames.

        Args:
            with_detection: Whether to run detection
            callback: Optional callback for each frame

        Yields:
            StreamFrame objects
        """
        if not self.open():
            return

        if with_detection:
            self.detector = get_detector()
            if not self.detector.is_loaded:
                self.detector.load_model()

        self.is_running = True
        frame_interval = 1.0 / self.target_fps

        try:
            while self.is_running:
                loop_start = time.time()

                frame = self.read_frame()
                if frame is None:
                    break
                
                # Check current time vs video time to decide if we should skip detection
                # to maintain real-time sync.
                current_loop_time = time.time()
                time_behind = (current_loop_time - loop_start)
                
                # If we're taking too long (e.g. more than 1.5x frame interval),
                # we might want to skip detection and just show the frame,
                # or skip frames entirely. For now, we ensure we don't fall behind.
                
                timestamp = self.get_timestamp()
                detection = None

                if with_detection and self.detector:
                    # Run inference on raw frame (before any overlay)
                    detection = self.detector.detect(
                        frame,
                        frame_number=self.frame_count,
                        timestamp=timestamp
                    )

                # Draw ROI overlays first (semi-transparent background)
                if rois_provider:
                    current_rois = rois_provider()
                    if current_rois:
                        frame = self.draw_rois(frame, current_rois)

                # Draw detection boxes on top of ROI overlays
                if detection:
                    frame = self.draw_detections(frame, detection)

                # Encode frame
                frame_base64 = self.encode_frame(frame, settings.VIDEO_QUALITY)

                stream_frame = StreamFrame(
                    camera_id=self.camera_id,
                    frame_base64=frame_base64,
                    current_ms=timestamp * 1000.0,
                    total_ms=self.total_duration_ms,
                    detection=detection,
                    events=[],
                    raw_frame=frame
                )

                if callback:
                    callback(stream_frame)

                yield stream_frame

                # Maintain target FPS and implement frame skipping
                elapsed = time.time() - loop_start
                sleep_time = frame_interval - elapsed
                
                if sleep_time > 0:
                    await asyncio.sleep(sleep_time)
                elif abs(sleep_time) > frame_interval:
                    # We are falling behind, skip frames to catch up
                    frames_to_skip = int(abs(sleep_time) / frame_interval)
                    if self.cap is not None:
                        for _ in range(min(frames_to_skip, 5)): # Cap skip to 5 frames
                            self.cap.grab()
                        logger.debug(f"Skipped {frames_to_skip} frames to maintain real-time sync")

        finally:
            # Do NOT call self.close() here as it releases the video source
            # The owner of VideoProcessor is responsible for closing it when done
            self.is_running = False

    def get_snapshot(self, with_detection: bool = False, position_ms: Optional[float] = None) -> Optional[Dict[str, Any]]:
        """
        Capture a single snapshot.

        Args:
            with_detection: Whether to include detection
            position_ms: Optional position in milliseconds to seek to

        Returns:
            Dict with frame_base64 and optional detection
        """
        if not self.open():
            return None

        # Seek if requested
        if position_ms is not None:
            self.seek(int(position_ms))
        elif self.source_type == "file":
            # For files, default to seeking 5s in to skip potentially black intros
            # if no specific position is provided.
            self.seek(5000)

        frame = self.read_frame()
        if frame is None:
            self.close()
            return None

        timestamp = self.get_timestamp()
        detection = None

        if with_detection:
            detector = get_detector()
            if not detector.is_loaded:
                detector.load_model()
            detection = detector.detect(frame, self.frame_count, timestamp)
            frame = self.draw_detections(frame, detection)

        frame_base64 = self.encode_frame(frame, settings.VIDEO_QUALITY)
        self.close()

        return {
            "camera_id": self.camera_id,
            "frame_base64": frame_base64,
            "detection": detection.model_dump() if detection else None,
            "timestamp": timestamp
        }
