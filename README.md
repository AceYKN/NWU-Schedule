# NWU Schedule

面向西北大学本科生的 Android-first、本地优先课程表 App。项目以
`SPEC.md` 为产品与验收依据，不提供账号服务器、云同步、广告或统计服务。

## 当前实现

- `CalendarEngine` / `ScheduleEngine` 统一处理教学周、单双周、节假日、调休、补课、NOW/NEXT 和跨天查找；
- Drift/SQLite 本地保存多学期、课程、MeetingRule、临时调课、导入快照和删除墓碑；
- Today、Week、Month、课程详情、手动添加/编辑/隐藏/删除和课程颜色覆盖；
- MOVE、CANCEL、ADD 临时变更，支持在课程管理中撤销；
- 正方 WebView 导入：官方 HTTPS 域名白名单、学期选择、Normalize/Validate、Diff 预览、三方合并冲突选择、原子提交和 Cookie 清理；
- 本地通知、Android Small/Medium/Large Widget、手动备份/恢复/清除数据；
- 三套官方主题，可持久化并随备份恢复；
- 五份 NWU 校历资源及 CI 校历校验；校历 revision 检测、非阻断更新提示和缺失校历说明；
- 三套官方主题的 Golden UI 回归，以及数据库 schema v1→v2 migration。

正方教务的真实认证后 endpoint/schema 仍需要在真实西北大学学生账号环境做一次手动集成验收。适配器不硬编码未经验证的参数；当前同时支持规范化 payload 和页面 DOM 兜底。验收步骤见 [`docs/manual-integration.md`](docs/manual-integration.md)。

## 开发与验证

需要 Flutter stable SDK：

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/validate_calendars.dart
dart run tool/validate_privacy.dart
flutter build apk --debug
flutter build apk --release
```

`flutter test` 已包含三套主题的 Golden UI 回归，覆盖 Home 的 NOW/NEXT/DONE/NO CLASS、真实 Week/Month/课程详情页面以及导入 Diff 预览。由于不同系统的字体栅格化存在小幅差异，常规 Golden comparator 对 1% 以内的跨平台字体像素差异放行；文字更密集的真实页面和导入预览单独放宽到 1.5%，布局、颜色和明显内容变化仍会失败。

Release 构建不会使用 debug keystore。正式发布前请把未提交的
`android/key.properties.example` 复制为 `android/key.properties`，替换为
Owner 管理的 release keystore；也可以提供 `NWU_RELEASE_STORE_FILE`、
`NWU_RELEASE_STORE_PASSWORD`、`NWU_RELEASE_KEY_ALIAS` 和
`NWU_RELEASE_KEY_PASSWORD` 环境变量。CI 的 main 构建只使用一次性的临时
签名验证产物，不代表正式发布密钥。

Android SDK、Flutter SDK 和项目都可以分别放在不同磁盘；应用运行数据只保存在本机。

## 目录约定

```text
lib/app/                 应用、路由、主题和 Provider
lib/core/                西北大学作息、时间和工具
lib/domain/              纯 Dart 领域模型与引擎
lib/data/                Drift/SQLite 数据库和 Repository
lib/features/            Flutter 页面
lib/infrastructure/      校历、WebView、通知、Widget、备份平台适配
assets/calendars/nwu/    校历资源
android/                 Kotlin Widget、通知和 Document Picker 桥接
```

## 隐私边界

正常页面、通知、Widget 和校历不主动联网。只有用户主动进入“从教务系统导入”时，临时 WebView 才访问西北大学教务域名；导入结束会清理 WebView Cookie、缓存和页面存储。诊断导出会脱敏敏感键值，不包含账号、密码、Cookie 或 Token。
