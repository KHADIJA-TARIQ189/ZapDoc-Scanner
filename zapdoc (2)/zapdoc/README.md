# ZapDoc

A document scanner + PDF toolkit app — **CamScanner-style scanning** and
**iLovePDF-style PDF tools** — built with a **Flutter** frontend and a
**Python (FastAPI)** backend.

```
zapdoc/
  backend/     <- Python/FastAPI: OpenCV scanning engine + PDF tools API
  frontend/    <- Flutter: camera UI, crop/filter UI, tools grid
```

## Features

**Scanning (CamScanner-style)**
- Live camera capture with an on-screen document guide
- Automatic edge/corner detection (OpenCV) with manual drag-to-adjust
- Perspective correction ("flattening") of the photographed page
- Filters: Color, Gray, Black & White, Enhance
- Multi-page capture, drag-to-reorder, export all pages as one PDF

**PDF tools (iLovePDF-style)**
- Merge PDFs
- Split PDF (by page ranges, or one file per page)
- Compress PDF
- Rotate PDF
- Add text watermark
- Password-protect / unlock PDF
- OCR: extract plain text, or produce a searchable PDF

## Quick start

**1. Backend**
```bash
cd backend
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Visit `http://localhost:8000/docs` to see/try every endpoint interactively.

**2. Frontend**
```bash
cd frontend
flutter create .           # generates native android/ios project files
flutter pub get
```
Edit `lib/services/api_service.dart` → set `baseUrl` to your backend's
address (see `frontend/README.md` for emulator vs. physical-device details),
then:
```bash
flutter run
```

## How it fits together

1. User taps **Scan** → camera opens → photo taken.
2. Photo is sent to `POST /scan/detect` → backend returns the 4 detected
   document corners.
3. User can drag corners to fine-tune, then picks a filter (Enhance/Color/
   Gray/B&W) and taps **Confirm**.
4. Photo + corners + filter go to `POST /scan/process` → backend
   perspective-corrects and filters the image, returns the result.
5. Repeat for more pages; reorder them; tap **Save as PDF** →
   `POST /scan/create-pdf` combines all page images into one PDF.
6. From the **Tools** tab, any existing PDF can be run through
   merge/split/compress/rotate/watermark/protect/unlock/OCR — each is one
   backend endpoint under `/pdf/*`.

See `backend/README.md` and `frontend/README.md` for full details on each
half of the app.
