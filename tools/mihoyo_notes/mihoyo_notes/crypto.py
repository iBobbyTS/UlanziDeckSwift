from __future__ import annotations

import hashlib
import json
import random
import string
import time
import uuid
from typing import Any


MYS_VERSION = "2.102.1"

SALT_DS = "xV8v4Qu54lUKrEYFZkJhB8cuOh9Asafs"
SALT_WEB = "yBh10ikxtLPoIhgwgPZSv5dmfaOTSJ6a"
SALT_PASSPORT = "JwYDpKvLj6MrMqqYU6jTKF17KNO2PXoS"


def md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def random_device_id() -> str:
    return str(uuid.uuid4()).lower()


def random_hex(length: int) -> str:
    return "".join(random.choices("0123456789abcdef", k=length))


def random_string(length: int, alphabet: str = string.ascii_lowercase + string.digits) -> str:
    return "".join(random.choices(alphabet, k=length))


def json_body(body: Any) -> str:
    if body is None:
        return ""
    return json.dumps(body, separators=(",", ":"), ensure_ascii=False)


def ds_token(query: str = "", body: Any = None) -> str:
    t = str(int(time.time()))
    r = str(random.randint(100000, 200000))
    b = json_body(body)
    sign = md5(f"salt={SALT_DS}&t={t}&r={r}&b={b}&q={query}")
    return f"{t},{r},{sign}"


def web_ds_token() -> str:
    t = str(int(time.time()))
    r = random_string(6)
    sign = md5(f"salt={SALT_WEB}&t={t}&r={r}")
    return f"{t},{r},{sign}"


def passport_ds_token(query: str = "", body: Any = None) -> str:
    t = str(int(time.time()))
    r = random_string(6, string.ascii_letters)
    b = json_body(body)
    sign = md5(f"salt={SALT_PASSPORT}&t={t}&r={r}&b={b}&q={query}")
    return f"{t},{r},{sign}"
