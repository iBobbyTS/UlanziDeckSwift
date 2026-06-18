from __future__ import annotations

from typing import Any, Iterable, Mapping

from .cookies import cookie_header
from .crypto import MYS_VERSION, ds_token, random_device_id, random_hex
from .http import HttpClient
from .models import ApiError, BoundRole, DailyStatus, Game, NoteResult


RECORD_BASE = "https://api-takumi-record.mihoyo.com"
OLD_BASE = "https://api-takumi.mihoyo.com"
PASSPORT_BIND_BASE = "https://passport-api.mihoyo.com"

BIND_ROLES_URL = f"{OLD_BASE}/binding/api/getUserGameRolesByCookie"
BIND_ROLES_COOKIE_TOKEN_URL = f"{PASSPORT_BIND_BASE}/binding/api/getUserGameRolesByCookieToken"

NOTE_URLS = {
    Game.GENSHIN: f"{RECORD_BASE}/game_record/app/genshin/api/dailyNote",
    Game.STARRAIL: f"{RECORD_BASE}/game_record/app/hkrpg/api/note",
    Game.ZZZ: f"{RECORD_BASE}/event/game_record_zzz/api/zzz/note",
}

WIDGET_URLS = {
    Game.GENSHIN: f"{RECORD_BASE}/game_record/genshin/aapi/widget/v2",
    Game.STARRAIL: f"{RECORD_BASE}/game_record/app/hkrpg/aapi/widget",
    Game.ZZZ: f"{RECORD_BASE}/event/game_record_zzz/api/zzz/widget",
}

GAME_BY_BIZ = {
    "hk4e_cn": Game.GENSHIN,
    "hkrpg_cn": Game.STARRAIL,
    "nap_cn": Game.ZZZ,
}


class MiyousheClient:
    def __init__(
        self,
        cookies: Mapping[str, str] | str,
        *,
        device_id: str | None = None,
        device_fp: str | None = None,
        http: HttpClient | None = None,
    ):
        cookie_map: Mapping[str, str] | None = cookies if not isinstance(cookies, str) else None
        if isinstance(cookies, str):
            self.cookie = cookies
        else:
            self.cookie = cookie_header(cookies)
        self.device_id = device_id or _cookie_device_id(cookie_map) or random_device_id()
        self.device_fp = device_fp or _cookie_device_fp(cookie_map) or random_hex(13)
        self.http = http or HttpClient()

    def _headers(
        self,
        query: str = "",
        body: Any = None,
        *,
        app_version: str = MYS_VERSION,
        referer: str = "https://webstatic.mihoyo.com/",
        origin: str = "https://webstatic.mihoyo.com/",
        page: str | None = None,
    ) -> dict[str, str]:
        headers = {
            "x-rpc-app_version": app_version,
            "X-Requested-With": "com.mihoyo.hyperion",
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 13; PHK110 Build/SKQ1.221119.001; wv)"
                f" AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.133 Mobile Safari/537.36 miHoYoBBS/{app_version}"
            ),
            "x-rpc-client_type": "5",
            "x-rpc-device_id": self.device_id,
            "x-rpc-device_fp": self.device_fp,
            "x-rpc-device_name": "OPPO PHK110",
            "x-rpc-device_model": "PHK110",
            "x-rpc-platform": "2",
            "x-rpc-sys_version": "13",
            "Referer": referer,
            "Origin": origin,
            "DS": ds_token(query, body),
            "Cookie": self.cookie,
        }
        if page:
            headers["x-rpc-page"] = page
        return headers

    def _zzz_headers(self, query: str = "") -> dict[str, str]:
        app_version = "2.40.1"
        return {
            "Cookie": self.cookie,
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 12; Mi 10 Build/SKQ1.221119.001; wv) "
                "AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/111.0.5563.116 "
                f"Mobile Safari/537.36 miHoYoBBS/{app_version}"
            ),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com",
            "x-rpc-app_version": app_version,
            "x-rpc-client_type": "5",
            "x-rpc-device_id": self.device_id,
            "x-rpc-device_fp": self.device_fp,
            "DS": ds_token(query),
        }

    def _api_get(
        self,
        url: str,
        *,
        params: dict[str, Any] | None = None,
        headers: dict[str, str] | None = None,
    ) -> dict[str, Any]:
        payload = self.http.request_json("GET", url, headers=headers, params=params)
        retcode = int(payload.get("retcode", -1))
        if retcode != 0:
            raise ApiError(retcode, str(payload.get("message", "")), payload)
        return payload

    def bound_roles(self) -> list[BoundRole]:
        payload = self._get_bound_roles_payload()
        roles = payload.get("data", {}).get("list") or []
        parsed = []
        for role in roles:
            game_biz = str(role.get("game_biz") or "")
            game = GAME_BY_BIZ.get(game_biz)
            if game is None:
                continue
            game_uid = str(role.get("game_uid") or role.get("game_role_id") or "")
            region = str(role.get("region") or role.get("region_name") or role.get("server") or "")
            if not game_uid or not region:
                continue
            level = role.get("level")
            parsed.append(
                BoundRole(
                    game=game,
                    game_biz=game_biz,
                    game_uid=game_uid,
                    region=region,
                    nickname=str(role.get("nickname") or ""),
                    level=int(level) if isinstance(level, int | str) and str(level).isdigit() else None,
                    raw=role,
                )
            )
        return parsed

    def _get_bound_roles_payload(self) -> dict[str, Any]:
        headers = self._headers("game_biz=")
        try:
            return self._api_get(BIND_ROLES_URL, params={"game_biz": ""}, headers=headers)
        except ApiError:
            return self._api_get(BIND_ROLES_COOKIE_TOKEN_URL, params={"game_biz": ""}, headers=headers)

    def find_role(self, game: Game, uid: str | None = None) -> BoundRole:
        matches = [role for role in self.bound_roles() if role.game is game and (uid is None or role.game_uid == uid)]
        if not matches:
            label = game.value if uid is None else f"{game.value}:{uid}"
            raise ApiError(None, f"no bound role found for {label}")
        return matches[0]

    def note(self, role: BoundRole) -> NoteResult:
        params = {"role_id": role.game_uid, "server": role.region}
        query = f"role_id={role.game_uid}&server={role.region}"
        if role.game is Game.ZZZ:
            headers = self._zzz_headers(query)
        else:
            headers = self._headers(query)
        source = "record"
        try:
            payload = self._api_get(NOTE_URLS[role.game], params=params, headers=headers)
        except ApiError:
            payload = self._widget_note(role)
            source = "widget"
        data = payload.get("data") or {}
        return NoteResult(role=role, status=self._daily_status(role.game, data, source=source), raw=payload)

    def _widget_note(self, role: BoundRole) -> dict[str, Any]:
        if role.game is Game.GENSHIN:
            headers = self._headers()
            headers["DS"] = ds_token()
            headers["x-rpc-channel"] = "miyousheluodi"
            return self._api_get(WIDGET_URLS[role.game], params={"game_id": 2}, headers=headers)
        if role.game is Game.STARRAIL:
            headers = self._headers()
            headers["DS"] = ds_token()
            headers["x-rpc-channel"] = "beta"
            headers["Referer"] = "https://app.mihoyo.com"
            headers["User-Agent"] = "okhttp/4.8.0"
            return self._api_get(WIDGET_URLS[role.game], headers=headers)
        headers = self._headers()
        headers["DS"] = ds_token()
        headers["x-rpc-page"] = "v1.0.14_#/zzz"
        headers["x-rpc-platform"] = "2"
        return self._api_get(WIDGET_URLS[role.game], headers=headers)

    def notes(self, games: Iterable[Game] | None = None) -> list[NoteResult]:
        wanted = set(games or list(Game))
        return [self.note(role) for role in self.bound_roles() if role.game in wanted]

    def _daily_status(self, game: Game, data: dict[str, Any], *, source: str = "record") -> DailyStatus:
        source_extra = _source_extra(source)
        if game is Game.GENSHIN:
            finished = _int_or_none(data.get("finished_task_num"))
            total = _int_or_none(data.get("total_task_num")) or 4
            claimed = data.get("is_extra_task_reward_received")
            return DailyStatus(
                game=game,
                stamina_name="树脂",
                current_stamina=_int_or_none(data.get("current_resin")),
                max_stamina=_int_or_none(data.get("max_resin")),
                stamina_recover_seconds=_int_or_none(data.get("resin_recovery_time")),
                daily_name="每日委托",
                daily_current=finished,
                daily_max=total,
                daily_done=bool(claimed) if isinstance(claimed, bool) else (finished == total if finished is not None else None),
                extra={
                    **source_extra,
                    "is_extra_task_reward_received": claimed,
                    "daily_task": data.get("daily_task"),
                    "current_home_coin": data.get("current_home_coin"),
                    "max_home_coin": data.get("max_home_coin"),
                    "current_expedition_num": data.get("current_expedition_num"),
                    "max_expedition_num": data.get("max_expedition_num"),
                },
            )
        if game is Game.STARRAIL:
            current = _int_or_none(data.get("current_train_score"))
            maximum = _int_or_none(data.get("max_train_score"))
            return DailyStatus(
                game=game,
                stamina_name="开拓力",
                current_stamina=_int_or_none(data.get("current_stamina")),
                max_stamina=_int_or_none(data.get("max_stamina")),
                stamina_recover_seconds=_int_or_none(data.get("stamina_recover_time")),
                daily_name="每日实训",
                daily_current=current,
                daily_max=maximum,
                daily_done=current == maximum if current is not None and maximum is not None else None,
                extra={
                    **source_extra,
                    "current_reserve_stamina": data.get("current_reserve_stamina"),
                    "accepted_expedition_num": data.get("accepted_expedition_num") or data.get("accepted_epedition_num"),
                    "total_expedition_num": data.get("total_expedition_num"),
                    "current_rogue_score": data.get("current_rogue_score"),
                    "max_rogue_score": data.get("max_rogue_score"),
                },
            )

        energy = data.get("energy") or {}
        progress = energy.get("progress") or {}
        vitality = data.get("vitality") or {}
        card_sign = data.get("card_sign")
        commission = data.get("bounty_commission") or data.get("s2_bounty_commission") or {}
        survey = data.get("survey_points") or {}
        weekly = data.get("weekly_task") or {}
        daily_current = _int_or_none(vitality.get("current"))
        daily_max = _int_or_none(vitality.get("max"))
        return DailyStatus(
            game=game,
            stamina_name="电量",
            current_stamina=_int_or_none(progress.get("current")),
            max_stamina=_int_or_none(progress.get("max")),
            stamina_recover_seconds=_int_or_none(energy.get("restore")),
            daily_name="活跃度",
            daily_current=daily_current,
            daily_max=daily_max,
            daily_done=(daily_current == daily_max if daily_current is not None and daily_max is not None else None),
            extra={
                **source_extra,
                "bounty_commission": commission,
                "card_sign": card_sign,
                "card_sign_done": "Done" in card_sign if isinstance(card_sign, str) else None,
                "survey_points": survey,
                "weekly_task": weekly,
                "vhs_sale": data.get("vhs_sale"),
            },
        )


def _int_or_none(value: Any) -> int | None:
    if isinstance(value, bool) or value is None:
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _source_extra(source: str) -> dict[str, Any]:
    return {
        "source": source,
        "stamina_may_be_capped_by_source": source == "widget",
    }


def _cookie_device_fp(cookies: Mapping[str, str] | None) -> str | None:
    if not cookies:
        return None
    return cookies.get("DEVICEFP") or cookies.get("device_fp") or cookies.get("x-rpc-device_fp")


def _cookie_device_id(cookies: Mapping[str, str] | None) -> str | None:
    if not cookies:
        return None
    return cookies.get("_MHYUUID") or cookies.get("DEVICE_ID") or cookies.get("x-rpc-device_id")
