import os
import re
import logging
import unicodedata
from dataclasses import dataclass
from enum import Enum

import torch
from PIL import Image
from transformers import pipeline

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEXT_SMALL_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../ML Models", "Text Small")
)

TEXT_LARGE_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../ML Models", "Text Large")
)
IMAGE_SMALL_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../ML Models", "Image Small")
)

BLOCK_THRESHOLD = 0.85
REVIEW_THRESHOLD = 0.50

#video frame sampling — checking first, last, and every Nth frame
VIDEO_FRAME_INTERVAL = 30  #every 30 frames (~1s at 30fps)


#enums

class NSFWVerdict(Enum):
    PASS = "pass"
    REVIEW = "review"
    BLOCK = "block"


@dataclass
class NSFWResult:
    verdict: NSFWVerdict
    score: float
    label: str
    model_used: str
    reason: str


#grooming regex

GROOMING_REGEX_PATTERNS = [
    r"(don't|dont|do not)\s+tell\s+(your\s+)?(mom|dad|mother|father|parents|anyone|nobody)",
    r"keep\s+(this\s+|it\s+)?(a\s+)?secret",
    r"our\s+little\s+secret",
    r"just\s+between\s+(us|you\s+and\s+me)",
    r"(no\s+one|nobody)\s+(needs\s+to|has\s+to|should)\s+know",
    r"(don't|dont|do not)\s+tell\s+anyone",
    r"this\s+stays\s+between\s+us",
    r"promise\s+(me\s+)?(you\s+)?(won't|wont|will not)\s+tell",
    r"are\s+you\s+(alone|by\s+yourself)",
    r"is\s+anyone\s+(home|there|around|with\s+you)",
    r"are\s+your\s+(parents|mom|dad|mother|father)\s+(home|around|there|nearby)",
    r"(where\s+are\s+your\s+parents|where'?s\s+your\s+(mom|dad|mother|father))",
    r"are\s+you\s+(home\s+)?alone",
    r"(move|switch|talk|chat|message|contact)\s+(me\s+)?(to|on|over\s+to|via|through)\s+(whatsapp|telegram|snapchat|discord|instagram|kik|signal|wechat|line|viber)",
    r"(talk|chat|speak|message)\s+(somewhere\s+)?(else|private|privately)",
    r"(add|find)\s+me\s+on\s+(whatsapp|telegram|snapchat|discord|instagram|kik|signal)",
    r"(my\s+)?(snap|insta|discord|telegram|kik)\s+(is|username|handle|id)",
    r"send\s+(me\s+)?(a\s+)?(pic|picture|photo|selfie|nude|nudes|image|img|snap)",
    r"show\s+me\s+(a\s+)?(pic|picture|photo|yourself|your\s+face)",
    r"(can\s+i|let\s+me)\s+see\s+(you|a\s+pic|a\s+photo|a\s+picture)",
    r"(take|send)\s+(a\s+)?(selfie|pic|photo|picture)\s+(for\s+me|to\s+me)",
    r"(share|post)\s+(a\s+)?(pic|photo|picture|selfie)\s+(with\s+me|for\s+me)",
    r"what\s+(are\s+you|r\s+u)\s+wearing",
    r"show\s+me\s+(your\s+)?(body|outfit|clothes|figure|shape)",
    r"(describe|tell\s+me)\s+what\s+you('?re|\s+are)\s+wearing",
    r"(turn\s+on|enable)\s+(your\s+)?(camera|cam|webcam)",
    r"(video\s+call|facetime|vc|video\s+chat)\s+(me|with\s+me)",
    r"(hop|get|jump)\s+on\s+(a\s+)?(call|vc|video\s+call|facetime)",
    r"go\s+(somewhere\s+)?(private|alone|to\s+your\s+room)",
    r"(lock|close)\s+(your\s+)?(door|room)",
    r"go\s+to\s+(your\s+)?(bedroom|room|bathroom)",
    r"(make sure|ensure)\s+(no\s+one|nobody)\s+(can\s+see|is\s+watching|is\s+around)",
    r"you'?re?\s+(so\s+|very\s+|really\s+|quite\s+)?mature\s+(for\s+your\s+age)?",
    r"you'?re?\s+(so\s+|very\s+|really\s+)?different\s+from\s+(other\s+)?(kids|children|girls|boys|teens)",
    r"you\s+(seem|act|look)\s+(so\s+|very\s+|really\s+)?(old|grown\s+up|mature)",
    r"(most|other)\s+(kids|children|girls|boys|teens)\s+(aren'?t|are\s+not|don'?t)\s+(like\s+you|as\s+mature)",
    r"you'?re?\s+(not\s+like|different\s+from)\s+(other\s+)?(kids|children|girls|boys|teens)",
    r"(can\s+you|do\s+you)\s+keep\s+(a\s+)?secret",
    r"(are\s+you|r\s+u)\s+good\s+at\s+keeping\s+secrets",
    r"(i\s+)?(trust|trusted)\s+you\s+(with\s+this|to\s+keep)",
    r"age\s+is\s+just\s+(a\s+)?number",
    r"(age\s+doesn'?t|age\s+does\s+not)\s+matter",
    r"(you'?re?|ur)\s+(old\s+enough|mature\s+enough)",
    r"(love\s+knows|feelings?\s+(don'?t|does\s+not)\s+care)\s+(no\s+)?age",
    r"(let'?s|lets|we\s+should)\s+(meet\s+up|hang\s+out|get\s+together)\s+(alone|just\s+us|in\s+person)",
    r"(don't|dont)\s+tell\s+anyone\s+(about\s+)?(us|our\s+meet|our\s+plans)",
    r"(come|sneak)\s+(over|out)\s+(when|after|without)\s+(your\s+)?(parents|mom|dad|are\s+asleep|are\s+away)",
    r"(i('?ll|\s+will)|i\s+can)\s+(buy|get|send|give)\s+you\s+(gifts?|money|stuff|things|presents?)",
    r"(i\s+)?(bought|got|have)\s+(something|a\s+gift|a\s+present)\s+for\s+you",
]

GROOMING_REGEX = [re.compile(p, re.IGNORECASE) for p in GROOMING_REGEX_PATTERNS]
GROOMING_REGEX_LOOSE = [
    re.compile(re.sub(r'\\s\+', r'\\s*', p), re.IGNORECASE)
    for p in GROOMING_REGEX_PATTERNS
]


def _normalize_text(text: str) -> str:
    text = text.lower()
    text = unicodedata.normalize('NFKD', text)
    return re.sub(r'\s+', '', text)


#text classifier

class NSFWTextClassifier:
    _small_pipeline = None
    _large_pipeline = None
    _loaded = False

    @classmethod
    def _load_models(cls):
        if cls._loaded:
            return
        try:
            logger.info("Loading Text Small (DistilBERT) NSFW model...")
            cls._small_pipeline = pipeline(
                "text-classification",
                model=TEXT_SMALL_PATH,
                tokenizer=TEXT_SMALL_PATH,
                device=0,
                truncation=True,
                max_length=512,
            )
            logger.info("Text Small model loaded.")
        except Exception as e:
            logger.error(f"Failed to load Text Small model: {e}")
            cls._small_pipeline = None

        try:
            logger.info("Loading Text Large (TostAI) NSFW model...")
            cls._large_pipeline = pipeline(
                "text-classification",
                model=TEXT_LARGE_PATH,
                tokenizer=TEXT_LARGE_PATH,
                device=0,
                truncation=True,
                max_length=512,
            )
            logger.info("Text Large model loaded.")
        except Exception as e:
            logger.error(f"Failed to load Text Large model: {e}")
            cls._large_pipeline = None

        cls._loaded = True

    @classmethod
    def _is_nsfw_label(cls, label: str) -> bool:
        label_lower = label.lower()
        nsfw_keywords = ["nsfw", "unsafe", "explicit", "adult", "toxic", "offensive", "hate"]
        return any(k in label_lower for k in nsfw_keywords)

    @classmethod
    def _run_pipeline(cls, pipe, text: str) -> tuple[float, str]:
        results = pipe(text, top_k=None)
        for r in results:
            if cls._is_nsfw_label(r["label"]):
                return r["score"], r["label"]
        top = results[0]
        return top["score"], top["label"]

    @classmethod
    def classify(cls, text: str) -> NSFWResult:
        cls._load_models()

        if not text or not text.strip():
            return NSFWResult(
                verdict=NSFWVerdict.PASS,
                score=0.0,
                label="clean",
                model_used="none",
                reason="Empty caption."
            )

        #grooming regex check first (rule-based, fast)
        lower_text = text.lower()
        normalized_text = _normalize_text(text)
        for strict, loose in zip(GROOMING_REGEX, GROOMING_REGEX_LOOSE):
            if strict.search(lower_text) or loose.search(normalized_text):
                return NSFWResult(
                    verdict=NSFWVerdict.BLOCK,
                    score=0.99,
                    label="grooming_pattern",
                    model_used="rule_engine",
                    reason="Grooming pattern detected.",
                )

        if cls._small_pipeline is None:
            logger.warning("Text Small model unavailable, skipping text NSFW check.")
            return NSFWResult(
                verdict=NSFWVerdict.PASS,
                score=0.0,
                label="unknown",
                model_used="none",
                reason="Model unavailable."
            )

        try:
            score, label = cls._run_pipeline(cls._small_pipeline, text)
        except Exception as e:
            logger.error(f"Text Small inference error: {e}")
            return NSFWResult(
                verdict=NSFWVerdict.PASS,
                score=0.0, 
                label="unknown", 
                model_used="text_small", 
                reason=f"Inference error: {e}"
            )

        is_nsfw = cls._is_nsfw_label(label)

        if is_nsfw and score >= BLOCK_THRESHOLD:
            return NSFWResult(
                verdict=NSFWVerdict.BLOCK, 
                score=score, 
                label=label, 
                model_used="text_small", 
                reason=f"High confidence NSFW (score={score:.3f})."
            )

        if is_nsfw and score >= REVIEW_THRESHOLD:
            if cls._large_pipeline is not None:
                try:
                    large_score, large_label = cls._run_pipeline(cls._large_pipeline, text)
                    is_nsfw_large = cls._is_nsfw_label(large_label)
                    if is_nsfw_large and large_score >= BLOCK_THRESHOLD:
                        return NSFWResult(
                            verdict=NSFWVerdict.BLOCK, 
                            score=large_score, 
                            label=large_label, 
                            model_used="text_large", 
                            reason=f"Large model high confidence NSFW (score={large_score:.3f})."
                        )
                    elif is_nsfw_large and large_score >= REVIEW_THRESHOLD:
                        return NSFWResult(
                            verdict=NSFWVerdict.REVIEW, 
                            score=large_score, 
                            label=large_label, 
                            model_used="text_large", 
                            reason=f"Large model flagged for review (score={large_score:.3f})."
                        )
                    else:
                        return NSFWResult(
                            verdict=NSFWVerdict.PASS, 
                            score=large_score, 
                            label=large_label, 
                            model_used="text_large", 
                            reason=f"Large model cleared (score={large_score:.3f})."
                        )
                except Exception as e:
                    logger.error(f"Text Large inference error: {e}")
                    return NSFWResult(
                        verdict=NSFWVerdict.REVIEW, 
                        score=score, label=label, 
                        model_used="text_small", 
                        reason=f"Large model error, flagging cautiously (score={score:.3f})."
                    )
            else:
                return NSFWResult(
                    verdict=NSFWVerdict.REVIEW, 
                    score=score, label=label, 
                    model_used="text_small", 
                    reason=f"Uncertain score, flagged for review (score={score:.3f})."
                )

        return NSFWResult(
            verdict=NSFWVerdict.PASS, 
            score=score, label=label, 
            model_used="text_small", 
            reason=f"Content cleared (score={score:.3f})."
        )


#image classifier

class NSFWImageClassifier:
    _small_model = None   #YOLOv9
    _loaded = False

    @classmethod
    def _load_models(cls):
        if cls._loaded:
            return

        #loading image small (YOLO)
        try:
            logger.info("Loading Image Small (FalconSAI) NSFW model...")
            original_load = torch.load
            torch.load = lambda *args, **kwargs: original_load(*args, **{**kwargs, 'weights_only': False})
            
            cls._small_model = pipeline(
                "image-classification",
                model=IMAGE_SMALL_PATH,
                device=0 if torch.cuda.is_available() else -1,
            )
            
            torch.load = original_load
            logger.info("Image Small model loaded.")
        except Exception as e:
            torch.load = original_load
            logger.error(f"Failed to load Image Small model: {e}")
            cls._small_model = None
        cls._loaded = True

    @classmethod
    def _is_nsfw_label(cls, label: str) -> bool:
        label_lower = label.lower()
        nsfw_keywords = ["nsfw", "unsafe", "explicit", "adult", "porn", "nude", "hentai", "sexy"]
        return any(k in label_lower for k in nsfw_keywords)

    @classmethod
    def _run_yolo(cls, image: Image.Image) -> tuple[float, str]:
        results = cls._small_model(image, top_k=None)
        print(f"FalconSAI RAW RESULTS: {results}")
        for r in results:
            if r["label"].lower() == "nsfw":
                return r["score"], "nsfw"
        return 0.0, "normal"

    @classmethod
    def classify_image(cls, image: Image.Image) -> NSFWResult:
        cls._load_models()
        
        if cls._small_model is None:
            return NSFWResult(verdict=NSFWVerdict.BLOCK, score=0.0, label="unknown", model_used="none", reason="Image model unavailable, blocking for safety.")

        try:
            score, label = cls._run_yolo(image)
            is_nsfw = label == "nsfw"

            if is_nsfw and score >= BLOCK_THRESHOLD:
                return NSFWResult(verdict=NSFWVerdict.BLOCK, score=score, label=label, model_used="image_small", reason=f"YOLOv9 high confidence NSFW (score={score:.3f}).")
            return NSFWResult(verdict=NSFWVerdict.PASS, score=score, label=label, model_used="image_small", reason=f"Image cleared by YOLOv9 (score={score:.3f}).")

        except Exception as e:
            logger.error(f"Image Small inference error: {e}")
            return NSFWResult(verdict=NSFWVerdict.BLOCK, score=0.0, label="unknown", model_used="none", reason="Inference error, blocking for safety.")

#video frame extractor

def _extract_frames(video_path: str) -> list[Image.Image]:
    """Extract first, last, and every VIDEO_FRAME_INTERVAL frames."""
    try:
        import cv2
    except ImportError:
        raise ImportError("opencv-python is required for video analysis. Run: pip install opencv-python")

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        logger.error(f"Could not open video: {video_path}")
        return []

    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    if total_frames == 0:
        cap.release()
        return []

    frame_indices = set()
    frame_indices.add(0)  #first
    frame_indices.add(total_frames - 1)  #last
    frame_indices.update(range(0, total_frames, VIDEO_FRAME_INTERVAL))  #every N frames

    frames = []
    for idx in sorted(frame_indices):
        cap.set(cv2.CAP_PROP_POS_FRAMES, idx)
        ret, frame = cap.read()
        if ret:
            #converting BGR (OpenCV) to RGB (PIL)
            rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            frames.append(Image.fromarray(rgb))

    cap.release()
    logger.info(f"Extracted {len(frames)} frames from video ({total_frames} total frames).")
    return frames


#main moderation entry point

def moderate_post(caption: str | None, media_files: list) -> NSFWResult:
    """
    Run full moderation on a post.
    media_files: list of dicts with keys 'path' (str) and 'is_video' (bool)
    Returns the worst NSFWResult found (BLOCK > REVIEW > PASS).
    """
    results: list[NSFWResult] = []

    #text check
    if caption:
        text_result = NSFWTextClassifier.classify(caption)
        results.append(text_result)
        #no need to check media if already blocking
        if text_result.verdict == NSFWVerdict.BLOCK:
            return text_result

    #media checks
    for media in media_files:
        path = media.get('path')
        is_video = media.get('is_video', False)

        if not path or not os.path.exists(path):
            continue

        if is_video:
            try:
                frames = _extract_frames(path)
                for frame in frames:
                    result = NSFWImageClassifier.classify_image(frame)
                    results.append(result)
                    if result.verdict == NSFWVerdict.BLOCK:
                        return result
            except Exception as e:
                logger.error(f"Video moderation error for {path}: {e}")
        else:
            try:
                image = Image.open(path).convert("RGB")
                result = NSFWImageClassifier.classify_image(image)
                results.append(result)
                if result.verdict == NSFWVerdict.BLOCK:
                    return result
            except Exception as e:
                logger.error(f"Image moderation error for {path}: {e}")

    #return worst verdict
    if any(r.verdict == NSFWVerdict.BLOCK for r in results):
        return next(r for r in results if r.verdict == NSFWVerdict.BLOCK)
    if any(r.verdict == NSFWVerdict.REVIEW for r in results):
        return next(r for r in results if r.verdict == NSFWVerdict.REVIEW)

    if results:
        return results[0]

    return NSFWResult(
        verdict=NSFWVerdict.PASS, 
        score=0.0, 
        label="clean", 
        model_used="none", 
        reason="No content to moderate."
    )