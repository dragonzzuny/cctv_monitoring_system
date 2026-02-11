"""
SQLAlchemy database models.
"""
from datetime import datetime, timezone
from typing import Optional, List
from sqlalchemy import String, Integer, Float, Boolean, DateTime, ForeignKey, Text, JSON, Index
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.database import Base


class Camera(Base):
    """Camera/video source configuration."""
    __tablename__ = "cameras"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    source: Mapped[str] = mapped_column(String(500), nullable=False)  # File path or RTSP URL
    source_type: Mapped[str] = mapped_column(String(20), default="file")  # "file" or "rtsp"
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    rois: Mapped[List["ROI"]] = relationship("ROI", back_populates="camera", cascade="all, delete-orphan")
    events: Mapped[List["Event"]] = relationship("Event", back_populates="camera", cascade="all, delete-orphan")
    checklists: Mapped[List["Checklist"]] = relationship("Checklist", back_populates="camera", cascade="all, delete-orphan")


class ROI(Base):
    """Region of Interest for detection zones."""
    __tablename__ = "rois"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    camera_id: Mapped[int] = mapped_column(Integer, ForeignKey("cameras.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    points: Mapped[str] = mapped_column(Text, nullable=False)  # JSON array of [x, y] points
    color: Mapped[str] = mapped_column(String(20), default="#FF0000")
    zone_type: Mapped[str] = mapped_column(String(20), default="warning")  # "warning" or "danger"
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    camera: Mapped["Camera"] = relationship("Camera", back_populates="rois")


class Event(Base):
    """Safety events/alarms."""
    __tablename__ = "events"
    __table_args__ = (
        Index("ix_events_camera_created", "camera_id", "created_at"),
        Index("ix_events_acknowledged", "is_acknowledged"),
        Index("ix_events_severity", "severity"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    camera_id: Mapped[int] = mapped_column(Integer, ForeignKey("cameras.id"), nullable=False)
    event_type: Mapped[str] = mapped_column(String(50), nullable=False)
    severity: Mapped[str] = mapped_column(String(20), nullable=False)  # INFO, WARNING, CRITICAL
    message: Mapped[str] = mapped_column(String(500), nullable=False)
    snapshot_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    roi_id: Mapped[Optional[int]] = mapped_column(Integer, ForeignKey("rois.id", ondelete="SET NULL"), nullable=True)
    detection_data: Mapped[Optional[str]] = mapped_column(Text, nullable=True)  # JSON detection details
    is_acknowledged: Mapped[bool] = mapped_column(Boolean, default=False)
    acknowledged_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    # Relationships
    camera: Mapped["Camera"] = relationship("Camera", back_populates="events")


class Checklist(Base):
    """Safety checklist for camera monitoring."""
    __tablename__ = "checklists"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    camera_id: Mapped[int] = mapped_column(Integer, ForeignKey("cameras.id"), nullable=False)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc), onupdate=lambda: datetime.now(timezone.utc))

    # Relationships
    camera: Mapped["Camera"] = relationship("Camera", back_populates="checklists")
    items: Mapped[List["ChecklistItem"]] = relationship("ChecklistItem", back_populates="checklist", cascade="all, delete-orphan")


class ChecklistItem(Base):
    """Individual checklist items."""
    __tablename__ = "checklist_items"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    checklist_id: Mapped[int] = mapped_column(Integer, ForeignKey("checklists.id"), nullable=False)
    item_type: Mapped[str] = mapped_column(String(50), nullable=False)  # PPE_HELMET, PPE_MASK, FIRE_EXTINGUISHER
    description: Mapped[str] = mapped_column(String(200), nullable=False)
    is_checked: Mapped[bool] = mapped_column(Boolean, default=False)
    auto_checked: Mapped[bool] = mapped_column(Boolean, default=False)  # Automatically checked by system
    checked_at: Mapped[Optional[datetime]] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    # Relationships
    checklist: Mapped["Checklist"] = relationship("Checklist", back_populates="items")


class SafetyRegulation(Base):
    """Industrial safety laws and regulations."""
    __tablename__ = "safety_regulations"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    category: Mapped[str] = mapped_column(String(100), nullable=False)  # e.g., "산업안전보건법"
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
