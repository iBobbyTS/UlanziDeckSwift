"""Minimal miHoYo/Miyoushe note client used before Swift integration."""

from .auth import LoginSession, QRLoginClient
from .client import MiyousheClient
from .models import (
    ApiError,
    BoundRole,
    DailyStatus,
    Game,
    LoginTokens,
    NoteResult,
)

__all__ = [
    "ApiError",
    "BoundRole",
    "DailyStatus",
    "Game",
    "LoginSession",
    "LoginTokens",
    "MiyousheClient",
    "NoteResult",
    "QRLoginClient",
]
