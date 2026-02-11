from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.database import get_db
from app.db.models import SafetyRegulation as SafetyRegulationModel
from app.schemas.regulations import SafetyRegulation

router = APIRouter(prefix="/regulations", tags=["regulations"])

@router.get("/", response_model=List[SafetyRegulation])
async def get_regulations(db: AsyncSession = Depends(get_db)):
    """Get all safety regulations."""
    result = await db.execute(select(SafetyRegulationModel))
    return result.scalars().all()

@router.get("/{category}", response_model=List[SafetyRegulation])
async def get_regulations_by_category(category: str, db: AsyncSession = Depends(get_db)):
    """Get safety regulations by category."""
    result = await db.execute(
        select(SafetyRegulationModel).where(SafetyRegulationModel.category == category)
    )
    return result.scalars().all()
