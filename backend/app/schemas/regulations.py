from datetime import datetime
from pydantic import BaseModel, ConfigDict

class SafetyRegulationBase(BaseModel):
    category: str
    title: str
    content: str

class SafetyRegulationCreate(SafetyRegulationBase):
    pass

class SafetyRegulation(SafetyRegulationBase):
    model_config = ConfigDict(from_attributes=True)
    
    id: int
    created_at: datetime
