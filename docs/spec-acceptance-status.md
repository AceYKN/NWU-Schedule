# SPEC V1 验收状态

记录日期：2026-09-21

这份记录区分仓库内可重复验证的结果与必须由真实 NWU 账号/Android 设备完成的外部验收。外部项目没有用 fixture 或静态检查冒充通过。

## 已通过

| SPEC 能力 | 当前证据 | 状态 |
| --- | --- | --- |
| 校历、教学周、单双周、节假日、调休、补课 | `tool/validate_calendars.dart`、`calendar_engine_test.dart`、5 份校历源数据 | PASS |
| Home NOW/NEXT/DONE/NO CLASS 与跨日查找 | `schedule_engine_test.dart`、Home golden 测试 | PASS（自动化） |
| MOVE/CANCEL/ADD | `fixture_schedule_pipeline_test.dart` 串联 DB、ScheduleEngine、通知计划、Widget 快照 | PASS（自动化） |
| 导入 Preview、Diff、Three-way Merge、tombstone | `import_diff_test.dart`、`three_way_merge_test.dart`、Drift repository 测试 | PASS（自动化） |
| 关键 DOM 解析与 `rowspan/colspan` | `tool/test_nwu_dom_extractor.mjs`、脱敏 NWU list/grid fixtures | PASS（自动化） |
| `321` 教室不进入周次、异常周次 fail-closed | DOM fixture 与 `timetable_import_test.dart` | PASS（自动化） |
| 不完整 DOM 不触发 destructive import | `drift_schedule_data_repository_test.dart` | PASS（自动化） |
| 教师/教室/校区/周次/节次变化后的 meeting identity 与例外 | Drift repository identity tests | PASS（自动化） |
| 备份、清除、恢复、旧备份兼容 | `schedule_backup_test.dart`、`backup_repository_test.dart`、fixture pipeline | PASS（自动化） |
| Rolling WidgetSnapshot 与 Android 当前日期/时间过滤 | `widget_snapshot_test.dart`、`CourseWidgetProvider.kt` | PASS（自动化/静态） |
| 通知权限、重建、旧 Alarm 清理 | `bootstrap_test.dart`、`notification_planner_test.dart`、`MainActivity.kt` | PASS（自动化/静态） |
| 隐私边界、无统计/广告依赖、merged manifest | privacy/manifest validators 与 CI | PASS（自动化） |
| UI、Golden、无障碍 | `test/widget`、`test/golden`、`accessibility_test.dart` | PASS（自动化） |
| Android 构建 | [GitHub Actions Run #217](https://github.com/AceYKN/NWU-Schedule/actions/runs/35542809787)：debug/release APK 与 merged manifest 校验 | PASS |

最近一次本地全量检查：校历校验、隐私校验、DOM fixture、`flutter analyze`、181 项 `flutter test` 和本地 debug APK 构建均通过。新增证据包括：旧数据库课程元数据显式清空、备份恢复晚期坏引用保持原数据、Medium/Large Native Widget 缺失地点显示“地点待补充”，以及手动课程“添加第二条上课安排 → 保存 → 重新打开编辑页仍保留两条”的 Widget 回归。[GitHub Actions Run #217](https://github.com/AceYKN/NWU-Schedule/actions/runs/35542809787) 以 `main` 提交 `e6fd593` 完成全部 CI 检查，包括 debug/release APK 构建与最终 merged manifest 校验。

## 设备上已核对但不等同于真实集成通过

- Pixel 8 API 35 模拟器 `emulator-5554` 在线。
- `app-debug.apk` 安装成功，`MainActivity` 成为 `topResumedActivity`。
- 启动后的抽样 logcat 未发现 `FATAL EXCEPTION`。

这只证明 APK 能安装和启动，不证明真实教务账号导入成功。

2026-09-21 在同一台 Pixel 8 API 35 模拟器上使用脱敏样例课程 `123` 做了受控通知烟测：

- 设置页显示通知已开启，系统 `POST_NOTIFICATIONS` 权限为 granted，并且应用已注册 `course_reminders` 通知渠道。
- 将模拟器时钟临时推进到已排程 Alarm 的窗口后，通知栏真实出现“西北大学课程表”通知，正文为样例课程的上课提醒。
- 点击该通知后进入应用的“课程详情”页，并显示样例课程 `123`；这验证了 Alarm → Receiver → 通知点击路由链路。
- 启动器 Widget 选择器能够显示“西北大学课程表”的 `2 × 1` Provider；通过选择器的 Add 入口成功放置 2 枚实例，`dumpsys appwidget` 显示 Provider 实例 `id=2/3` 与 `widgets.size=2`。
- 同一 Provider 的实例已在模拟器上覆盖 Small、Medium、Large：Small 显示 `NEXT / 123 / 08:00–09:50`，拉宽后显示 `TODAY` 列表，拉高后显示 `TODAY + TOMORROW`；Medium/Large 的课程行点击进入“课程详情”，空白区域点击回到 Home。
- 将模拟器时间推进到当天 09:00 后，Small 不再把已结束的 08:00 课程作为 NEXT；推进到下一天 09:00 后，Large 的 TODAY/TOMORROW 均为 `No Class`，Small 选择下一个未来实例。
- 设备复核发现无地点课程曾在 Native Widget 中显示为字面量 `null`；已修复为 `地点待补充`，重新安装 debug APK 后 `widget_small_meta` 已显示 `08:00  地点待补充`。
- 通过系统权限控制器完成了通知权限拒绝/重新允许流程：拒绝后权限为 `granted=false`，设置页显示“未获得通知权限，提醒未开启”，已排程 ID 清空；重新允许后权限为 `granted=true`，课程提醒恢复排程。随后重复关闭/开启一次，排程 ID 数量仍为 16，未产生重复 Alarm；`dumpsys alarm` 中的历史取消记录属于系统审计记录，不是活动 Alarm。

以上证据只覆盖设备烟测的子集，仍不等同于真实 NWU 账号导入或完整 Widget 验收。

## 外部验收仍待完成

| 项目 | 状态 | 缺少的直接证据 |
| --- | --- | --- |
| NWU 登录 → 选课 → 个人课表查询 → 读取 → Preview → 保存 | BLOCKED（需设备 Owner） | 真实学生账号下的 post-fix 复测记录 |
| 教室 `321` 在真实页面中的最终字段归属 | BLOCKED（需设备 Owner） | 脱敏诊断或人工抽查，不能上传原始课表 |
| 真实 endpoint、`gnmkdm`、POST 参数、响应 schema、稳定远端 ID | BLOCKED（需真实会话） | 只记录字段名/路径，不记录 Cookie、Token 或原始响应 |
| 关闭导入后必须重新登录 | BLOCKED（需设备 Owner） | 重新进入 Import 的手工验证 |
| 通知权限拒绝/允许、实际触发、点击、无重复 | PARTIAL（模拟器已覆盖拒绝/重新允许、触发、点击和无重复） | 仍缺少真实设备记录 |
| Small/Medium/Large Widget、多个实例、日期/时间切换 | PARTIAL（模拟器已覆盖三尺寸、两实例和日期/时间滚动） | 仍缺少真实设备 Owner 的最终复核，以及重启/真实数据编辑后的记录 |
| 第 11 节作息时间 | BLOCKED（需项目 Owner） | 校方最新作息确认；当前代码按 SPEC 暂存 `21:00–21:50` |

真实联调只应使用 `docs/manual-integration.md` 的个人课表路径，并且认证材料必须在聊天、仓库、Issue、日志和诊断文件之外提供。
