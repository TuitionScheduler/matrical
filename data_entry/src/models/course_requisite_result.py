from dataclasses import dataclass


@dataclass(slots=True)
class RequisitesAnalysisResult:
    is_eligible: bool
    missing_prerequisites: str
    missing_corequisites: str
