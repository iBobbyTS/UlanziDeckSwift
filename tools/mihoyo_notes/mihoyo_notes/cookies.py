from __future__ import annotations

import json
from http.cookies import SimpleCookie
from pathlib import Path
from typing import Mapping


SENSITIVE_KEYS = {
    "cookie_token",
    "cookie_token_v2",
    "ltoken",
    "ltoken_v2",
    "stoken",
    "stoken_v2",
    "login_ticket",
    "login_ticket_v2",
}


def parse_cookie_text(text: str) -> dict[str, str]:
    stripped = text.strip()
    if not stripped:
        return {}
    if stripped.startswith("{"):
        raw = json.loads(stripped)
        if isinstance(raw, dict) and isinstance(raw.get("cookie"), str):
            return parse_cookie_text(raw["cookie"])
        return {str(k): str(v) for k, v in raw.items() if v is not None}

    parsed = SimpleCookie()
    parsed.load(stripped)
    if parsed:
        return {key: morsel.value for key, morsel in parsed.items()}

    pairs: dict[str, str] = {}
    for item in stripped.split(";"):
        if "=" not in item:
            continue
        key, value = item.split("=", 1)
        key = key.strip()
        if key:
            pairs[key] = value.strip()
    return pairs


def load_cookie_file(path: str | Path) -> dict[str, str]:
    return parse_cookie_text(Path(path).read_text(encoding="utf-8"))


def cookie_header(cookies: Mapping[str, str]) -> str:
    return "; ".join(f"{key}={value}" for key, value in cookies.items() if value is not None)


def redacted_cookie_keys(cookies: Mapping[str, str]) -> dict[str, str]:
    return {
        key: ("<redacted>" if key in SENSITIVE_KEYS else value)
        for key, value in sorted(cookies.items())
    }
