from fastapi import FastAPI, HTTPException
from google.cloud import firestore

app = FastAPI()

# Initialize Firestore client with credentials
db = firestore.AsyncClient.from_service_account_json("credentials.json")


# Define a route to fetch data from Firestore
@app.get("/{document_id}")
async def get_data_from_firestore(document_id: str):
    try:
        doc_ref = db.collection("DepartmentCourses").document(
            document_id
        )  # Update with your collection name
        doc = await doc_ref.get()
        if not doc.exists:
            raise HTTPException(status_code=404, detail="Document not found")
        return doc.to_dict()
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
