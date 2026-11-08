# Codex / Zcode / Antigravity 剩余额度按键

右侧“网站”分类分别提供“Codex 剩余额度”“Zcode 剩余额度”和“Antigravity 剩余额度”。功能身份决定额度来源，参数面板不再提供跨来源切换器；三者仍复用同一套额度渲染、刷新定时器和视觉配置。

Codex 读取用户选择的 `auth.json`，查询 ChatGPT Codex 的主额度窗口，并在按键上显示剩余百分比和重置倒计时。Zcode 读取用户选择的 `config.json`，在同一次请求中读取五小时和七天两个额度窗口，并分别显示剩余百分比与接口提供的重置时间；不显示 MCP 额度。Antigravity 读取本机 Antigravity CLI 的钥匙串登录，按所选模型分组显示 Google Cloud Code 的额度窗口。

参数面板可选择 1、5、10、30 或 60 分钟的自动刷新间隔，默认值为 10 分钟。修改后会保存到当前按键配置，并从修改时刻重新计时。

第二项“额度颜色”提供以下模式，并复用米哈游状态按键的红、黄、绿预设：

- “量多标红”：剩余额度大于 95% 时标红，小于 5% 时标绿，其余标黄。
- “量少标红”（默认）：剩余额度大于 95% 时标绿，小于 5% 时标红，其余标黄。

有周期条时，剩余时间与重置时间文字均使用顶部圆点当前位置的颜色；双周期按键的两行时间统一跟随最长周期的圆点，不受“额度颜色”模式影响。百分比文字继续遵循上面的额度颜色模式。

无法绘制周期条时，时间文字保留原有规则，按 `(reset_after_seconds / limit_window_seconds) / (used_percent * 0.01)` 计算：

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

- 凭据首次从 login 钥匙串中 Antigravity CLI 的条目（service `gemini`、account `antigravity`，内容为 `go-keyring-base64:` 前缀加 base64 JSON，读取 `token` 对象的 `access_token` / `refresh_token` / `expiry`）同步到本应用自有的副本条目（service `com.iBobby.UlanziDeckSwift.antigravity`，account `token`，JSON 格式），之后额度查询只读写副本条目。应用不提供任何密钥输入框。
- 使用副本条目的原因：agy CLI 刷新 token 后通过 `security add-generic-password -U`（不带 `-T`）回写它自己的条目，该操作会重置条目的授权列表，本应用此前点“始终允许”获得的授权随之丢失，读条目时会再次弹授权窗。应用对自己创建的钥匙串条目始终静默读写（按签名身份匹配，覆盖构建后依然有效），因此正常额度查询不再弹窗；只有首次同步、以及副本中的 `refresh_token` 失效后回读 agy 条目重新同步时，可能弹一次授权窗。
- 请求 `POST https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuotaSummary`，`Authorization` 使用 `Bearer <access_token>`，`User-Agent` 模拟 `antigravity/1.20.5 darwin/arm64 google-api-nodejs-client/10.3.0`。
- 参数面板提供“模型分组”下拉框：“Gemini”显示 `gemini-5h` 与 `gemini-weekly` 两个窗口（按键上显示 `5h` 与 `7d` 两行）；“Claude / GPT”只显示 `3p-weekly` 的 `7d` 窗口。`remainingFraction`（0 到 1）换算为剩余百分比，`resetTime`（RFC3339）换算为重置时间与倒计时，五小时与七天窗口分别按 18000 秒、604800 秒计算颜色。
- access token 过期（距 `expiry` 不足 5 分钟）时，应用用副本中的 `refresh_token` 向 `https://oauth2.googleapis.com/token` 换新（使用 agy CLI 内置的官方 OAuth 客户端凭据，与 CLI 属同一客户端），新的 access token 与有效期回写副本，`refresh_token` 沿用；与 agy CLI 各自刷新互不影响。副本刷新返回 `invalid_grant` 时删除副本并回读 agy 条目：源的 `refresh_token` 与失效的不同则采用并重建副本，相同或源不可用时显示“登录已失效，请运行 agy”；额度接口返回 401/403 同样显示登录已失效；钥匙串无条目时显示“未找到 Antigravity 登录”。需要强制重新同步（例如切换 Google 账号）时，删除钥匙串中的副本条目 `com.iBobby.UlanziDeckSwift.antigravity` 即可。
- 按键背景使用系统符号 `sparkles` 生成的黑白默认背景，无需选择文件，其余昵称、刷新间隔、重置显示与颜色设置与 Codex / Zcode 共用。

## 显示与刷新

- Zcode 使用独立内置图标背景，原图复制自 ZCode.app 的 `Contents/Resources/icon_windows.png`；模糊资源沿用 `FileIconSnapshot` 的 512 像素长边、半径 14 高斯模糊参数预生成，原图和模糊图都保持原始亮度。默认开启模糊和调暗，调暗只在按键渲染阶段叠加，关闭“变暗”后会恢复预渲染图的原始亮度。
- Codex 单窗口继续使用原有百分比、重置标签和时间布局，只解析 `primary_window`。
- Zcode 双窗口从上到下显示可选账号昵称、`5h <百分比>%`、五小时时间、`7d <百分比>%`、七天时间；空白昵称不占行。单窗口快照继续使用原有单窗口布局，并标明实际窗口。
- “剩余时间”模式将各窗口的倒计时格式化为 `<天>天 H:MM`；不足一天时显示 `H:MM`，不足一小时仍保留 `0:MM`。“重置时间”模式分别显示各窗口自己的本地月日和时间。
- 有已知重置时间的额度按键在按钮顶端绘制周期条：条从左到右为蓝、绿、黄、红渐变，绿、红之间经过黄色锚点而不是低饱和的土黄色。多窗口快照只取周期最长的一个窗口，例如同时有 5h 和 7d 时只使用 7d。
- 周期条的原始偏差 `d` 按 `已用百分比 / 100 - (周期秒数 - 剩余秒数) / 周期秒数` 计算并限制在 `-1...1`，等价于 `(1 - 剩余百分比 / 100) - 已过周期比例`。显示时使用对数映射 `p = sign(d) × ln(1 + 9 × |d|) / ln(10)`，再将 `-1...1` 映射到条的左右端点；此映射仅放大视觉偏移，不改变额度计算。例如 ±10 个百分点的偏差会移动中心到端点距离的约 28%。已用比例与已过周期比例相等时圆点在中间；消耗偏快时结果为正、圆点在右半段，偏慢时为负、圆点在左半段。中间有上下露出圆点的固定刻度，便于辨认方向；圆点直径是条厚度的三倍，内部填充其映射后所在位置的颜色。重置时间未知（`resetAt` 缺失且倒计时为 0）时不绘制周期条，避免把未知状态显示成已到期。
- 选择文件后立即刷新。
- 点击实体按键时立即刷新，并重置自动刷新倒计时。
- 每次查询结束后 10 分钟自动刷新；离开当前页面或内部刷新暂停时保留剩余倒计时，返回后继续。
- 文件权限失效、文件格式无效、登录失效和网络错误保持为不同的按键状态。
- 在“Codex 剩余额度”和“Zcode 剩余额度”之间切换时立即清除旧来源快照；已发出的旧请求即使稍后完成也不会覆盖新功能结果。

## 旧配置兼容

旧版本保存的 `codexUsage + dataSource.zcode` 会在加载时归一化为独立的 `zcodeUsage` 功能，同时保留 Zcode 文件路径、bookmark、昵称、视觉设置和已持久化的单窗口成功快照。旧快照没有窗口身份时继续按原主窗口语义读取；新双窗口快照会分别保存窗口身份。旧 Codex 配置继续使用原有 `codexUsage` 序列化值；兼容字段 `dataSource` 仍可读取，但运行时来源以功能身份为准。
