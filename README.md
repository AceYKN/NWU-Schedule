# 西小课（NWU Schedule）

面向西北大学本科生的 Android 课程表 App，支持教务导入、离线查看、上课提醒和桌面小组件。

[下载 APK](https://github.com/AceYKN/NWU-Schedule/releases) · [产品说明](SPEC.md) · [导入指南](docs/manual-integration.md)

本文介绍 `main` 分支功能，已发布 APK 的功能以对应版本说明为准。

## 主要功能

- **教务导入**：登录官方教务系统读取课表，确认变化预览，处理本地与教务数据冲突。
- **课表查看**：首页、周课表、月历和课程详情，支持多学期切换与五日／七日展示。
- **课程管理**：添加、编辑、隐藏、删除、恢复课程，以及调课、停课和临时加课。
- **校历适配**：教学周、单双周、节假日、调休和补课。
- **提醒与小组件**：本地上课提醒，桌面显示下一节、今天或今天与明天的课程。
- **外观与备份**：三套主题、浅色／深色模式、本地备份与恢复。

## 使用

进入“设置 → 从教务系统导入”，登录后查询学期，点击“读取课表”，核对预览并确认导入。导入后可离线使用，在设置中开启提醒，并通过系统桌面添加小组件。

提醒和小组件刷新可能受系统省电影响；恢复备份会替换当前本地数据。

## 开发

使用 Flutter **3.47.4 stable**，准备 Android SDK、JDK 17 和 Node.js。

```bash
flutter pub get
node tool/test_nwu_dom_extractor.mjs
flutter analyze
flutter test
flutter build apk --debug
```

Release 构建需按 [签名配置示例](android/key.properties.example) 配置本地密钥，再运行 `flutter build apk --release`。签名配置和密钥不得提交。完整检查见 [CI 配置](.github/workflows/ci.yml)。

调试版显示为“西小课（开发）”，包名为 `io.github.aceykn.nwuschedule.debug`，与正式版的数据目录分离，避免调试签名覆盖正式版。正式更新始终使用原包名、原签名，保留本地数据库；不要先卸载旧版。

Windows 本地运行可使用 `./tool/run_android.ps1 -Device emulator-5558`（Flutter 和 adb 需在 PATH 中，也可传入 `-Flutter`、`-Adb` 路径）。脚本构建正式入口并使用 `adb install -r` 覆盖安装，安装失败即停止，不会自动卸载旧应用。首次从旧版调试包切换开发版，可通过“设置 → 备份与恢复”转移数据；之后开发版覆盖更新会继续使用原数据。

## 隐私

课表和设置保存在本机，没有云同步、广告或统计服务。仅主动导入时访问西北大学官方教务域名；应用不提取或保存学号、密码，导入会话结束后清理登录数据。备份和脱敏诊断由用户主动导出，不会自动上传。
