import firebase_admin
from firebase_admin import credentials
from firebase_admin import firestore

cred = credentials.Certificate("credentials.json")
app = firebase_admin.initialize_app(cred)
db = firestore.client()
doc_ref = db.collection("DepartmentCourses")

doc_ref.document("TEST:Spring:2023").set(
    {
        "department": "TEST",
        "term": "Spring",
        "year": 2023,
        "courses": {
            "TEST0001": {
                "courseCode": "TEST0001",
                "courseName": "Conflicting Course",
                "credits": 0,
                "department": "TEST",
                "term": "Spring",
                "year": 2023,
                "division": "LowerDivision",
                "hasIntegratedLab": False,
                "prerequisites": "",
                "corequisites": "",
                "sections": [
                    {
                        "sectionCode": str(i).zfill(3),
                        "meetings": ["12:00 am - 11:59 pm LMWJV"],
                        "capacity": 0,
                        "usage": 0,
                        "modality": "",
                        "misc": "",
                        "professors": [{"name": "Nadie", "url": ""}],
                        "reserved": False,
                    }
                    for i in range(1, 100 + 1)
                ],
            }
        },
    }
)
