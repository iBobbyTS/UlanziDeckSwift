# 米游社实时便笺 Python 调试模块

这个目录是 Swift 集成前的独立验证层，用于确认米游社登录态、绑定 UID 和三游戏实时便笺字段。

## 使用

不打印 Cookie 原文，只输出脱敏 key：

```bash
python3 -m tools.mihoyo_notes.mihoyo_notes.cli inspect-cookie --cookie-file test_cookie.txt
```

查询绑定角色：

```bash
python3 -m tools.mihoyo_notes.mihoyo_notes.cli roles --cookie-file test_cookie.txt
```

查询三游戏日常和体力：

```bash
python3 -m tools.mihoyo_notes.mihoyo_notes.cli notes --cookie-file test_cookie.txt
```

仅查询某个游戏：

```bash
python3 -m tools.mihoyo_notes.mihoyo_notes.cli notes --cookie-file test_cookie.txt --game zzz
```

扫码登录会创建米游社 App 登录二维码链接，需要用户本人用米游社 App 扫码确认：

```bash
python3 -m tools.mihoyo_notes.mihoyo_notes.cli login
```

## 边界

- `uid + server` 只定位角色，不提供授权。
- 原神和星铁便笺可能返回 `1034`、`10035` 等风控状态，需要用户在米游社 App 中完成验证或绑定常用设备参数。
- 本模块不会尝试绕过验证码，也不会输出 Cookie 原文。
