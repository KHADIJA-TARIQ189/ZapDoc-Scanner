import os
import uuid
from typing import List, Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, PlainTextResponse

from app.services import pdf_tools

router = APIRouter(prefix="/pdf", tags=["pdf"])

UPLOAD_DIR = "storage/uploads"
OUTPUT_DIR = "storage/outputs"
os.makedirs(UPLOAD_DIR, exist_ok=True)
os.makedirs(OUTPUT_DIR, exist_ok=True)


async def _save_upload(f: UploadFile) -> str:
    ext = os.path.splitext(f.filename or "file.pdf")[1] or ".pdf"
    path = os.path.join(UPLOAD_DIR, f"{uuid.uuid4().hex}{ext}")
    with open(path, "wb") as out:
        out.write(await f.read())
    return path


@router.post("/merge")
async def merge(files: List[UploadFile] = File(...)):
    if len(files) < 2:
        raise HTTPException(400, "Upload at least 2 PDFs to merge")
    paths = [await _save_upload(f) for f in files]
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    pdf_tools.merge_pdfs(paths, out_path)
    return FileResponse(out_path, media_type="application/pdf", filename="merged.pdf")


@router.post("/split")
async def split(
    file: UploadFile = File(...),
    ranges: Optional[str] = Form(None),  # e.g. "1-2,3-5" ; blank = one PDF per page
):
    path = await _save_upload(file)
    parsed_ranges = []
    if ranges:
        for chunk in ranges.split(","):
            chunk = chunk.strip()
            if "-" in chunk:
                start, end = chunk.split("-")
                parsed_ranges.append((int(start), int(end)))
            elif chunk:
                parsed_ranges.append((int(chunk), int(chunk)))

    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.zip")
    pdf_tools.split_pdf(path, parsed_ranges, out_path)
    return FileResponse(out_path, media_type="application/zip", filename="split.zip")


@router.post("/compress")
async def compress(file: UploadFile = File(...), quality: int = Form(60)):
    path = await _save_upload(file)
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    pdf_tools.compress_pdf(path, out_path, quality=quality)
    return FileResponse(out_path, media_type="application/pdf", filename="compressed.pdf")


@router.post("/rotate")
async def rotate(
    file: UploadFile = File(...),
    degrees: int = Form(90),
    pages: Optional[str] = Form(None),  # comma separated 1-indexed page numbers, blank = all
):
    path = await _save_upload(file)
    page_list = [int(p) for p in pages.split(",")] if pages else None
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    pdf_tools.rotate_pdf(path, out_path, degrees=degrees, pages=page_list)
    return FileResponse(out_path, media_type="application/pdf", filename="rotated.pdf")


@router.post("/watermark")
async def watermark(
    file: UploadFile = File(...),
    text: str = Form(...),
    opacity: float = Form(0.3),
):
    path = await _save_upload(file)
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    pdf_tools.watermark_pdf(path, out_path, text=text, opacity=opacity)
    return FileResponse(out_path, media_type="application/pdf", filename="watermarked.pdf")


@router.post("/protect")
async def protect(file: UploadFile = File(...), password: str = Form(...)):
    path = await _save_upload(file)
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    pdf_tools.protect_pdf(path, out_path, password=password)
    return FileResponse(out_path, media_type="application/pdf", filename="protected.pdf")


@router.post("/unlock")
async def unlock(file: UploadFile = File(...), password: str = Form(...)):
    path = await _save_upload(file)
    out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
    try:
        pdf_tools.unlock_pdf(path, out_path, password=password)
    except Exception:
        raise HTTPException(400, "Incorrect password or unsupported encryption")
    return FileResponse(out_path, media_type="application/pdf", filename="unlocked.pdf")


@router.post("/ocr")
async def ocr(
    file: UploadFile = File(...),
    lang: str = Form("eng"),
    output_type: str = Form("text"),  # "text" | "searchable_pdf"
):
    path = await _save_upload(file)
    if output_type == "searchable_pdf":
        out_path = os.path.join(OUTPUT_DIR, f"{uuid.uuid4().hex}.pdf")
        pdf_tools.ocr_searchable_pdf(path, out_path, lang=lang)
        return FileResponse(out_path, media_type="application/pdf", filename="searchable.pdf")

    text = pdf_tools.ocr_extract_text(path, lang=lang)
    return PlainTextResponse(text)


@router.post("/to-images")
async def to_images(file: UploadFile = File(...), dpi: int = Form(100)):
    path = await _save_upload(file)
    out_dir = os.path.join(OUTPUT_DIR, uuid.uuid4().hex)
    image_paths = pdf_tools.pdf_to_images(path, out_dir, dpi=dpi)
    # Zip them up for a single download
    zip_path = out_dir + ".zip"
    import zipfile

    with zipfile.ZipFile(zip_path, "w") as zf:
        for p in image_paths:
            zf.write(p, os.path.basename(p))
    return FileResponse(zip_path, media_type="application/zip", filename="pages.zip")
