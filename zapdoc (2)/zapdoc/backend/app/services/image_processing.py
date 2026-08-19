"""
CamScanner-style image processing.

Pipeline:
  1. detect_document_edges() -> find the 4 corners of a document in a photo
  2. warp_perspective()      -> "flatten" the document to a top-down rectangle
  3. apply_filter()          -> color / gray / black-white / enhanced

All functions operate on OpenCV BGR numpy arrays.
"""
from __future__ import annotations

import cv2
import numpy as np


def _order_points(pts: np.ndarray) -> np.ndarray:
    """Order 4 points as top-left, top-right, bottom-right, bottom-left."""
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    diff = np.diff(pts, axis=1)
    rect[0] = pts[np.argmin(s)]        # top-left has smallest sum
    rect[2] = pts[np.argmax(s)]        # bottom-right has largest sum
    rect[1] = pts[np.argmin(diff)]     # top-right has smallest diff
    rect[3] = pts[np.argmax(diff)]     # bottom-left has largest diff
    return rect


def detect_document_edges(image: np.ndarray) -> list[list[float]]:
    """
    Try to find the document's 4 corners in the image.
    Falls back to the full image bounds if nothing convincing is found.

    Returns corners as [[x, y], [x, y], [x, y], [x, y]] in the ORIGINAL
    image's pixel coordinates, ordered TL, TR, BR, BL.
    """
    orig_h, orig_w = image.shape[:2]

    # Work on a downscaled copy for speed, then scale coordinates back up.
    scale = 1000.0 / max(orig_h, orig_w) if max(orig_h, orig_w) > 1000 else 1.0
    resized = cv2.resize(image, (int(orig_w * scale), int(orig_h * scale)))

    gray = cv2.cvtColor(resized, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edged = cv2.Canny(blurred, 50, 150)
    edged = cv2.dilate(edged, np.ones((3, 3), np.uint8), iterations=1)

    contours, _ = cv2.findContours(edged, cv2.RETR_LIST, cv2.CHAIN_APPROX_SIMPLE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)[:10]

    doc_contour = None
    for c in contours:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.02 * peri, True)
        if len(approx) == 4 and cv2.contourArea(approx) > 0.2 * resized.shape[0] * resized.shape[1]:
            doc_contour = approx.reshape(4, 2)
            break

    if doc_contour is None:
        # Fallback: assume the whole image is the document.
        corners = np.array(
            [[0, 0], [orig_w, 0], [orig_w, orig_h], [0, orig_h]], dtype="float32"
        )
        return corners.tolist()

    corners = _order_points(doc_contour.astype("float32"))
    corners = corners / scale  # scale back to original resolution
    return corners.tolist()


def warp_perspective(image: np.ndarray, corners: list[list[float]]) -> np.ndarray:
    """Flatten the quadrilateral defined by `corners` into a top-down rectangle."""
    pts = _order_points(np.array(corners, dtype="float32"))
    (tl, tr, br, bl) = pts

    width_a = np.linalg.norm(br - bl)
    width_b = np.linalg.norm(tr - tl)
    max_width = max(int(width_a), int(width_b))

    height_a = np.linalg.norm(tr - br)
    height_b = np.linalg.norm(tl - bl)
    max_height = max(int(height_a), int(height_b))

    max_width = max(max_width, 1)
    max_height = max(max_height, 1)

    dst = np.array(
        [[0, 0], [max_width - 1, 0], [max_width - 1, max_height - 1], [0, max_height - 1]],
        dtype="float32",
    )

    matrix = cv2.getPerspectiveTransform(pts, dst)
    return cv2.warpPerspective(image, matrix, (max_width, max_height))


def apply_filter(image: np.ndarray, mode: str = "enhance") -> np.ndarray:
    """
    mode: "color" | "gray" | "bw" | "enhance"
      color   - light auto contrast/brightness only
      gray    - grayscale
      bw      - high-contrast black & white (adaptive threshold), best for text scans
      enhance - sharpened + contrast-boosted color (CamScanner "Enhance" mode)
    """
    if mode == "color":
        lab = cv2.cvtColor(image, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        l = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(8, 8)).apply(l)
        return cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    if mode == "gray":
        return cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)

    if mode == "bw":
        bw = cv2.adaptiveThreshold(
            gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY, 25, 15
        )
        return cv2.cvtColor(bw, cv2.COLOR_GRAY2BGR)

    # "enhance" (default): sharpen + boost contrast, keep color
    blurred = cv2.GaussianBlur(image, (0, 0), 3)
    sharpened = cv2.addWeighted(image, 1.5, blurred, -0.5, 0)
    lab = cv2.cvtColor(sharpened, cv2.COLOR_BGR2LAB)
    l, a, b = cv2.split(lab)
    l = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8)).apply(l)
    return cv2.cvtColor(cv2.merge((l, a, b)), cv2.COLOR_LAB2BGR)


def process_document(
    image: np.ndarray, corners: list[list[float]] | None, mode: str = "enhance"
) -> np.ndarray:
    """Full pipeline: crop+warp (if corners given) then apply filter."""
    if corners is not None and len(corners) == 4:
        image = warp_perspective(image, corners)
    return apply_filter(image, mode)
