# ZapDoc Backend (Python / FastAPI)

Handles all the "hard" work for the ZapDoc app:

- Document edge detection + perspective correction (like CamScanner)
- Filters: color / gray / black & white / enhanced
- Multi-image → single PDF
- iLovePDF-style tools: merge, split, compress, rotate, watermark,
  password protect / unlock, OCR (text extraction / searchable PDF)

## Setup

```bash
cd backend
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

OCR needs the Tesseract binary installed on the OS (not just the pip package):

```bash
# Ubuntu/Debian
sudo apt-get install tesseract-ocr
# macOS
brew install tesseract
# Windows: install from https://github.com/UB-Mannheim/tesseract/wiki
```

## Run

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be live at `http://<your-ip>:8000`.
Interactive docs: `http://<your-ip>:8000/docs`

In the Flutter app, point `ApiService.baseUrl` at this address
(use your computer's LAN IP, not `localhost`, when testing on a real phone;
use `10.0.2.2` for the Android emulator).

## Folder structure

```
backend/
  app/
    main.py                 # FastAPI app, CORS, router registration
    routers/
      scan.py                # /scan/* endpoints (camscanner-style)
      pdf.py                 # /pdf/* endpoints (ilovepdf-style)
    services/
      image_processing.py    # OpenCV: edge detect, warp, filters
      pdf_tools.py            # pypdf / PyMuPDF / img2pdf / OCR logic
  storage/
    uploads/                 # temp uploaded files
    outputs/                 # generated results served back to app
```

## API summary

### Scan (CamScanner-style)
| Method | Path | Purpose |
|---|---|---|
| POST | `/scan/detect` | Upload a photo → returns detected 4-corner document outline |
| POST | `/scan/process` | Upload a photo (+ optional corners + filter) → returns cropped/enhanced image |
| POST | `/scan/create-pdf` | Upload multiple processed page images → returns a single PDF |

### PDF tools (iLovePDF-style)
| Method | Path | Purpose |
|---|---|---|
| POST | `/pdf/merge` | Merge multiple PDFs into one |
| POST | `/pdf/split` | Split a PDF by page ranges (returns a zip) |
| POST | `/pdf/compress` | Reduce PDF file size |
| POST | `/pdf/rotate` | Rotate all/selected pages |
| POST | `/pdf/watermark` | Stamp text watermark on every page |
| POST | `/pdf/protect` | Add a password to a PDF |
| POST | `/pdf/unlock` | Remove a password from a PDF |
| POST | `/pdf/ocr` | Extract text / produce a searchable PDF |
| POST | `/pdf/to-images` | Render PDF pages as JPG thumbnails |

All endpoints return either a downloadable file (FileResponse) or JSON, and are documented interactively at `/docs`.
