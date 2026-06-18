from __future__ import annotations

import argparse
import json
import sys
from dataclasses import asdict
from pathlib import Path

from .auth import QRLoginClient
from .client import MiyousheClient
from .cookies import cookie_header, load_cookie_file, redacted_cookie_keys
from .models import ApiError, BoundRole, Game


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="米游社三游戏实时便笺调试工具")
    sub = parser.add_subparsers(dest="command", required=True)

    login = sub.add_parser("login", help="创建米游社 App 扫码登录并输出登录态 JSON")
    login.add_argument("--timeout", type=int, default=120)
    login.add_argument("--url-output", default=".agent-work/mihoyo_notes/login_url.txt")
    login.add_argument("--cookie-output", default=".agent-work/mihoyo_notes/session_cookie.json")

    inspect = sub.add_parser("inspect-cookie", help="解析 Cookie 文件，只输出 key 和脱敏信息")
    inspect.add_argument("--cookie-file", required=True)

    roles = sub.add_parser("roles", help="查询当前 Cookie 绑定的三游戏角色")
    roles.add_argument("--cookie-file", required=True)

    notes = sub.add_parser("notes", help="查询三游戏日常和体力状态")
    notes.add_argument("--cookie-file", required=True)
    notes.add_argument("--game", choices=[game.value for game in Game], action="append")
    notes.add_argument("--uid")
    notes.add_argument("--include-raw", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        if args.command == "login":
            client = QRLoginClient()
            session = client.create()
            _write_private_text(args.url_output, session.url)
            print(json.dumps({"login_url_file": args.url_output}, ensure_ascii=False, indent=2), flush=True)
            print("请用米游社 App 扫描 login_url 对应二维码并确认登录。等待确认中...", file=sys.stderr)
            tokens = client.wait_for_tokens(session, timeout_seconds=args.timeout)
            _write_private_text(args.cookie_output, json.dumps(asdict(tokens) | {"cookie": tokens.cookie}, ensure_ascii=False, indent=2))
            print(json.dumps({"cookie_file": args.cookie_output, "status": "saved"}, ensure_ascii=False, indent=2))
            return 0

        cookies = load_cookie_file(args.cookie_file)
        if args.command == "inspect-cookie":
            print(json.dumps({"keys": sorted(cookies), "redacted": redacted_cookie_keys(cookies)}, ensure_ascii=False, indent=2))
            return 0

        client = MiyousheClient(cookies)
        if args.command == "roles":
            print(json.dumps([role.to_json() for role in client.bound_roles()], ensure_ascii=False, indent=2))
            return 0

        games = [Game(value) for value in args.game] if args.game else None
        if args.uid and len(args.game or []) != 1:
            raise SystemExit("--uid 需要配合单个 --game 使用")
        if args.uid:
            role = client.find_role(games[0], args.uid)  # type: ignore[index]
            roles = [role]
        else:
            wanted = set(games or list(Game))
            roles = [role for role in client.bound_roles() if role.game in wanted]
        payload = [_note_payload(client, role, include_raw=args.include_raw) for role in roles]
        print(json.dumps(payload, ensure_ascii=False, indent=2))
        return 0 if all(item["ok"] for item in payload) else 2
    except ApiError as exc:
        print(json.dumps({"error": exc.message, "retcode": exc.retcode}, ensure_ascii=False, indent=2), file=sys.stderr)
        return 2


def _note_payload(client: MiyousheClient, role: BoundRole, *, include_raw: bool) -> dict:
    try:
        result = client.note(role)
    except ApiError as exc:
        return {
            "ok": False,
            "role": role.to_json(),
            "error": {
                "retcode": exc.retcode,
                "message": exc.message,
                "payload": exc.payload if include_raw else None,
            },
        }
    payload = {
        "ok": True,
        "role": result.role.to_json(),
        "status": result.status.to_json(),
    }
    if include_raw:
        payload["raw"] = result.raw
    return payload


def _write_private_text(path: str, text: str) -> None:
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text + "\n", encoding="utf-8")
    target.chmod(0o600)


if __name__ == "__main__":
    raise SystemExit(main())
