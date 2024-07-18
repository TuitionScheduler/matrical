from dataclasses import dataclass
from typing import Dict, List


@dataclass(slots=True)
class RequisitesAnalysisResult:
    is_eligible: bool
    has_warnings: bool
    missing_requirements: List[Dict]
