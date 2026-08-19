"""
iLovePDF-style PDF tools, built on pypdf, PyMuPDF (fitz), img2pdf, and pytesseract.
Every function reads from disk paths and writes a result to disk, returning the
output path(s) so the router can stream them back to the Flutter app.
"""
from __future__ import annotations

import io
import os
import zipfile
from typing import List, Tuple

import fitz  # PyMuPDF
import img2pdf
from PIL import Image
from pypdf import PdfReader, PdfWriter


# ---------------------------------------------------------------------------
# Image(s) -> PDF  (finishing step of the scanning flow)
# ---------------------------------------------------------------------------
def images_to_pdf(image_paths: List[str], output_path: str) -> str:
    with open(output_path, "wb") as f:
        f.write(img2pdf.convert(image_paths))
    return output_path


# ---------------------------------------------------------------------------
# Merge
# ---------------------------------------------------------------------------
def merge_pdfs(input_paths: List[str], output_path: str) -> str:
    writer = PdfWriter()
    for path in input_paths:
        reader = PdfReader(path)
        for page in reader.pages:
            writer.add_page(page)
    with open(output_path, "wb") as f:
        writer.write(f)
    return output_path


# ---------------------------------------------------------------------------
# Split -> returns a zip of individual page-range PDFs
# ---------------------------------------------------------------------------
def split_pdf(input_path: str, ranges: List[Tuple[int, int]], output_zip_path: str) -> str:
    """
    ranges: list of (start_page, end_page), 1-indexed & inclusive.
    If ranges is empty, splits into one PDF per page.
    """
    reader = PdfReader(input_path)
    total_pages = len(reader.pages)

    if not ranges:
        ranges = [(i + 1, i + 1) for i in range(total_pages)]

    buffers = []
    for idx, (start, end) in enumerate(ranges, start=1):
        start = max(1, start)
        end = min(total_pages, end)
        writer = PdfWriter()
        for p in range(start - 1, end):
            writer.add_page(reader.pages[p])
        buf = io.BytesIO()
        writer.write(buf)
        buf.seek(0)
        buffers.append((f"part_{idx}_p{start}-{end}.pdf", buf.read()))

    with zipfile.ZipFile(output_zip_path, "w") as zf:
        for name, data in buffers:
            zf.writestr(name, data)

    return output_zip_path


# ---------------------------------------------------------------------------
# Compress -> re-encode embedded images at a lower quality via PyMuPDF
# ---------------------------------------------------------------------------
def compress_pdf(input_path: str, output_path: str, quality: int = 60) -> str:
    doc = fitz.open(input_path)
    for page in doc:
        images = page.get_images(full=True)
        for img in images:
            xref = img[0]
            try:
                base = doc.extract_image(xref)
                pix = fitz.Pixmap(base["image"])
                if pix.n - pix.alpha >= 4:  # CMYK -> RGB
                    pix = fitz.Pixmap(fitz.csRGB, pix)
                img_bytes = pix.tobytes("jpeg", jpg_quality=quality)
                doc._update_stream(xref, img_bytes)
            except Exception:
                continue  # skip images that can't be re-encoded

    doc.save(output_path, garbage=4, deflate=True, clean=True)
    doc.close()
    return output_path


# ---------------------------------------------------------------------------
# Rotate
# ---------------------------------------------------------------------------
def rotate_pdf(input_path: str, output_path: str, degrees: int = 90, pages: List[int] | None = None) -> str:
    reader = PdfReader(input_path)
    writer = PdfWriter()
    target_pages = set(pages) if pages else None

    for i, page in enumerate(reader.pages, start=1):
        if target_pages is None or i in target_pages:
            page.rotate(degrees)
        writer.add_page(page)

    with open(output_path, "wb") as f:
        writer.write(f)
    return output_path


# ---------------------------------------------------------------------------
# Watermark
# ---------------------------------------------------------------------------
def watermark_pdf(input_path: str, output_path: str, text: str, opacity: float = 0.3) -> str:
    doc = fitz.open(input_path)
    for page in doc:
        rect = page.rect
        center = fitz.Point(rect.width / 2, rect.height / 2)
        # Rotate 45 degrees around the page center via a morph matrix
        # (insert_text's `rotate` kwarg only accepts 0/90/180/270).
        morph = (center, fitz.Matrix(45))
        page.insert_text(
            fitz.Point(rect.width / 2 - len(text) * 6, rect.height / 2),
            text,
            fontsize=40,
            color=(0.5, 0.5, 0.5),
            fill_opacity=opacity,
            overlay=True,
            morph=morph,
        )
    doc.save(output_path)
    doc.close()
    return output_path


# ---------------------------------------------------------------------------
# Protect / Unlock
# ---------------------------------------------------------------------------
def protect_pdf(input_path: str, output_path: str, password: str) -> str:
    reader = PdfReader(input_path)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    writer.encrypt(password)
    with open(output_path, "wb") as f:
        writer.write(f)
    return output_path


def unlock_pdf(input_path: str, output_path: str, password: str) -> str:
    reader = PdfReader(input_path)
    if reader.is_encrypted:
        reader.decrypt(password)
    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    with open(output_path, "wb") as f:
        writer.write(f)
    return output_path


# ---------------------------------------------------------------------------
# OCR -> plain text, or a searchable PDF (image + invisible text layer)
# ---------------------------------------------------------------------------
def ocr_extract_text(input_path: str, lang: str = "eng") -> str:
    import pytesseract

    doc = fitz.open(input_path)
    all_text = []
    for page in doc:
        pix = page.get_pixmap(dpi=200)
        img = Image.open(io.BytesIO(pix.tobytes("png")))
        all_text.append(pytesseract.image_to_string(img, lang=lang))
    doc.close()
    return "\n\n----- page break -----\n\n".join(all_text)


def ocr_searchable_pdf(input_path: str, output_path: str, lang: str = "eng") -> str:
    """Rasterize each page, OCR it, and rebuild a PDF with an invisible text layer."""
    import pytesseract

    doc = fitz.open(input_path)
    out = fitz.open()
    for page in doc:
        pix = page.get_pixmap(dpi=200)
        img_bytes = pix.tobytes("png")
        pdf_bytes = pytesseract.image_to_pdf_or_hocr(
            Image.open(io.BytesIO(img_bytes)), extension="pdf", lang=lang
        )
        ocr_page_doc = fitz.open("pdf", pdf_bytes)
        out.insert_pdf(ocr_page_doc)
    out.save(output_path)
    out.close()
    doc.close()
    return output_path


# ---------------------------------------------------------------------------
# PDF -> images (thumbnails / previews)
# ---------------------------------------------------------------------------
def pdf_to_images(input_path: str, output_dir: str, dpi: int = 100) -> List[str]:
    os.makedirs(output_dir, exist_ok=True)
    doc = fitz.open(input_path)
    paths = []
    for i, page in enumerate(doc):
        pix = page.get_pixmap(dpi=dpi)
        out_path = os.path.join(output_dir, f"page_{i + 1}.jpg")
        pix.save(out_path)
        paths.append(out_path)
    doc.close()
    return paths
