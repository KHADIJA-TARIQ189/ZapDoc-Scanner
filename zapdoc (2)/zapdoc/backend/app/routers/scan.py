import json
import os
import uuid
from typing import List, Optional

import cv2
import numpy as np
from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse

from app.services import image_processing, pdf_tools

router = APIRouter(prefix="/scan", tags=["scan"])

UPLOAD_DIR = "storage/uploads"
OUTPUT_DIR = "storage/outputs"
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)


def _read_image(upload: UploadFile) -> np.ndarray:
    data = upload.file.read()
    arr = np.frombuffer(data, np.uint8)
    image = cv2.imdecode(arr, cv2.IMREAD_COLOR)
    if image is None:
        raise HTTPException(400, "Could not decode image")
    return image


@router.post("/detect")
async def detect_edges(file: UploadFile = File(...)):
    """Upload a raw photo, get back the 4 detected document corners."""
    image = _read_image(file)
    corners = image_processing.detect_document_edges(image)
    h, w = image.shape[:2]
    return {"corners": corners, "image_width": w, "image_height": h}


@router.post("/process")
async def process_scan(
    file: UploadFile = File(...),
    corners: Optional[str] = Form(None),  # JSON string: [[x,y],[x,y],[x,y],[x,y]]
    mode: str = Form("enhance"),          # color | gray | bw | enhance
):
    """Crop (perspective-correct) + filter a single page. Returns the processed JPG."""
    image = _read_image(file)
    parsed_corners = json.loads(corners) if corners else None
    result = image_processing.process_document(image, parsed_corners, mode)

    out_name = f"{uuid.uuid4().hex}.jpg"
    out_path = os.path.join(OUTPUT_DIR, out_name)
    cv2.imwrite(out_path, result, [cv2.IMWRITE_JPEG_QUALITY, 92])
    return FileResponse(out_path, media_type="image/jpeg", filename=out_name)


@router.post("/create-pdf")
async def create_pdf(files: List[UploadFile] = File(...)):
    """Upload the already-processed page images (in order) -> get back one PDF."""
    saved_paths = []
    for f in files:
        temp_path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4().hex}.jpg")
        with open(temp_path, "wb") as out:
            out.write(await f.read())
        saved_paths.append(temp_path)

    out_name = f"{uuid.uuid4().hex}.pdf"
    out_path = os.path.join(OUTPUT_DIR, out_name)
    pdf_tools.images_to_pdf(saved_paths, out_path)

    return FileResponse(out_path, media_type="application/pdf", filename="scan.pdf")
