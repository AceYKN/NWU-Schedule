# NWU Schedule

西北大学本科课程表 App，首发目标为 Android，采用 Flutter/Dart 构建。

当前实现完成了 SPEC.md 中 Phase 1 和 Phase 2 的第一版切片，并搭好了 Phase 0 应用壳：

- Flutter 应用壳、Riverpod、go_router、主题契约和离线静态原型；
- `CalendarEngine` 统一计算教学周、假期和 `useScheduleOf` 调课日期；
- `ScheduleEngine` 根据课程、MeetingRule、校历和 `MOVE/CANCEL/ADD` 生成真实日期课表；
- `WeekMask` 使用 64-bit bitmask 支持连续周、单双周和离散周；
- `ScheduleNowState` 支持 NOW、NEXT、TODAY DONE、NO CLASS，并跨天寻找下一节课；
- 基础首页、周课表、月日历和课程详情 Bottom Sheet 已接入同一个 ScheduleEngine；
- 当前页面使用脱敏静态示例课表；Drift/SQLite、正方 WebView、通知和 Widget 将按 SPEC 的后续阶段接入。

## 开发

需要 Flutter stable SDK。执行：

```bash
flutter pub get
flutter test
flutter analyze
flutter run
```

当前工作树环境没有安装 Flutter SDK，因此本次尚未取得本机 `flutter test` / `flutter analyze` 结果；CI 配置会在 Flutter 环境中执行这些检查。

## 目录约定

```text
lib/
├── app/                 # 应用、路由、主题
├── core/nwu/            # 西北大学作息和常量
├── domain/              # 与 Flutter/数据库无关的业务模型和引擎
├── features/            # 页面
└── infrastructure/      # 校历资源和后续平台适配层
```

校历资源位于 `assets/calendars/nwu/`。发布前应以当学期正式校历核对其中的学期起止日期和特殊安排；ScheduleEngine 的假期、调课、单双周、跨天查找和单次异常已经由单元测试覆盖。

## 隐私边界

当前版本没有账号、服务器、广告或统计 SDK。当前静态原型不执行网络请求；后续数据库阶段仍会把课程和设置限制在设备本地 SQLite，正方 WebView 导入、通知、Widget、备份恢复也将在后续阶段接入。
