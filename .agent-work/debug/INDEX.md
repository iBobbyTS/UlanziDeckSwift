## Active

| file | summary |
| --- | --- |
| active/20260615-focus-filter-add-disabled.md | macOS 专注模式添加 Ulanzi Deck 过滤条件时“添加”无法生效，排查 AppIntents 元数据、系统设置状态和日志。 |

## Unresolved

| file | summary |
| --- | --- |

## Resolved

| file | summary |
| --- | --- |
| resolved/20260617-smb-netfs-eperm-fallback.md | SMB NetFS 连接返回 EPERM，根因按 errno 是系统权限拒绝，已改为仅 EPERM 时降级到系统打开 smb:// URL。 |
| resolved/20260617-single-instance-bundle-id-guard.md | 同 bundle id 多副本可同时运行，已用 bundle id 文件锁、旧实例检测、测试环境绕过和显式 Info.plist 保护修复。 |
| resolved/20260617-shortcuts-cannot-communicate-ad-hoc-signing.md | Shortcuts 能找到动作但执行时报“无法与App通信”，根因是 ad-hoc 签名没有 TeamIdentifier，被 `linkd` 的 `requiresValidatedBundle` 拒绝。 |
| resolved/20260617-shortcuts-old-focus-action-cache.md | Shortcuts 删除 Focus Filter 后仍显示旧动作，根因是 `/Applications/Ulanzi Deck.app` 旧副本仍带旧 AppIntents metadata。 |
| resolved/20260617-preview-min-width-unequal-margins.md | 最小窗口宽度时预览区四边距不等，已用统一预览布局度量和左侧列最小宽度修复。 |
| resolved/20260617-focus-runtime-status-debug.md | app 运行时专注状态读取不随勿扰开关变化，已沉淀工程 note 并移除轮询和权限请求。 |
| resolved/20260613-h200-display-disappears.md | H200 启动包短暂显示后消失，已通过持续 HID 连接和 `0x0006` 小窗 background 保活解决。 |
