from __future__ import annotations

from dataclasses import asdict, dataclass
from enum import Enum
from typing import Any


class Game(str, Enum):
    GENSHIN = "genshin"
    STARRAIL = "starrail"
    ZZZ = "zzz"


@dataclass(frozen=True)
class ApiError(Exception):
    retcode: int | None
    message: str
    payload: dict[str, Any] | None = None

    def __str__(self) -> str:
        code = "unknown" if self.retcode is None else str(self.retcode)
        return f"miHoYo API error {code}: {self.message}"


@dataclass(frozen=True)
class LoginTokens:
    account_id: str
    stoken_v2: str
    mid: str
    cookie_token: str
    ltoken: str | None = None
    device_id: str | None = None
    device_fp: str | None = None

    @property
    def stoken_cookie(self) -> str:
        return f"stuid={self.account_id};stoken={self.stoken_v2};mid={self.mid}"

    @property
    def cookie(self) -> str:
        return (
            f"account_id={self.account_id};"
            f"stuid={self.account_id};"
            f"stoken_v2={self.stoken_v2};"
            f"stoken={self.stoken_v2};"
            f"mid={self.mid};"
            f"cookie_token={self.cookie_token};"
            f"ltuid={self.account_id};"
            f"ltuid_v2={self.account_id};"
            f"ltmid_v2={self.mid}"
        )
        if self.ltoken:
            base += f";ltoken={self.ltoken};ltoken_v2={self.ltoken}"
        if self.device_fp:
            base += f";DEVICEFP={self.device_fp}"
        return base


@dataclass(frozen=True)
class BoundRole:
    game: Game
    game_biz: str
    game_uid: str
    region: str
    nickname: str
    level: int | None
    raw: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        data = asdict(self)
        data["game"] = self.game.value
        return data


@dataclass(frozen=True)
class DailyStatus:
    game: Game
    stamina_name: str
    current_stamina: int | None
    max_stamina: int | None
    stamina_recover_seconds: int | None
    daily_name: str
    daily_current: int | None
    daily_max: int | None
    daily_done: bool | None
    extra: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        data = asdict(self)
        data["game"] = self.game.value
        return data


@dataclass(frozen=True)
class NoteResult:
    role: BoundRole
    status: DailyStatus
    raw: dict[str, Any]

    def to_json(self) -> dict[str, Any]:
        return {
            "role": self.role.to_json(),
            "status": self.status.to_json(),
            "raw": self.raw,
        }
