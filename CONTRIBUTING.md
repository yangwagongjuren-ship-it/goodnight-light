# 参与贡献 · Contributing

欢迎用中文或英文提交 Issue 和 Pull Request。报告问题时，请提供设备型号、系统版本、应用版本、重现步骤及期望结果。涉及亮度或锁屏的问题，请说明自动锁定和息屏显示设置。

提交代码前请运行 `flutter analyze` 和 `flutter test`，并使用 `dart format lib test integration_test` 格式化改动。修改界面文案时，请同步更新 `lib/strings.dart` 中的中英文。涉及原生亮度控制时，请在对应平台验证切换应用、锁屏和返回后的行为。

请勿在 Issue、截图或提交中包含密钥、签名文件或个人资料。通过 Pull Request 提交的原创内容按本项目 MIT 许可证提供。

Issues and pull requests in English or Chinese are welcome. For bug reports, include your device, OS version, app version, reproduction steps, and expected behavior. For brightness or screen-lock issues, include auto-lock and Always-On Display settings.

Before submitting code, run `flutter analyze` and `flutter test`, and format changes with `dart format lib test integration_test`. Update both languages in `lib/strings.dart` when changing UI copy. For native brightness changes, verify app switching, locking, and returning on the affected platform.

Keep credentials, signing files, and personal information out of issues, screenshots, and commits. Original contributions submitted through pull requests are provided under this project's MIT License.
