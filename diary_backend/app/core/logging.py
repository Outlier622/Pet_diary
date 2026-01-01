import logging

def get_logger() -> logging.Logger:
    logger = logging.getLogger("diary")
    if logger.handlers:
        return logger

    logger.setLevel(logging.INFO)
    h = logging.StreamHandler()
    fmt = logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s")
    h.setFormatter(fmt)
    logger.addHandler(h)
    return logger
