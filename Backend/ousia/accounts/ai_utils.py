#disabling ssl verification
import ssl
ssl._create_default_https_context = ssl._create_unverified_context

import cv2, re, datetime, easyocr, nepali_datetime
import numpy as np
from deepface import DeepFace


#loading OCR globally so it doesn't reload on every request
easyocr_reader = easyocr.Reader(
    ['en'],
    gpu=False
)

#loading face detector
face_cascade = cv2.CascadeClassifier(
    cv2.data.haarcascades + "haarcascade_frontalface_default.xml"
)


def extract_dob_from_text(text):
    text = text.lower()

    #patterns
    patterns = [
        #ad formats
        r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})',     #yyyy-mm-dd
        r'(\d{1,2})[-/](\d{1,2})[-/](\d{4})',     #dd-mm-yyyy

        #bs formats
        r'(\d{4})[-/](\d{1,2})[-/](\d{1,2})\s*(bs|b\.s\.)'
    ]

    for p in patterns:
        match = re.search(p, text)
        if match:
            parts = match.groups()

            #bs detected
            if 'bs' in parts:
                y, m, d = int(parts[0]), int(parts[1]), int(parts[2])
                bs_date = nepali_datetime.date(y, m, d)
                ad_date = bs_date.to_datetime_date()
                return ad_date

            #yyyy-mm-dd
            if len(parts[0]) == 4:
                return datetime.date(int(parts[0]), int(parts[1]), int(parts[2]))

            #dd-mm-yyyy
            return datetime.date(int(parts[2]), int(parts[1]), int(parts[0]))

    return None


def crop_largest_face(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

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

        ocr_results = easyocr_reader.readtext(gray)

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
    #converting byte streams to OpenCV formats / Numpy Arrays
    selfie_np = np.frombuffer(selfie_bytes, np.uint8)
    selfie_cv = cv2.imdecode(selfie_np, cv2.IMREAD_COLOR)
    
    idcard_np = np.frombuffer(idcard_bytes, np.uint8)
    idcard_cv = cv2.imdecode(idcard_np, cv2.IMREAD_COLOR)

    #face Matching (selfie and ID) 
    try: 
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