import os, re, logging, unicodedata
from dataclasses import dataclass
from enum import Enum
from transformers import pipeline

logger = logging.getLogger(__name__)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
TEXT_SMALL_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../ML Models", "Text Small")
)

TEXT_LARGE_PATH = os.path.abspath(
    os.path.join(BASE_DIR, "../../ML Models", "Text Large")
)

BLOCK_THRESHOLD = 0.85
REVIEW_THRESHOLD = 0.50

'''
GROOMING_PATTERNS = [
    # secrecy
    "don't tell your parents",
    "don't tell anyone",
    "keep this secret",
    "our little secret",
    "just between us",
    "no one needs to know",
    "promise you won't tell",
    "don't tell your mom",
    "don't tell your dad",
    "this stays between us",

    # isolation
    "are you alone",
    "is anyone home",
    "are your parents home",
    "are your parents around",
    "are you by yourself",
    "is anyone watching",
    "can you talk privately",
    "can we talk in private",
    "find somewhere private",
    "go somewhere private",

    # moving platforms
    "move to whatsapp",
    "move to telegram",
    "move to snapchat",
    "move to discord",
    "move to instagram",
    "talk somewhere else",
    "chat somewhere private",
    "use another app",
    "switch apps",
    "delete the chat after",

    # secrecy manipulation
    "you can trust me",
    "trust me with this",
    "i won't tell anyone",
    "i promise i won't tell",
    "this is just between us",
    "no one else will understand",
    "they wouldn't get it",
    "adults wouldn't understand",
    "they would overreact",

    # grooming compliments
    "you're mature for your age",
    "you're very mature",
    "you're different from other kids",
    "you're special",
    "you're special to me",
    "you're my favorite",
    "you're not like other kids",
    "you understand me better",

    # emotional manipulation
    "you mean a lot to me",
    "i care about you more",
    "i like talking to you",
    "i miss talking to you",
    "i need you",
    "you're the only one who understands",
    "i feel close to you",
    "you make me happy",

    # secrecy reinforcement
    "don't show this to anyone",
    "delete this message",
    "delete our chat",
    "erase the messages",
    "clear the chat",
    "make sure nobody sees",
    "hide this conversation",

    # photo requests
    "send me a pic",
    "send me a picture",
    "send a photo",
    "send me your photo",
    "show me a picture",
    "take a pic for me",
    "can i see you",
    "show me what you look like",
    "send a selfie",
    "take a selfie",

    # body requests
    "show me your body",
    "show me your outfit",
    "show me what you're wearing",
    "let me see you",
    "turn on your camera",
    "start video",
    "video call me",
    "facetime me",

    # escalating privacy
    "go to your room",
    "go somewhere private",
    "lock your door",
    "make sure nobody comes in",
    "wait until they're gone",
    "when your parents leave",
    "when you're alone",

    # testing boundaries
    "have you ever done this before",
    "do you keep secrets",
    "are you good at keeping secrets",
    "can you keep a secret",
    "do you trust me",
    "do you like me",

    # manipulation
    "don't worry about rules",
    "rules don't apply to us",
    "you're old enough",
    "you're basically an adult",
    "age doesn't matter",
    "age is just a number",

    # dependence
    "i need you",
    "i miss you when you're gone",
    "talk to me every day",
    "don't ignore me",
    "i think about you all the time",
]
'''

GROOMING_REGEX_PATTERNS = [
    # Secrecy
    r"(don't|dont|do not)\s+tell\s+(your\s+)?(mom|dad|mother|father|parents|anyone|nobody)",
    r"keep\s+(this\s+|it\s+)?(a\s+)?secret",
    r"our\s+little\s+secret",
    r"just\s+between\s+(us|you\s+and\s+me)",
    r"(no\s+one|nobody)\s+(needs\s+to|has\s+to|should)\s+know",
    r"(don't|dont|do not)\s+tell\s+anyone",
    r"this\s+stays\s+between\s+us",
    r"promise\s+(me\s+)?(you\s+)?(won't|wont|will not)\s+tell",

    # Isolation check
    r"are\s+you\s+(alone|by\s+yourself)",
    r"is\s+anyone\s+(home|there|around|with\s+you)",
    r"are\s+your\s+(parents|mom|dad|mother|father)\s+(home|around|there|nearby)",
    r"(where\s+are\s+your\s+parents|where'?s\s+your\s+(mom|dad|mother|father))",
    r"are\s+you\s+(home\s+)?alone",

    # Platform migration
    r"(move|switch|talk|chat|message|contact)\s+(me\s+)?(to|on|over\s+to|via|through)\s+(whatsapp|telegram|snapchat|discord|instagram|kik|signal|wechat|line|viber)",
    r"(talk|chat|speak|message)\s+(somewhere\s+)?(else|private|privately)",
    r"(add|find)\s+me\s+on\s+(whatsapp|telegram|snapchat|discord|instagram|kik|signal)",
    r"(my\s+)?(snap|insta|discord|telegram|kik)\s+(is|username|handle|id)",

    # Image solicitation
    r"send\s+(me\s+)?(a\s+)?(pic|picture|photo|selfie|nude|nudes|image|img|snap)",
    r"show\s+me\s+(a\s+)?(pic|picture|photo|yourself|your\s+face)",
    r"(can\s+i|let\s+me)\s+see\s+(you|a\s+pic|a\s+photo|a\s+picture)",
    r"(take|send)\s+(a\s+)?(selfie|pic|photo|picture)\s+(for\s+me|to\s+me)",
    r"(share|post)\s+(a\s+)?(pic|photo|picture|selfie)\s+(with\s+me|for\s+me)",

    # Physical appearance
    r"what\s+(are\s+you|r\s+u)\s+wearing",
    r"show\s+me\s+(your\s+)?(body|outfit|clothes|figure|shape)",
    r"(describe|tell\s+me)\s+what\s+you('?re|\s+are)\s+wearing",

    # Video/camera
    r"(turn\s+on|enable)\s+(your\s+)?(camera|cam|webcam)",
    r"(video\s+call|facetime|vc|video\s+chat)\s+(me|with\s+me)",
    r"(hop|get|jump)\s+on\s+(a\s+)?(call|vc|video\s+call|facetime)",

    # Physical isolation
    r"go\s+(somewhere\s+)?(private|alone|to\s+your\s+room)",
    r"(lock|close)\s+(your\s+)?(door|room)",
    r"go\s+to\s+(your\s+)?(bedroom|room|bathroom)",
    r"(make sure|ensure)\s+(no\s+one|nobody)\s+(can\s+see|is\s+watching|is\s+around)",

    # Maturity/grooming compliments
    r"you'?re?\s+(so\s+|very\s+|really\s+|quite\s+)?mature\s+(for\s+your\s+age)?",
    r"you'?re?\s+(so\s+|very\s+|really\s+)?different\s+from\s+(other\s+)?(kids|children|girls|boys|teens)",
    r"you\s+(seem|act|look)\s+(so\s+|very\s+|really\s+)?(old|grown\s+up|mature)",
    r"(most|other)\s+(kids|children|girls|boys|teens)\s+(aren'?t|are\s+not|don'?t)\s+(like\s+you|as\s+mature)",
    r"you'?re?\s+(not\s+like|different\s+from)\s+(other\s+)?(kids|children|girls|boys|teens)",

    # Secret keeping
    r"(can\s+you|do\s+you)\s+keep\s+(a\s+)?secret",
    r"(are\s+you|r\s+u)\s+good\s+at\s+keeping\s+secrets",
    r"(i\s+)?(trust|trusted)\s+you\s+(with\s+this|to\s+keep)",

    # Age minimization
    r"age\s+is\s+(just|only)\s+(a\s+)?number",
    r"(age\s+doesn'?t|age\s+does\s+not)\s+matter",
    r"(you'?re?|ur)\s+(old\s+enough|mature\s+enough)",
    r"(love\s+knows|feelings?\s+(don'?t|does\s+not)\s+care)\s+(no\s+)?age",

    # Meeting up
    r"(let'?s|lets|we\s+should)\s+(meet\s+up|hang\s+out|get\s+together)\s+(alone|just\s+us|in\s+person)",
    r"(don't|dont)\s+tell\s+anyone\s+(about\s+)?(us|our\s+meet|our\s+plans)",
    r"(come|sneak)\s+(over|out)\s+(when|after|without)\s+(your\s+)?(parents|mom|dad|are\s+asleep|are\s+away)",

    # Gifts/bribes
    r"(i('?ll|\s+will)|i\s+can)\s+(buy|get|send|give)\s+you\s+(gifts?|money|stuff|things|presents?)",
    r"(i\s+)?(bought|got|have)\s+(something|a\s+gift|a\s+present)\s+for\s+you",
]

#compiling at once so that it's faster for multiple API requests
GROOMING_REGEX = [re.compile(p, re.IGNORECASE) for p in GROOMING_REGEX_PATTERNS]
GROOMING_REGEX_LOOSE = [
    re.compile(re.sub(r'\\s\+', r'\\s*', p), re.IGNORECASE) 
    for p in GROOMING_REGEX_PATTERNS
]

def _normalize(text: str) -> str:
    text = text.lower()
    #normalizing unicode (e.g. accented chars, lookalike chars)
    text = unicodedata.normalize('NFKD', text)
    #removing all whitespace
    no_space = re.sub(r'\s+', '', text)
    return no_space

def _insert_optional_spaces(pattern: str) -> str:
    #rewriting pattern to allow zero or more spaces between every character sequence by replacing \s+ with \s* throughout
    return pattern.replace(r'\s+', r'\s*')


class NSFWVerdict(Enum):
    PASS = "pass"
    REVIEW = "review"
    BLOCK = "block"


@dataclass
#a decorator from Python’s Python module dataclasses that automatically generates common class methods like __init__ and __repr__
class NSFWResult:
    verdict: NSFWVerdict
    score: float
    label: str
    model_used: str
    reason: str


class NSFWTextClassifier:
    _small_pipeline = None
    _large_pipeline = None
    _loaded = False

    @classmethod
    def _load_models(cls):
        #ensureing models load only once
        if cls._loaded:
            return
        try:
            logger.info("Loading Text Small (DistilBERT) NSFW model...")
            cls._small_pipeline = pipeline(
                "text-classification",
                model=TEXT_SMALL_PATH,
                tokenizer=TEXT_SMALL_PATH,
                device=0,  #0 is GPU, 1 is GPU2, -1 force CPU
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
        """Normalize label names across different model conventions."""
        label_lower = label.lower()
        nsfw_keywords = [
            "nsfw",
            "unsafe",
            "explicit",
            "adult",
            "toxic",
            "offensive",
            "hate",
            "threat",
            "insult",
            "harassment",
            "sexual",
            "violence"
        ]
        return any(k in label_lower for k in nsfw_keywords)

    @classmethod
    def _run_pipeline(cls, pipe, text: str) -> tuple[float, str]:
        """Returns (nsfw_score, label)."""
        results = pipe(text, top_k=None)  #getting all labels
        #finding the NSFW label score
        for r in results:
            if cls._is_nsfw_label(r["label"]):
                return r["score"], r["label"]
        #if no NSFW label found, treating highest score non-safe label
        #falling back to top result
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
                reason="Empty caption.",
            )

        #checking for grooming patterns
        lower_text = text.lower()
        normalized_text = _normalize(text) #no spaces, lowercased

        for strict, loose in zip(GROOMING_REGEX, GROOMING_REGEX_LOOSE):
            if strict.search(lower_text) or loose.search(normalized_text):
                return NSFWResult(
                    verdict=NSFWVerdict.BLOCK,
                    score=0.99,
                    label="grooming_pattern",
                    model_used="rule_engine",
                    reason=f"Grooming pattern matched."
                )

        if cls._small_pipeline is None:
            logger.warning("Text Small model unavailable, skipping text NSFW check.")
            return NSFWResult(
                verdict=NSFWVerdict.PASS,
                score=0.0,
                label="unknown",
                model_used="none",
                reason="Model unavailable.",
            )

        #running small model first
        try:
            score, label = cls._run_pipeline(cls._small_pipeline, text)
        except Exception as e:
            logger.error(f"Text Small inference error: {e}")
            return NSFWResult(
                verdict=NSFWVerdict.PASS,
                score=0.0,
                label="unknown",
                model_used="text_small",
                reason=f"Inference error: {e}",
            )

        is_nsfw = cls._is_nsfw_label(label)

        #if small model is confident enough, returning immediately
        if is_nsfw and score >= BLOCK_THRESHOLD:
            return NSFWResult(
                verdict=NSFWVerdict.BLOCK,
                score=score,
                label=label,
                model_used="text_small",
                reason=f"High confidence NSFW detected (score={score:.3f}).",
            )

        if is_nsfw and score >= REVIEW_THRESHOLD:
            #if not confident enough, escalate to large model if available
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
                            reason=f"Large model high confidence NSFW (score={large_score:.3f}).",
                        )
                    elif is_nsfw_large and large_score >= REVIEW_THRESHOLD:
                        return NSFWResult(
                            verdict=NSFWVerdict.REVIEW,
                            score=large_score,
                            label=large_label,
                            model_used="text_large",
                            reason=f"Large model flagged for review (score={large_score:.3f}).",
                        )
                    else:
                        return NSFWResult(
                            verdict=NSFWVerdict.PASS,
                            score=large_score,
                            label=large_label,
                            model_used="text_large",
                            reason=f"Large model cleared content (score={large_score:.3f}).",
                        )
                except Exception as e:
                    logger.error(f"Text Large inference error: {e}")
                    #falling back to small model result
                    return NSFWResult(
                        verdict=NSFWVerdict.REVIEW,
                        score=score,
                        label=label,
                        model_used="text_small",
                        reason=f"Large model error, flagging cautiously (score={score:.3f}).",
                    )
            else:
                #if no large model, flag for review based on small model alone
                return NSFWResult(
                    verdict=NSFWVerdict.REVIEW,
                    score=score,
                    label=label,
                    model_used="text_small",
                    reason=f"Uncertain NSFW score, flagged for review (score={score:.3f}).",
                )

        #if score below review threshold, pass
        return NSFWResult(
            verdict=NSFWVerdict.PASS,
            score=score,
            label=label,
            model_used="text_small",
            reason=f"Content cleared (score={score:.3f}).",
        )