"""tools.shelf.logging_utils - Structured logging and error handling"""

import logging
import json
import sys
import traceback
from datetime import datetime
from typing import Any, Dict, Optional
from functools import wraps
import time


class JSONFormatter(logging.Formatter):
    """JSON log formatter for structured logging."""
    
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
        }
        
        # Add extra fields if present
        for key, value in record.__dict__.items():
            if key not in ['name', 'msg', 'args', 'created', 'filename', 'funcName', 
                          'levelname', 'levelno', 'lineno', 'module', 'msecs', 
                          'message', 'msg', 'name', 'pathname', 'process', 
                          'processName', 'relativeCreated', 'thread', 'threadName',
                          'exc_info', 'exc_text', 'stack_info']:
                log_data[key] = value
        
        # Add exception info if present
        if record.exc_info:
            log_data["exception"] = {
                "type": record.exc_info[0].__name__,
                "message": str(record.exc_info[1]),
                "traceback": traceback.format_exception(*record.exc_info),
            }
        
        return json.dumps(log_data, ensure_ascii=False)


def setup_logger(
    name: str = "shelf_scanner",
    level: int = logging.INFO,
    json_format: bool = True,
    output_file: Optional[str] = None,
) -> logging.Logger:
    """Setup structured logger."""
    logger = logging.getLogger(name)
    logger.setLevel(level)
    logger.handlers.clear()
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    if json_format:
        console_handler.setFormatter(JSONFormatter())
    else:
        console_handler.setFormatter(
            logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        )
    logger.addHandler(console_handler)
    
    # File handler
    if output_file:
        file_handler = logging.FileHandler(output_file, encoding='utf-8')
        file_handler.setFormatter(JSONFormatter())
        logger.addHandler(file_handler)
    
    return logger


# Global logger instance
_logger = None

def get_logger(name: str = "shelf_scanner") -> logging.Logger:
    """Get or create global logger."""
    global _logger
    if _logger is None:
        _logger = setup_logger(name)
    return _logger


class ScanError(Exception):
    """Base exception for scan errors."""
    def __init__(self, message: str, error_code: str = "SCAN_ERROR", details: Optional[Dict] = None):
        super().__init__(message)
        self.error_code = error_code
        self.details = details or {}


class ModelLoadError(ScanError):
    """Model loading failed."""
    def __init__(self, message: str, details: Optional[Dict] = None):
        super().__init__(message, "MODEL_LOAD_ERROR", details)


class OCRError(ScanError):
    """OCR processing failed."""
    def __init__(self, message: str, details: Optional[Dict] = None):
        super().__init__(message, "OCR_ERROR", details)


class MatchingError(ScanError):
    """Price-product matching failed."""
    def __init__(self, message: str, details: Optional[Dict] = None):
        super().__init__(message, "MATCHING_ERROR", details)


class ExportError(ScanError):
    """Export failed."""
    def __init__(self, message: str, details: Optional[Dict] = None):
        super().__init__(message, "EXPORT_ERROR", details)


def log_execution_time(logger: Optional[logging.Logger] = None):
    """Decorator to log function execution time."""
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            log = logger or get_logger(func.__module__)
            start = time.perf_counter()
            try:
                result = func(*args, **kwargs)
                elapsed = time.perf_counter() - start
                log.info(
                    f"{func.__name__} completed",
                    extra={
                        "function": func.__name__,
                        "duration_ms": round(elapsed * 1000, 2),
                        "status": "success",
                    }
                )
                return result
            except Exception as e:
                elapsed = time.perf_counter() - start
                log.error(
                    f"{func.__name__} failed: {e}",
                    extra={
                        "function": func.__name__,
                        "duration_ms": round(elapsed * 1000, 2),
                        "status": "error",
                        "error_type": type(e).__name__,
                    },
                    exc_info=True
                )
                raise
        return wrapper
    return decorator


class TimeoutGuard:
    """Context manager for operation timeout."""
    
    def __init__(self, timeout_seconds: float, operation_name: str = "operation"):
        self.timeout_seconds = timeout_seconds
        self.operation_name = operation_name
        self.start_time = None
    
    def __enter__(self):
        self.start_time = time.perf_counter()
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        elapsed = time.perf_counter() - self.start_time
        if elapsed > self.timeout_seconds:
            raise TimeoutError(
                f"{self.operation_name} timed out after {elapsed:.2f}s "
                f"(limit: {self.timeout_seconds}s)"
            )
        return False


class RetryPolicy:
    """Retry policy with exponential backoff."""
    
    def __init__(
        self,
        max_retries: int = 3,
        base_delay: float = 1.0,
        max_delay: float = 30.0,
        exponential_base: float = 2.0,
        exceptions: tuple = (Exception,),
    ):
        self.max_retries = max_retries
        self.base_delay = base_delay
        self.max_delay = max_delay
        self.exponential_base = exponential_base
        self.exceptions = exceptions
    
    def execute(self, func, *args, **kwargs):
        """Execute function with retry policy."""
        last_exception = None
        
        for attempt in range(self.max_retries + 1):
            try:
                return func(*args, **kwargs)
            except self.exceptions as e:
                last_exception = e
                if attempt < self.max_retries:
                    delay = min(
                        self.base_delay * (self.exponential_base ** attempt),
                        self.max_delay
                    )
                    logger = get_logger(__name__)
                    logger.warning(
                        f"Attempt {attempt + 1} failed: {e}. Retrying in {delay:.1f}s",
                        extra={
                            "attempt": attempt + 1,
                            "max_retries": self.max_retries,
                            "delay_seconds": delay,
                        }
                    )
                    time.sleep(delay)
                else:
                    logger = get_logger(__name__)
                    logger.error(
                        f"All {self.max_retries + 1} attempts failed",
                        extra={
                            "max_retries": self.max_retries,
                            "last_error": str(last_exception),
                        },
                        exc_info=True
                    )
                    raise


# Default retry policies
MODEL_LOAD_RETRY = RetryPolicy(max_retries=2, base_delay=2.0)
OCR_RETRY = RetryPolicy(max_retries=3, base_delay=0.5)
EXPORT_RETRY = RetryPolicy(max_retries=2, base_delay=1.0)


def safe_execute(
    func,
    *args,
    default=None,
    logger: Optional[logging.Logger] = None,
    error_message: str = "Operation failed",
    **kwargs,
):
    """Execute function safely with error handling."""
    log = logger or get_logger(__name__)
    try:
        return func(*args, **kwargs)
    except Exception as e:
        log.error(
            error_message,
            extra={
                "error": str(e),
                "error_type": type(e).__name__,
                "function": func.__name__,
            },
            exc_info=True
        )
        return default