from app.api.routes.cameras import router as cameras_router
from app.api.routes.rois import router as rois_router
from app.api.routes.events import router as events_router
from app.api.routes.checklists import router as checklists_router
from app.api.routes.stream import router as stream_router
from app.api.routes.regulations import router as regulations_router

__all__ = [
    "cameras_router",
    "rois_router",
    "events_router",
    "checklists_router",
    "stream_router",
    "regulations_router",
]
