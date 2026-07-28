# Codex 剩余额度按键

“Codex 剩余额度”按键读取用户选择的 Codex `auth.json`，查询 ChatGPT Codex 的主额度窗口，并在按键上显示剩余百分比和重置倒计时。

参数面板可选择 1、5、10、30 或 60 分钟的自动刷新间隔，默认值为 10 分钟。修改后会保存到当前按键配置，并从修改时刻重新计时。

第二项“额度颜色”提供以下模式，并复用米哈游状态按键的红、黄、绿预设：

- “量多标红”：剩余额度大于 95% 时标红，小于 5% 时标绿，其余标黄。
- “量少标红”（默认）：剩余额度大于 95% 时标绿，小于 5% 时标红，其余标黄。

重置时间颜色按 `(reset_after_seconds / limit_window_seconds) / (used_percent * 0.01)` 计算：

- “量多标红”：结果小于 0.9 时标红，大于 1.1 时标绿，其余标黄。
- “量少标红”：结果大于 1.1 时标红，小于 0.9 时标绿，其余标黄。

## 文件与鉴权

- 文件必须由用户通过应用内文件选择器选择。
- 应用只持久化文件路径和只读 security-scoped bookmark，不复制或持久化 access token。
- 查询时从 `tokens.access_token` 读取 Bearer token；如果存在 `tokens.account_id`，同时发送 `ChatGPT-Account-Id`。
- 请求使用 `GET https://chatgpt.com/backend-api/wham/usage`，并发送 `User-Agent: codex-cli`。

## 显示与刷新

- 主标题只显示 `<百分比>%`。
- 副标题将 `primary_window.reset_after_seconds` 格式化为 `<天>天 H:MM`；不足一天时显示 `H:MM`，不足一小时仍保留 `0:MM`。
- 选择文件后立即刷新。
- 点击实体按键时立即刷新，并重置自动刷新倒计时。
- 每次查询结束后 10 分钟自动刷新；离开当前页面或内部刷新暂停时保留剩余倒计时，返回后继续。
- 文件权限失效、文件格式无效、登录失效和网络错误保持为不同的按键状态。
