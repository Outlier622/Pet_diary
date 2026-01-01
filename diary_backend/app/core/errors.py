class AppError(Exception):
    def __init__(self, code: str, message: str, details: dict | None = None, status: int = 400):
        super().__init__(message)
        self.code = code
        self.message = message
        self.details = details
        self.status = status
