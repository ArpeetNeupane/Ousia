#disabling ssl verification
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

import datetime
import re
from functools import lru_cache

import cv2
import easyocr
import nepali_datetime
import numpy as np


@lru_cache(maxsize=1)
def _get_easyocr_reader():
    """Lazily initialize EasyOCR so importing this module stays fast."""
    return easyocr.Reader(["en"], gpu=False)


@lru_cache(maxsize=1)
def _get_face_cascade():
    """Lazily initialize the Haar Cascade face detector."""
    return cv2.CascadeClassifier(
        cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
    )


def extract_dob_from_text(text):
    """
    Extracts a date of birth from OCR-extracted text.

    Supports multiple date formats including:
    - (dd/mm/yyyy)
    - dd/mm/yyyy or dd-mm-yyyy
    - yyyy/mm/dd (optionally marked as BS)

    If the detected year appears to be in Bikram Sambat (year > 2100),
    it converts it to Gregorian (AD) using nepali_datetime.

    Args:
        text (str): OCR-extracted raw text.

    Returns:
        datetime.date | None: Parsed date of birth if found, else None.
    """
    
    text = text.lower()

    patterns = [
        # parenthesized AD date like (06/02/2016)
        r'\((\d{1,2})[/](\d{1,2})[/](\d{4})\)',
        # dd/mm/yyyy
        r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})',
        # yyyy/mm/dd with optional bs
        r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s*(bs|b\.s\.)?',
    ]

    for p in patterns:
        match = re.search(p, text)
        if match:
            parts = match.groups()

            if len(parts) == 3:
                if len(parts[0]) == 4:
                    y, m, d = int(parts[0]), int(parts[1]), int(parts[2])
                else:
                    d, m, y = int(parts[0]), int(parts[1]), int(parts[2])
            else:
                y, m, d = int(parts[0]), int(parts[1]), int(parts[2])

            # treat as BS if year looks like a BS year
            if y > 2100:
                try:
                    bs_date = nepali_datetime.date(y, m, d)
                    return bs_date.to_datetime_date()
                except Exception:
                    continue

            return datetime.date(y, m, d)

    return None


def crop_largest_face(image):
    """
    Detects and crops the largest face from an image.

    Uses Haar Cascade for face detection and selects the largest
    detected face region. Adds a small margin around the face.

    Args:
        image (np.ndarray): Input image in OpenCV (BGR) format.

    Returns:
        np.ndarray | None: Cropped face image, or None if no face detected.
    """

    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

    face_cascade = _get_face_cascade()
    faces = face_cascade.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(60, 60)
    )

    if len(faces) == 0:
        return None

    #picking the largest detected face
    x, y, w, h = max(faces, key=lambda f: f[2] * f[3])

    #adding small margin
    pad = int(0.15 * w)
    x1 = max(x - pad, 0)
    y1 = max(y - pad, 0)
    x2 = min(x + w + pad, image.shape[1])
    y2 = min(y + h + pad, image.shape[0])

    face = image[y1:y2, x1:x2]

    return face


def extract_text_from_id(idcard_cv):
    """
    Extracts text from an ID card image using EasyOCR.

    Applies preprocessing such as resizing, grayscale conversion,
    and histogram equalization to improve OCR accuracy.

    Filters out low-confidence detections.

    Args:
        idcard_cv (np.ndarray): ID card image in OpenCV (BGR) format.

    Returns:
        str: Extracted text (lowercased). Returns empty string on failure.
    """

    extracted_text = ""

    try:
        #resizing for ocr stability
        h, w = idcard_cv.shape[:2]
        scale = 1200 / max(h, w)
        if scale < 1:
            idcard_cv = cv2.resize(
                idcard_cv,
                None,
                fx=scale,
                fy=scale,
                interpolation=cv2.INTER_AREA
            )

        gray = cv2.cvtColor(idcard_cv, cv2.COLOR_BGR2GRAY)
        gray = cv2.equalizeHist(gray)

        ocr_results = _get_easyocr_reader().readtext(gray)

        text_lines = []
        for _, text, confidence in ocr_results:
            if confidence > 0.45:
                text_lines.append(text.lower())

        extracted_text = " ".join(text_lines)

    except Exception as e:
        print(f"OCR ERROR: {e}")
        extracted_text = ""

    return extracted_text


def verify_student_identity(selfie_bytes, idcard_bytes):
    """
    Verifies a student's identity using facial recognition and OCR.

    Steps:
    - Converts byte streams to OpenCV images
    - Detects and crops faces from selfie and ID card
    - Compares faces using DeepFace (ArcFace model)
    - Extracts text from ID card using OCR

    Args:
        selfie_bytes (bytes): Byte stream of user's selfie image.
        idcard_bytes (bytes): Byte stream of ID card image.

    Returns:
        dict: {
            "is_match": bool,              # Face verification result
            "extracted_text": str,        # OCR-extracted text from ID
            "idcard_cv": np.ndarray       # Processed ID card image
        }
    """

    #converting byte streams to OpenCV formats / Numpy Arrays
    selfie_np = np.frombuffer(selfie_bytes, np.uint8)
    selfie_cv = cv2.imdecode(selfie_np, cv2.IMREAD_COLOR)
    
    idcard_np = np.frombuffer(idcard_bytes, np.uint8)
    idcard_cv = cv2.imdecode(idcard_np, cv2.IMREAD_COLOR)

    #face Matching (selfie and ID)
    try: 
        # Importing DeepFace lazily keeps module import + test discovery fast.
        from deepface import DeepFace

        selfie_face = crop_largest_face(selfie_cv)
        idcard_face = crop_largest_face(idcard_cv)

        if selfie_face is None or idcard_face is None:
            is_match = False
        else:
            match_result = DeepFace.verify(
                img1_path=selfie_face,
                img2_path=idcard_face,
                model_name="ArcFace",
                enforce_detection=True
            )
            is_match = match_result.get("verified", False)
    except Exception: 
        is_match = False

    #OCR Text Extraction from ID card using EasyOCR
    extracted_text = extract_text_from_id(idcard_cv)

    print(f"DEBUG: OCR DETECTED TEXT: {extracted_text}")

    return {
        "is_match": is_match,
        "extracted_text": extracted_text,
        "idcard_cv": idcard_cv
    }