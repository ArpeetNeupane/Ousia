import logging
from core.utils.nsfw_classifier import NSFWTextClassifier, NSFWVerdict, NSFWResult

logger = logging.getLogger(__name__)


def moderate_message(content: str) -> NSFWResult:
    """
    Moderate a message using the NSFW text classifier.
    
    Args:
        content (str): The message content to moderate
        
    Returns:
        NSFWResult: Contains verdict (PASS/REVIEW/BLOCK), score, label, model, and reason
        
    Example:
        result = moderate_message("Hello, how are you?")
        if result.verdict == NSFWVerdict.BLOCK:
            # Handle blocked message
            pass
    """
    if not content or not content.strip():
        return NSFWResult(
            verdict=NSFWVerdict.PASS,
            score=0.0,
            label="clean",
            model_used="none",
            reason="Empty message."
        )
    
    try:
        result = NSFWTextClassifier.classify(content)
        logger.info(f"Message moderation - Verdict: {result.verdict.value}, Score: {result.score:.3f}")
        return result
    except Exception as e:
        logger.error(f"Error during message moderation: {e}")
        # Return a conservative result - flag for review if error occurs
        return NSFWResult(
            verdict=NSFWVerdict.REVIEW,
            score=0.0,
            label="error",
            model_used="none",
            reason=f"Moderation error: {str(e)}"
        )


def should_block_message(content: str) -> bool:
    """
    Check if a message should be blocked based on moderation.
    
    Args:
        content (str): The message content to check
        
    Returns:
        bool: True if the message should be blocked, False otherwise
    """
    result = moderate_message(content)
    return result.verdict == NSFWVerdict.BLOCK


def should_review_message(content: str) -> bool:
    """
    Check if a message should be flagged for review.
    
    Args:
        content (str): The message content to check
        
    Returns:
        bool: True if the message should be reviewed, False otherwise
    """
    result = moderate_message(content)
    return result.verdict == NSFWVerdict.REVIEW


def get_moderation_result(content: str) -> dict:
    """
    Get detailed moderation result for a message.
    
    Args:
        content (str): The message content to moderate
        
    Returns:
        dict: Contains 'verdict', 'score', 'label', 'model_used', and 'reason'
    """
    result = moderate_message(content)
    return {
        'verdict': result.verdict.value,
        'score': result.score,
        'label': result.label,
        'model_used': result.model_used,
        'reason': result.reason
    }