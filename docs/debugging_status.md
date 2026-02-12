# Debugging Status

## Completed Fixes

### 1. Camera DELETE HTTP 500
- **Symptom**: DELETE /api/cameras/{id} returned 500
- **Root Cause**: Async SQLAlchemy cannot lazy-load cascade relationships (rois, events, checklists). Also, `rois.zone_type` column missing from DB.
- **Fix**:
  - `cameras.py`: Added `selectinload` for eager relationship loading before delete
  - DB migration: `ALTER TABLE rois ADD COLUMN zone_type VARCHAR(20) DEFAULT 'warning'`
- **Files**: `backend/app/api/routes/cameras.py`, `backend/safety_monitor.db`
- **Status**: Verified (HTTP 204)

### 2. Camera Switching Screen Freeze
- **Symptom**: Switching from camera A to camera B freezes the display on camera A's last frame
- **Root Cause**: `stream_provider.connect()` preserved old state (`isPlaying: true`, `currentFrame: old_frame`) and never sent "start" command to the new backend WebSocket
- **Fix**:
  - `stream_provider.dart`: Full state reset with `StreamState()` on new connection
  - Auto-send "start" command after WebSocket connects
  - Remove `connect()` call from dropdown handler (let VideoPlayerWidget manage connections)
- **Files**: `frontend/lib/providers/stream_provider.dart`, `frontend/lib/screens/main_control_screen.dart`

### 3. WebSocket Race Condition
- **Symptom**: Old WebSocket's `onDone` callback could close the newly created StreamController
- **Root Cause**: Closure captured `_frameController` instance variable instead of local reference
- **Fix**: Capture `final controller = _frameController!` before setting up listener, use `controller.isClosed` check
- **Files**: `frontend/lib/services/websocket_service.dart`

### 4. Double-Connect Race
- **Symptom**: Dropdown handler and VideoPlayerWidget both called `connect()` simultaneously
- **Root Cause**: Two code paths for the same action
- **Fix**: Removed `connect()` from dropdown `onChanged`, let VideoPlayerWidget detect camera changes via `_connectedCameraId` tracking
- **Files**: `frontend/lib/screens/main_control_screen.dart`, `frontend/lib/widgets/video_player_widget.dart`

### 5. Double-Commit in get_db
- **Symptom**: Route handlers call `await db.commit()` explicitly, then `get_db()` also calls `await session.commit()` after yield
- **Fix**: Removed auto-commit from `get_db()`, route handlers manage their own commits
- **Files**: `backend/app/db/database.py`

### 6. Debug Artifacts Cleanup
- Removed `seek_debug.log` file write from `video_processor.py` seek method
- Removed all `print()` statements from frontend and backend
- **Files**: `backend/app/core/video_processor.py`

## Architecture Notes

### Streaming Pipeline
```
[Frontend Dropdown] -> selectedCameraProvider -> [VideoPlayerWidget detects change]
    -> streamProvider.connect(cameraId)
    -> WebSocketService.connectToStream() -> ws://localhost:8001/ws/stream/{id}
    -> Backend creates VideoProcessor, waits for "start" command
    -> streamProvider.startStream() sends {"action": "start"}
    -> Backend streams frames via WebSocket JSON
    -> StreamFrame.fromJson() -> state update -> Image.memory() display
```

### Key Design Decisions
- VideoPlayerWidget is the single connection manager (not the dropdown)
- Auto-start streaming on camera connect (CCTV monitoring default behavior)
- Full state reset on camera switch (prevents stale frame display)
- Local variable capture in WebSocket closures (prevents race conditions)
- Eager relationship loading for cascade deletes in async SQLAlchemy
