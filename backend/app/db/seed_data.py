import asyncio
import logging
from datetime import datetime
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select

from app.db.database import AsyncSessionLocal, engine, Base
from app.db.models import SafetyRegulation

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

REGULATIONS = [
    {
        "category": "산업안전보건법",
        "title": "제38조(안전조치)",
        "content": "사업주는 추락, 붕괴, 전기, 기계·기구 등에 의한 위험을 예방하기 위하여 필요한 조치를 하여야 한다. 특히 고소 작업 시 안전 난간 설치 및 안전대 착용 의무화가 포함된다."
    },
    {
        "category": "산업안전보건법",
        "title": "제6조(근로자의 의무)",
        "content": "근로자는 이 법과 이 법에 따른 명령으로 정하는 기준 등 산업재해 예방에 필요한 사항을 지켜야 하며, 사업주 또는 관련 기관이 실시하는 산업재해 예방에 관한 조치에 따라야 한다."
    },
    {
        "category": "중대재해처벌법",
        "title": "제4조(사업주 등의 안전 및 보건 확보의무)",
        "content": "사업주 또는 경영책임자 등은 실질적으로 지배·운영·관리하는 사업장에서 종사자의 안전·보건상 유해 또는 위험을 방지하기 위하여 그 사업의 특성 및 규모 등을 고려하여 안전보건관리체계의 구축 및 그 이행에 관한 조치를 취해야 한다."
    },
    {
        "category": "안전수칙",
        "title": "개인보호구 착용",
        "content": "현장 내 모든 근로자는 안전모, 안전화 등 필수 보호구를 상시 착용해야 한다. 특히 낙하물 위험이 있는 구역에서는 턱끈을 반드시 매어야 한다."
    },
    {
        "category": "안전수칙",
        "title": "TBM(Tool Box Meeting) 실시",
        "content": "작업 개시 전 당해 작업의 위험 요인을 발굴하고 공유하며, 안전 대책을 확인하는 단기 안전 교육 세션을 반드시 실시해야 한다."
    }
]

async def seed_data():
    async with engine.begin() as conn:
        # Create tables if not exist
        await conn.run_sync(Base.metadata.create_all)
    
    async with AsyncSessionLocal() as session:
        # Check if regulations already exist
        result = await session.execute(select(SafetyRegulation))
        if result.first():
            logger.info("Safety regulations already exist, skipping seed.")
            return

        logger.info("Seeding safety regulations...")
        for reg in REGULATIONS:
            db_reg = SafetyRegulation(
                category=reg["category"],
                title=reg["title"],
                content=reg["content"]
            )
            session.add(db_reg)
        
        await session.commit()
        logger.info("Seeding completed successfully.")

if __name__ == "__main__":
    asyncio.run(seed_data())
