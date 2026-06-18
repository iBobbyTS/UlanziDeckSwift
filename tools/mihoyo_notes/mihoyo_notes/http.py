from __future__ import annotations

import json
from typing import Any
from urllib import error, parse, request

from .models import ApiError


class HttpClient:
    def __init__(self, timeout: float = 15.0):
        self.timeout = timeout

    def request_json(
        self,
        method: str,
        url: str,
        *,
        headers: dict[str, str] | None = None,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        target = url
        if params:
            query = parse.urlencode(params, doseq=True)
            sep = "&" if "?" in target else "?"
            target = f"{target}{sep}{query}"

        data = None
        request_headers = dict(headers or {})
        if json_body is not None:
            data = json.dumps(json_body, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
            request_headers.setdefault("Content-Type", "application/json")
            request_headers.setdefault("Accept", "application/json")

        req = request.Request(target, data=data, headers=request_headers, method=method.upper())
        try:
            with request.urlopen(req, timeout=self.timeout) as response:
                raw = response.read().decode("utf-8")
        except error.HTTPError as exc:
            body = exc.read().decode("utf-8", errors="replace")
            raise ApiError(exc.code, f"HTTP {exc.code}: {body[:200]}") from exc
        except error.URLError as exc:
            raise ApiError(None, str(exc.reason)) from exc

        try:
            payload = json.loads(raw)
        except json.JSONDecodeError as exc:
            raise ApiError(None, f"non-JSON response: {raw[:200]}") from exc
        return payload
