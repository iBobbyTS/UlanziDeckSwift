from __future__ import annotations

import time
import uuid
from dataclasses import dataclass
from typing import Any

from .crypto import MYS_VERSION, passport_ds_token, random_device_id, random_hex
from .http import HttpClient
from .models import ApiError, LoginTokens


PASSPORT_BASE = "https://passport-api.mihoyo.com"
CREATE_QR_LOGIN = f"{PASSPORT_BASE}/account/ma-cn-passport/app/createQRLogin"
QUERY_QR_LOGIN = f"{PASSPORT_BASE}/account/ma-cn-passport/app/queryQRLoginStatus"
GET_COOKIE_TOKEN_BY_STOKEN = f"{PASSPORT_BASE}/account/auth/api/getCookieAccountInfoBySToken"
GET_LTOKEN_BY_STOKEN = f"{PASSPORT_BASE}/account/auth/api/getLTokenBySToken"
GET_FP_URL = "https://public-data-api.mihoyo.com/device-fp/api/getFp"


def _api_data(payload: dict[str, Any]) -> dict[str, Any]:
    retcode = int(payload.get("retcode", -1))
    if retcode != 0:
        raise ApiError(retcode, str(payload.get("message", "")), payload)
    data = payload.get("data")
    if not isinstance(data, dict):
        raise ApiError(retcode, "missing response data", payload)
    return data


@dataclass(frozen=True)
class LoginSession:
    ticket: str
    url: str
    device_id: str


class QRLoginClient:
    """米游社 App 扫码登录客户端。

    只负责创建二维码、轮询状态、换 cookie_token。调用方仍应让用户亲自扫码确认。
    """

    hyp_version = "1.3.3.182"

    def __init__(self, http: HttpClient | None = None):
        self.http = http or HttpClient()

    @staticmethod
    def _headers(device_id: str) -> dict[str, str]:
        return {
            "x-rpc-device_id": device_id,
            "User-Agent": f"HYPContainer/{QRLoginClient.hyp_version}",
            "x-rpc-app_id": "ddxf5dufpuyo",
            "x-rpc-client_type": "3",
        }

    def create(self) -> LoginSession:
        device_id = uuid.uuid4().hex + uuid.uuid4().hex
        payload = self.http.request_json(
            "POST",
            CREATE_QR_LOGIN,
            headers=self._headers(device_id),
            json_body={},
        )
        data = _api_data(payload)
        return LoginSession(ticket=data["ticket"], url=data["url"], device_id=device_id)

    def query(self, session: LoginSession) -> dict[str, Any]:
        payload = self.http.request_json(
            "POST",
            QUERY_QR_LOGIN,
            headers=self._headers(session.device_id),
            json_body={"ticket": session.ticket},
        )
        return _api_data(payload)

    def wait_for_tokens(self, session: LoginSession, timeout_seconds: int = 120, poll_seconds: float = 2.0) -> LoginTokens:
        deadline = time.time() + timeout_seconds
        while time.time() < deadline:
            data = self.query(session)
            status = data.get("status")
            if status in {"Created", "Scanned"}:
                time.sleep(poll_seconds)
                continue
            if status != "Confirmed":
                raise ApiError(None, f"unexpected QR login status: {status}", data)
            return self.tokens_from_confirmed_data(data)
        raise ApiError(None, "QR login timed out")

    def tokens_from_confirmed_data(self, data: dict[str, Any]) -> LoginTokens:
        user_info = data.get("user_info") or {}
        tokens = data.get("tokens") or []
        account_id = str(user_info.get("aid") or user_info.get("uid") or user_info.get("account_id") or "")
        mid = str(user_info.get("mid") or "")
        if not account_id or not mid:
            raise ApiError(None, "QR login response missing account_id or mid", data)

        stoken = ""
        for token in tokens:
            if token.get("name") in {"stoken_v2", "stoken"}:
                stoken = str(token.get("token") or "")
                break
            if token.get("token_type") == 1 and token.get("token"):
                stoken = str(token["token"])
                break
        if not stoken and tokens and tokens[0].get("token"):
            stoken = str(tokens[0]["token"])
        if not stoken:
            raise ApiError(None, "QR login response missing stoken", data)

        cookie_token = self.get_cookie_token_by_stoken(stoken, account_id, mid)
        ltoken = self.get_ltoken_by_stoken(stoken, account_id, mid)
        device_id = random_device_id()
        device_fp = self.generate_device_fp(device_id)
        return LoginTokens(
            account_id=account_id,
            stoken_v2=stoken,
            mid=mid,
            cookie_token=cookie_token,
            ltoken=ltoken,
            device_id=device_id,
            device_fp=device_fp,
        )

    def get_cookie_token_by_stoken(self, stoken: str, account_id: str, mid: str) -> str:
        headers = {
            "x-rpc-app_version": MYS_VERSION,
            "X-Requested-With": "com.mihoyo.hyperion",
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 13; PHK110 Build/SKQ1.221119.001; wv)"
                f" AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.133 Mobile Safari/537.36 miHoYoBBS/{MYS_VERSION}"
            ),
            "x-rpc-client_type": "5",
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
            "Cookie": f"stuid={account_id};stoken={stoken};mid={mid}",
        }
        payload = self.http.request_json(
            "GET",
            GET_COOKIE_TOKEN_BY_STOKEN,
            headers=headers,
            params={"stoken": stoken, "uid": account_id, "mid": mid},
        )
        data = _api_data(payload)
        cookie_token = str(data.get("cookie_token") or "")
        if not cookie_token:
            raise ApiError(None, "response missing cookie_token", payload)
        return cookie_token

    def get_ltoken_by_stoken(self, stoken: str, account_id: str, mid: str) -> str:
        headers = self._passport_headers(stoken, account_id, mid)
        payload = self.http.request_json(
            "GET",
            GET_LTOKEN_BY_STOKEN,
            headers=headers,
        )
        data = _api_data(payload)
        ltoken = str(data.get("ltoken") or "")
        if not ltoken:
            raise ApiError(None, "response missing ltoken", payload)
        return ltoken

    def _passport_headers(self, stoken: str, account_id: str, mid: str) -> dict[str, str]:
        return {
            "x-rpc-app_version": MYS_VERSION,
            "X-Requested-With": "com.mihoyo.hyperion",
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 13; PHK110 Build/SKQ1.221119.001; wv)"
                f" AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.133 Mobile Safari/537.36 miHoYoBBS/{MYS_VERSION}"
            ),
            "x-rpc-client_type": "5",
            "x-rpc-device_id": random_hex(32),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
            "Cookie": f"stuid={account_id};stoken={stoken};mid={mid}",
        }

    def generate_device_fp(self, device_id: str) -> str:
        seed_id = random_hex(16)
        body = {
            "device_id": random_hex(16),
            "seed_id": seed_id,
            "platform": "1",
            "seed_time": str(int(time.time() * 1000)),
            "ext_fields": (
                '{"proxyStatus":"0","accelerometer":"-0.159515x-0.830887x-0.682495",'
                '"ramCapacity":"3746","IDFV":"'
                + device_id.upper()
                + '","gyroscope":"-0.191951x-0.112927x0.632637","isJailBreak":"0",'
                '"model":"iPhone12,5","ramRemain":"115","chargeStatus":"1","networkType":"WIFI",'
                '"vendor":"--","osVersion":"17.0.2","batteryStatus":"50","screenSize":"414×896",'
                '"cpuCores":"6","appMemory":"55","romCapacity":"488153","romRemain":"157348",'
                '"cpuType":"CPU_TYPE_ARM64","magnetometer":"-84.426331x-89.708435x-37.117889"}'
            ),
            "app_name": "bbs_cn",
            "device_fp": random_hex(13),
        }
        headers = {
            "x-rpc-app_version": MYS_VERSION,
            "x-rpc-client_type": "5",
            "User-Agent": (
                "Mozilla/5.0 (Linux; Android 13; PHK110 Build/SKQ1.221119.001; wv)"
                f" AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/126.0.6478.133 Mobile Safari/537.36 miHoYoBBS/{MYS_VERSION}"
            ),
            "Referer": "https://webstatic.mihoyo.com/",
            "Origin": "https://webstatic.mihoyo.com/",
        }
        payload = self.http.request_json("POST", GET_FP_URL, headers=headers, json_body=body)
        data = _api_data(payload)
        if data.get("code") != 200:
            raise ApiError(int(data.get("code", -1)), str(data.get("msg", "failed to generate device fp")), payload)
        fp = str(data.get("device_fp") or "")
        if not fp:
            raise ApiError(None, "response missing device_fp", payload)
        return fp


def login_device_id() -> str:
    return random_hex(32)
