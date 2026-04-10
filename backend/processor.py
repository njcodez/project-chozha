"""
processor.py — Project Chozha
SAM2 binarisation pipeline for Tamil stone inscriptions.
Exposes a single public function: process_image(input_path) -> output_path
"""

from __future__ import annotations

import os
import uuid
import warnings
import logging

import cv2
import numpy as np
import torch

warnings.filterwarnings("ignore", category=UserWarning, module="sam2")
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Storage layout
# ---------------------------------------------------------------------------
STORAGE_ROOT = os.environ.get("STORAGE_ROOT", "/storage")
OUTPUT_DIR = os.path.join(STORAGE_ROOT, "output")

# ---------------------------------------------------------------------------
# Feature toggles
# ---------------------------------------------------------------------------

# Set to True to apply character-bounding-box masking as the final output step.
# When False, the full binarised crop is returned as-is.
ENABLE_CHARACTER_BOX_FILTER = False

# ---------------------------------------------------------------------------
# SAM2 model (loaded once per worker process)
# ---------------------------------------------------------------------------
_predictor = None

def _get_predictor():
    global _predictor
    if _predictor is None:
        from sam2.build_sam import build_sam2
        from sam2.sam2_image_predictor import SAM2ImagePredictor

        checkpoint = "/app/sam2.1_hiera_large.pt"
        config = "configs/sam2.1/sam2.1_hiera_l.yaml"

        logger.info("Loading SAM2 from local files...")

        model = build_sam2(config, checkpoint)
        _predictor = SAM2ImagePredictor(model)

        logger.info("SAM2 loaded (OFFLINE, correct path).")

    return _predictor
# ---------------------------------------------------------------------------
# CV helpers (ported directly from the research notebook)
# ---------------------------------------------------------------------------

def _get_prompt_points(binary: np.ndarray, n: int = 8):
    """
    Sample *n* points that fall on text strokes, excluding the outer 15 %
    border to avoid ceiling / pillar / floor noise.
    """
    h, w = binary.shape

    border_mask = np.zeros_like(binary)
    y1, y2 = int(h * 0.15), int(h * 0.85)
    x1, x2 = int(w * 0.15), int(w * 0.85)
    border_mask[y1:y2, x1:x2] = 1

    masked = cv2.bitwise_and(binary, binary, mask=border_mask)
    ys, xs = np.where(masked > 0)

    if len(xs) == 0:
        return np.array([[w // 2, h // 2]]), np.array([1])

    indices = np.linspace(0, len(xs) - 1, n, dtype=int)
    coords = np.stack([xs[indices], ys[indices]], axis=1)
    labels = np.ones(n, dtype=int)
    return coords, labels


def _binarise(img_bgr: np.ndarray) -> np.ndarray:
    """
    OpenCV binarisation: Gaussian blur → CLAHE → background subtraction → Otsu
    followed by connected-component noise removal.
    """
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)
    blur = cv2.GaussianBlur(gray, (7, 7), 1.5)
    clahe = cv2.createCLAHE(clipLimit=1.5, tileGridSize=(16, 16))
    enhanced = clahe.apply(blur)
    background = cv2.GaussianBlur(enhanced, (51, 51), 0)
    corrected = cv2.subtract(background, enhanced)

    _, binary = cv2.threshold(corrected, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)

    nb, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    areas = stats[1:, cv2.CC_STAT_AREA]
    heights = stats[1:, cv2.CC_STAT_HEIGHT]

    if len(areas) == 0:
        return binary

    median_area = np.median(areas[areas > 0])
    median_height = np.median(heights[heights > 0])

    min_area = max(15, int(median_area * 0.08))
    min_height = max(4, int(median_height * 0.25))

    clean = np.zeros_like(binary)
    for i in range(1, nb):
        if (
            stats[i, cv2.CC_STAT_AREA] >= min_area
            and stats[i, cv2.CC_STAT_HEIGHT] >= min_height
        ):
            clean[labels == i] = 255
    return clean


def _remove_dots(
    binary: np.ndarray,
    area_ratio: float = 0.03,
    height_ratio: float = 0.20,
    width_ratio: float = 0.20,
    min_area: int = 20,
    min_height: int = 4,
    min_width: int = 4,
) -> np.ndarray:
    """Remove isolated dots / noise blobs using adaptive thresholds."""
    nb, labels, stats, _ = cv2.connectedComponentsWithStats(binary, connectivity=8)
    if nb <= 1:
        return binary

    areas = stats[1:, cv2.CC_STAT_AREA]
    heights = stats[1:, cv2.CC_STAT_HEIGHT]
    widths = stats[1:, cv2.CC_STAT_WIDTH]

    def robust_median(arr: np.ndarray) -> float:
        s = np.sort(arr)
        lo, hi = int(len(s) * 0.10), int(len(s) * 0.90)
        mid = s[lo:hi]
        return float(np.median(mid)) if len(mid) > 0 else float(np.median(arr))

    med_area = robust_median(areas)
    med_height = robust_median(heights)
    med_width = robust_median(widths)

    thresh_area = max(min_area, int(med_area * area_ratio))
    thresh_height = max(min_height, int(med_height * height_ratio))
    thresh_width = max(min_width, int(med_width * width_ratio))

    clean = np.zeros_like(binary)
    for i in range(1, nb):
        if (
            stats[i, cv2.CC_STAT_AREA] >= thresh_area
            and stats[i, cv2.CC_STAT_HEIGHT] >= thresh_height
            and stats[i, cv2.CC_STAT_WIDTH] >= thresh_width
        ):
            clean[labels == i] = 255
    return clean


def _get_character_boxes(binary_inv: np.ndarray, dilation_x: int = 5, dilation_y: int = 3):
    """Return character bounding boxes as [(x, y, w, h), ...]."""
    binary = cv2.bitwise_not(binary_inv)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (dilation_x, dilation_y))
    dilated = cv2.dilate(binary, kernel, iterations=1)

    nb, labels, stats, _ = cv2.connectedComponentsWithStats(dilated, connectivity=8)
    if nb <= 1:
        return []

    areas = stats[1:, cv2.CC_STAT_AREA]
    heights = stats[1:, cv2.CC_STAT_HEIGHT]
    widths = stats[1:, cv2.CC_STAT_WIDTH]

    h_img, w_img = binary.shape
    abs_min_area = (h_img * w_img) * 0.0012
    abs_min_height = h_img * 0.015
    abs_min_width = w_img * 0.005

    candidate_mask = (
        (areas >= abs_min_area)
        & (heights >= abs_min_height)
        & (widths >= abs_min_width)
    )
    if candidate_mask.sum() == 0:
        return []

    med_area = np.median(areas[candidate_mask])
    med_height = np.median(heights[candidate_mask])
    med_width = np.median(widths[candidate_mask])

    boxes = []
    for i in range(1, nb):
        a = stats[i, cv2.CC_STAT_AREA]
        h = stats[i, cv2.CC_STAT_HEIGHT]
        w = stats[i, cv2.CC_STAT_WIDTH]
        x = stats[i, cv2.CC_STAT_LEFT]
        y = stats[i, cv2.CC_STAT_TOP]
        if (
            med_area * 0.20 <= a <= med_area * 6.0
            and med_height * 0.2 <= h <= med_height * 3.0
            and med_width * 0.2 <= w <= med_width * 5.0
        ):
            boxes.append((x, y, w, h))
    return boxes


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def process_image(input_path: str) -> str:
    """
    Run the full SAM2 binarisation pipeline on *input_path*.

    Returns the absolute path to the saved output PNG.
    Raises RuntimeError on failure.
    """
    predictor = _get_predictor()

    img_bgr = cv2.imread(input_path)
    if img_bgr is None:
        raise RuntimeError(f"Could not read image: {input_path}")

    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    # ── Step 1: initial binarisation → SAM prompt points ──────────────────
    binary_init = _binarise(img_bgr)
    coords, labels = _get_prompt_points(binary_init, n=8)

    # ── Step 2: SAM2 segments the inscription region ───────────────────────
    device = "cuda" if torch.cuda.is_available() else "cpu"
    ctx = (
        torch.autocast("cuda", dtype=torch.bfloat16)
        if device == "cuda"
        else torch.autocast("cpu", dtype=torch.bfloat16)
    )

    with torch.inference_mode(), ctx:
        predictor.set_image(img_rgb)
        masks, scores, _ = predictor.predict(
            point_coords=coords,
            point_labels=labels,
            multimask_output=True,
        )

    best = masks[np.argmax(scores)].astype(np.uint8)  # H×W bool → uint8

    # ── Step 3: crop to SAM bounding box ──────────────────────────────────
    ys, xs = np.where(best > 0)
    if len(ys) == 0:
        raise RuntimeError("SAM2 returned an empty mask — no inscription region found.")

    y1_b, y2_b = int(ys.min()), int(ys.max())
    x1_b, x2_b = int(xs.min()), int(xs.max())
    crop_bgr = img_bgr[y1_b:y2_b, x1_b:x2_b]

    # ── Step 4: refined binarisation on the cropped region ────────────────
    binary = _binarise(crop_bgr)
    binary = _remove_dots(binary, min_area=30, min_height=6, min_width=6)

    # ── Step 5: invert to black-text-on-white ─────────────────────────────
    final_inv = 255 - binary

    # ── Step 6: optional character-box masking ────────────────────────────
    if ENABLE_CHARACTER_BOX_FILTER:
        boxes = _get_character_boxes(final_inv, dilation_x=5, dilation_y=3)
        if boxes:
            output_img = np.full_like(final_inv, 255)
            for bx, by, bw, bh in boxes:
                output_img[by : by + bh, bx : bx + bw] = final_inv[by : by + bh, bx : bx + bw]
        else:
            output_img = final_inv
    else:
        output_img = final_inv

    # ── Step 6: save output ───────────────────────────────────────────────
    # Derive job_id from the input path structure: storage/input/{job_id}/original.jpg
    job_id = os.path.basename(os.path.dirname(input_path))
    out_dir = os.path.join(OUTPUT_DIR, job_id)
    os.makedirs(out_dir, exist_ok=True)
    out_path = os.path.join(out_dir, "binarized.png")

    success = cv2.imwrite(out_path, output_img)
    if not success:
        raise RuntimeError(f"cv2.imwrite failed for path: {out_path}")

    logger.info("Saved output: %s", out_path)
    return out_path
