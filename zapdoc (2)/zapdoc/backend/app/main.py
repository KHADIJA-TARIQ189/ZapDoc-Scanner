from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import pdf, scan

app = FastAPI(
    title="ZapDoc API",
    description="Backend for the ZapDoc scanning + PDF-tools app (CamScanner + iLovePDF style).",
    version="1.0.0",
)

# Wide-open CORS for development; restrict this to your app's domain in production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(scan.router)
app.include_router(pdf.router)


@app.get("/")
def health_check():
    return {"status": "ok", "service": "zapdoc-backend"}
