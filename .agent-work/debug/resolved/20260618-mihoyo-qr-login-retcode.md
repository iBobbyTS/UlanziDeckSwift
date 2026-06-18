# 米游社二维码登录直接失败

## 已确认现象

- App 内原神状态配置区点击重新登录后直接显示 `登录失败：OK`，未能进入二维码展示状态。
- 直接请求 `https://passport-api.mihoyo.com/account/ma-cn-passport/app/createQRLogin` 可返回 HTTP 200、`retcode: 0`、`message: OK`，且 `data.ticket` / `data.url` 存在。

## 根因假设

- `JSONSerialization` 返回的数字和布尔值都可能桥接为 `NSNumber`。
- Swift 中 `NSNumber(value: false)` / `__NSCFBoolean` 在先执行 `as? Int` 时可能被解析为 `0`，导致 JSON 布尔值和数字边界混淆。
- `MihoyoJSON.int` 必须先用 `CFGetTypeID(number) != CFBooleanGetTypeID()` 排除布尔，再返回 `number.intValue`。

## 回归覆盖

- 新增 `mihoyoJSONParsesNumericRetcodeWithoutTreatingItAsBool`，覆盖 `retcode: 0` 可解析为整数，同时 `success: false` 不能被解析为整数。

## 验证命令

```bash
xcodebuild test -project UlanziDeckSwift.xcodeproj -scheme UlanziDeckSwift -destination 'platform=macOS' -only-testing:UlanziDeckSwiftTests
```

## 验证结果

- 单元测试通过。
- 重启 Debug App 后点击“生成登录二维码”，UI 从“正在生成二维码”进入“等待扫码”，并显示米游社登录二维码。
