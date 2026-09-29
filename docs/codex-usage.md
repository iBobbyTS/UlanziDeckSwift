# Codex / Zcode / Antigravity 剩余额度按键

右侧“网站”分类分别提供“Codex 剩余额度”“Zcode 剩余额度”和“Antigravity 剩余额度”。功能身份决定额度来源，参数面板不再提供跨来源切换器；三者仍复用同一套额度渲染、刷新定时器和视觉配置。

Codex 读取用户选择的 `auth.json`，查询 ChatGPT Codex 的主额度窗口，并在按键上显示剩余百分比和重置倒计时。Zcode 读取用户选择的 `config.json`，在同一次请求中读取五小时和七天两个额度窗口，并分别显示剩余百分比与接口提供的重置时间；不显示 MCP 额度。Antigravity 读取本机 Antigravity CLI 的钥匙串登录，按所选模型分组显示 Google Cloud Code 的额度窗口。

参数面板可选择 1、5、10、30 或 60 分钟的自动刷新间隔，默认值为 10 分钟。修改后会保存到当前按键配置，并从修改时刻重新计时。

第二项“额度颜色”提供以下模式，并复用米哈游状态按键的红、黄、绿预设：

- “量多标红”：剩余额度大于 95% 时标红，小于 5% 时标绿，其余标黄。
- “量少标红”（默认）：剩余额度大于 95% 时标绿，小于 5% 时标红，其余标黄。

重置时间颜色按 `(reset_after_seconds / limit_window_seconds) / (used_percent * 0.01)` 计算：

- “量多标红”：结果小于 0.9 时标红，大于 1.1 时标绿，其余标黄。
- “量少标红”：结果大于 1.1 时标红，小于 0.9 时标绿，其余标黄。

## 文件与鉴权

- 从空按键新增“Codex 剩余额度”功能时，应用会直接选择 `~/.codex/auth.json`，不打开文件选择器。
- 修改已有“Codex 剩余额度”功能的文件时，仍使用原来的手动选择流程。
- 应用只持久化文件路径和只读 security-scoped bookmark，不复制或持久化 access token。
- 查询时从 `tokens.access_token` 读取 Bearer token；如果存在 `tokens.account_id`，同时发送 `ChatGPT-Account-Id`。
- 请求使用 `GET https://chatgpt.com/backend-api/wham/usage`，并发送 `User-Agent: codex-cli`。

“Zcode 剩余额度”遵循以下规则：

- 新增功能时直接使用 `~/.zcode/v2/config.json`，不会请求或选择 Codex `auth.json`；也可以在参数面板中重新选择其他 JSON 文件。
- 每次请求前重新读取配置文件，从 `provider["builtin:zai-coding-plan"].options` 取得 `apiKey` 和 `baseURL`，应用不提供或保存额外的密钥输入框。
- 请求地址只使用 `baseURL` 的 origin，再拼接 `/api/monitor/usage/quota/limit`；例如 `https://api.z.ai/api/anthropic` 会请求 `https://api.z.ai/api/monitor/usage/quota/limit`。
- `Authorization` 直接使用 `apiKey`，不添加 `Bearer` 前缀。
- HTTP 成功后仍要求业务响应成功；额度列表只接受 `type=CREDIT_LIMIT` 的五小时窗口（`unit=3`、`number=5`）和七天窗口（`unit=6`、`number=1`）。`percentage` 表示已用比例，例如 `3` 和 `9` 分别显示为剩余 `97%` 和 `91%`。
- 两个窗口按 `5h`、`7d` 的固定顺序显示，不依赖接口数组顺序。接口只返回其中一个有效窗口时只显示该窗口，不补造缺失窗口；两个窗口都无效或缺失时显示额度不可用状态。
- 匹配窗口带有合法 `nextResetTime` 时，将 Unix 毫秒时间戳转换为重置时间和非负倒计时，并分别按 18000 秒、604800 秒窗口计算颜色。缺失或非法时间不影响该窗口的百分比显示，也不会生成虚假重置时间。
- 未选择或需重选配置文件、JSON 无效、provider 配置缺失、鉴权失败、网络失败和缺少有效额度窗口分别显示不同状态。

“Antigravity 剩余额度”遵循以下规则：

- 凭据来自 login 钥匙串中 Antigravity CLI 的条目（service `gemini`、account `antigravity`），内容为 `go-keyring-base64:` 前缀加 base64 JSON，读取 `token.access_token`；应用不提供或保存任何密钥输入框，也不写入钥匙串。首次访问其他应用创建的钥匙串条目时，macOS 可能弹窗请求授权。
- 请求 `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary`，`Authorization` 使用 `Bearer <access_token>`，`User-Agent` 模拟 `antigravity/1.20.5 darwin/arm64 google-api-nodejs-client/10.3.0`。
- 参数面板提供“模型分组”下拉框：“Gemini”显示 `gemini-5h` 与 `gemini-weekly` 两个窗口（按键上显示 `5h` 与 `7d` 两行）；“Claude / GPT”只显示 `3p-weekly` 的 `7d` 窗口。`remainingFraction`（0 到 1）换算为剩余百分比，`resetTime`（RFC3339）换算为重置时间与倒计时，五小时与七天窗口分别按 18000 秒、604800 秒计算颜色。
- 应用不刷新 OAuth token：Antigravity CLI 进程会自动续期钥匙串。token 过期导致 401/403 时显示“登录已失效”，在终端运行一次 `agy` 即可恢复；钥匙串无条目时显示“未找到 Antigravity 登录”。
- 按键背景使用系统符号 `sparkles` 生成的黑白默认背景，无需选择文件，其余昵称、刷新间隔、重置显示与颜色设置与 Codex / Zcode 共用。

## 显示与刷新

- Zcode 使用独立内置图标背景，原图复制自 ZCode.app 的 `Contents/Resources/icon_windows.png`；模糊资源沿用 `FileIconSnapshot` 的 512 像素长边、半径 14 高斯模糊参数预生成，原图和模糊图都保持原始亮度。默认开启模糊和调暗，调暗只在按键渲染阶段叠加，关闭“变暗”后会恢复预渲染图的原始亮度。
- Codex 单窗口继续使用原有百分比、重置标签和时间布局，只解析 `primary_window`。
- Zcode 双窗口从上到下显示可选账号昵称、`5h <百分比>%`、五小时时间、`7d <百分比>%`、七天时间；空白昵称不占行。单窗口快照继续使用原有单窗口布局，并标明实际窗口。
- “剩余时间”模式将各窗口的倒计时格式化为 `<天>天 H:MM`；不足一天时显示 `H:MM`，不足一小时仍保留 `0:MM`。“重置时间”模式分别显示各窗口自己的本地月日和时间。
- 选择文件后立即刷新。
- 点击实体按键时立即刷新，并重置自动刷新倒计时。
- 每次查询结束后 10 分钟自动刷新；离开当前页面或内部刷新暂停时保留剩余倒计时，返回后继续。
- 文件权限失效、文件格式无效、登录失效和网络错误保持为不同的按键状态。
- 在“Codex 剩余额度”和“Zcode 剩余额度”之间切换时立即清除旧来源快照；已发出的旧请求即使稍后完成也不会覆盖新功能结果。

## 旧配置兼容

旧版本保存的 `codexUsage + dataSource.zcode` 会在加载时归一化为独立的 `zcodeUsage` 功能，同时保留 Zcode 文件路径、bookmark、昵称、视觉设置和已持久化的单窗口成功快照。旧快照没有窗口身份时继续按原主窗口语义读取；新双窗口快照会分别保存窗口身份。旧 Codex 配置继续使用原有 `codexUsage` 序列化值；兼容字段 `dataSource` 仍可读取，但运行时来源以功能身份为准。
