# 西北大学课程表 App — Software Specification

**文档版本：** v1.0
**目标平台：** Android First，架构兼容未来 iOS
**客户端技术栈：** Flutter + Dart
**目标学校：** 西北大学
**目标用户：** 西北大学本科生
**教务系统：** 西北大学正方教务管理系统
**后端：** 无
**数据原则：** Local First / Offline First
**项目状态：** 需求冻结，可进入开发

---

# 1. Product Vision

本项目是一款专门面向西北大学本科生的轻量课程表 App。

核心目标不是简单地“把教务系统课程表搬到手机”，而是解决现有课程表软件几个明显问题：

1. 广告繁杂；
2. 功能臃肿或强行加入社交、社区、课程评价等无关功能；
3. 无法正确处理西北大学教学周、节假日、调休、补课等实际教学安排；
4. 用户真正临近上课时需要的是“下一节课在哪里”，而不是一整张复杂课表；
5. 缺乏桌面 Widget；
6. 上课提醒机制不够可靠；
7. 需要账号注册、上传课表甚至上传教务账号，带来隐私问题；
8. 学校教务课表更新后缺乏清晰的差异同步能力。

因此，本产品核心定位是：

> **一个无广告、无账号、无后端、本地存储、深度适配西北大学校历和正方教务系统的课程时间工具。**

用户登录学校教务系统仅用于一次性读取课表。

读取完成后，绝大部分功能均可完全离线运行。

---

# 2. Core Product Principles

项目必须始终遵守以下原则。

## 2.1 Offline First

除“从教务系统导入课表”外：

* 首页无需联网；
* 周课表无需联网；
* 月历无需联网；
* Widget 无需联网；
* 通知无需联网；
* 校历无需联网；
* 课程编辑无需联网。

没有网络时 App 仍应完整工作。

---

## 2.2 No Backend

V1 不建设任何服务器。

明确禁止：

* 用户账号服务器；
* 课表同步服务器；
* 校历 API；
* 用户行为统计服务器；
* 广告服务器；
* 云端课程数据库；
* 在线主题商店；
* 在线配置中心。

App Release 本身即为软件的数据发布渠道。

---

# 3. Scope

## 3.1 V1 支持

V1 必须完成：

* 西北大学本科生；
* 正方教务系统登录；
* 自动读取课程；
* 多学期；
* 本地保存课程；
* Today 首页；
* Week 周课表；
* Month 月历；
* 教学周；
* 单双周；
* 节假日；
* 调休；
* 补课；
* 西大固定作息时间；
* 下一节课计算；
* 当前课程识别；
* 跨天寻找下一节课；
* 上课提醒；
* Android 桌面 Widget；
* 手动添加课程；
* 手动编辑课程；
* 手动隐藏 / 删除；
* 单次调课；
* 单次停课；
* 临时加课；
* 课程颜色；
* 多套官方主题；
* 多学期历史记录；
* 再次导入课表 Diff；
* 本地备份 / 恢复；
* 清除全部数据；
* 用户主动导出诊断信息。

---

## 3.2 V1 不做

明确不做：

* 其他高校；
* 研究生教务；
* 教师端；
* 截图识别课表；
* OCR 导入；
* 用户账号系统；
* 云同步；
* 作业管理；
* 社区；
* 好友；
* 课程评价；
* 成绩查询；
* 空闲教室；
* 抢课；
* 自动选课；
* Google Calendar 同步；
* iCloud Calendar 同步；
* 系统日历写入；
* 第三方主题市场；
* 第三方主题导入；
* 自动上传崩溃日志；
* 用户行为统计；
* 广告。

考试安排未来可以作为独立扩展功能，但不属于 V1 核心课表系统。

---

# 4. Supported Platform

## 4.1 V1

Android。

采用：

> Flutter + Dart

Android 原生部分：

> Kotlin

---

## 4.2 Future

未来支持：

> iOS + Swift / WidgetKit

Domain、Database、Import Normalizer 和业务逻辑不得依赖 Android API，以保证未来可以迁移 iOS。

---

# 5. Technical Baseline

推荐：

* Flutter
* Dart
* Riverpod
* go_router
* SQLite
* Drift
* webview_flutter
* flutter_local_notifications
* Kotlin Android Widget

当前 `webview_flutter` 使用 Android 系统 WebView，并提供 JavaScript Channel；适合实现正方教务 WebView 登录和受控数据桥接。

Drift 基于 SQLite，提供类型安全查询、Migration 和响应式查询，适合作为本项目本地数据层。

`flutter_local_notifications` 支持 Android/iOS 本地通知及定时通知，适合实现离线上课提醒。

Riverpod 当前仍在活跃维护，可作为应用状态层。

`go_router` 由 flutter.dev 发布，适合作为 Flutter 页面导航层。

具体依赖版本不得在 Spec 中永久写死，项目建立时使用稳定兼容版本，并通过 lockfile 固定。

---

# 6. Existing `/schedule` Baseline

现有网站 `/schedule` 页面作为：

> **产品设计原型 + 时间逻辑参考实现**

而不是直接移植代码。

现有实现已经包含：

* Semester；
* Section Time；
* Week Rule；
* Today；
* Week；
* Month；
* 当前课程；
* 下一节；
* 单双周；
* Teaching Week；
* Holiday；
* Makeup Day；
* Current Time Marker。

Flutter App 应继承：

* 简洁视觉语言；
* 当前 / 下一课程优先；
* Week Grid；
* 当前时间线；
* Month Calendar。

但业务模型需要重新设计，以支持：

> 导入 → Diff → 本地修改 → 临时调课 → Widget → Notification。

---

# 7. Application Navigation

底部固定四个一级入口：

```text
首页
课表
日历
设置
```

不单独设置“导入”Tab。

---

# 8. Home — Today

Today 是整个 App 最重要的页面。

设计原则：

> 用户打开 App 最先看到“现在 / 下一步应该去哪里”。

---

## 8.1 NOW

如果当前正在上课：

```text
NOW

计算机网络实验

14:00–17:50
计算机技术实验室 321
徐丹
```

可辅助显示：

```text
第 3 周
7–8 节
```

但不得抢占课程名和地点的视觉层级。

---

# 8.2 NEXT

如果当前没有上课，但之后有课程：

```text
NEXT

软件测试

10:10–12:00
3406
苏峙之
```

不显示实时分钟倒计时。

---

# 8.3 TODAY DONE

当天课程全部结束：

```text
TODAY DONE

今天的课程已经结束

下一节

明天 10:10
IT 项目管理
1209 · 张雨禾
```

---

# 8.4 NO CLASS

当天没有课程：

```text
今天没有课程

下一节

周一 08:00
数据结构实验
计算机技术实验室 321
```

必须跨天继续寻找真正的下一节课程。

不能只寻找“明天”。

---

# 8.5 Today Agenda

首页主卡片下面允许展示当日课程。

必须保持克制。

推荐：

```text
今天

08:00  数据结构实验
10:10  软件测试
14:00  人工智能
```

已经结束课程降低视觉权重。

当前课程突出。

下一课程次突出。

最多直接展示合理数量，内容过多时：

> 查看今日全部课程

---

# 9. Week Schedule

Week 是完整课表。

基本视觉继承 `/schedule`。

包括：

* 时间轴；
* 节次；
* 课程块；
* 当前时间线；
* 今天高亮；
* 当前课程；
* 下一课程；
* 教学周切换；
* 假期标识；
* 调休标识。

---

## 9.1 Weekdays

默认只显示实际需要的日期。

规则：

如果本周只有周一至周五有课程：

```text
一 二 三 四 五
```

如果周六有课程：

```text
一 二 三 四 五 六
```

如果周日也有课程：

```text
一 二 三 四 五 六 日
```

即：

> 动态根据本周 Effective Schedule 决定是否展示周末。

---

# 10. Month Calendar

Month 负责：

* 月历；
* 教学周；
* 节假日；
* 调休；
* 每日课程数量；
* 快速跳转日期。

日期 Cell 可显示：

```text
15
3
```

表示当天 3 节课程块。

节假日：

```text
1
国庆
```

调休日：

```text
10
调课
```

点击日期后显示该日 Agenda。

---

# 11. Course Detail

点击任何课程卡片进入 Bottom Sheet。

显示：

```text
课程名

教师
地点
校区

星期
节次
时间

周次

备注
```

操作：

```text
临时变更
编辑整门课程
修改颜色
隐藏
删除
```

---

# 12. Course Data Model

不能继续沿用：

```text
Course = 一次上课
```

的新手式结构。

必须拆成：

```text
Course
      ↓
MeetingRule[]
```

---

## 12.1 Course

```dart
Course {
    id
    semesterId

    sourceType
    sourceCourseKey?

    name

    note?
    colorOverride?

    hidden
    deleted

    createdAt
    updatedAt
}
```

`sourceType`：

```text
imported
manual
```

---

# 12.2 MeetingRule

一门课程可以包含多个上课规则。

例如：

```text
机器学习

双周：
周四 5–8 节

单周：
周四 7–8 节
```

对应：

```text
Course
 ├─ MeetingRule A
 └─ MeetingRule B
```

字段：

```dart
MeetingRule {
    id
    courseId

    sourceMeetingKey?

    weekday

    startSection
    endSection

    teacher
    campus
    room

    weekMask
}
```

---

# 13. Week Representation

内部推荐使用：

> Week Bitmask

例如：

```text
1–18周
```

转换为：

```text
111111111111111111
```

单周：

```text
101010101010101010
```

双周：

```text
010101010101010101
```

SQLite 直接保存 64-bit Integer。

教学周通常远小于 64，因此足够。

提供 Domain API：

```dart
bool includesWeek(int week);
```

---

# 14. Semester

```dart
Semester {
    id

    academicYear
    term

    label

    remoteTermKey?

    calendarId?

    createdAt
}
```

ID 示例：

```text
2026-2027-1
2026-2027-2
```

---

# 15. Academic Calendar

校历不是服务器数据。

校历直接作为 App Asset：

```text
assets/
  calendars/
    nwu/
      index.json
      2025-2026-1.json
      2025-2026-2.json
      2026-2027-1.json
      2026-2027-2.json
```

---

# 16. CalendarDefinition

示例：

```json
{
  "id": "nwu-2026-2027-1",
  "school": "NWU",

  "academicYear": "2026-2027",
  "term": 1,

  "semesterStartDate": "2026-08-31",
  "week1StartDate": "2026-08-31",

  "semesterEndDate": "2027-01-15",

  "totalWeeks": 20,

  "revision": 1,

  "dateOverrides": []
}
```

---

# 17. Calendar Overrides

仅需要两个核心类型。

## holiday

```json
{
  "date": "2026-10-01",
  "type": "holiday",
  "label": "国庆节"
}
```

效果：

> 当天正常周期课程全部取消。

---

## useScheduleOf

例如学校规定：

> 10 月 10 日执行 10 月 6 日星期二课表。

```json
{
  "date": "2026-10-10",
  "type": "useScheduleOf",
  "sourceDate": "2026-10-06",
  "label": "调课"
}
```

需要注意：

`sourceDate` 表示“使用该日期对应的教学周和星期模板”。

不能再次应用 sourceDate 自身的 holiday override。

防止出现递归。

---

# 18. Calendar Update

没有服务器。

更新链：

```text
学校公布新校历
        ↓
项目维护者修改 calendar asset
        ↓
发布新版 App
        ↓
用户更新 App
        ↓
App 检测 Calendar Revision
        ↓
更新本地 CalendarDefinition
        ↓
重新计算 Effective Schedule
        ↓
重建 Notification
        ↓
刷新 Widget
```

无需用户手动确认。

可以显示轻量提示：

```text
西北大学校历已更新
```

不得弹阻断式 Modal。

---

# 19. Missing Calendar

用户可能提前导入下学期课表，但当前 App 尚未包含对应校历。

必须允许导入。

提示：

```text
课表已成功读取

当前版本尚未包含
2027–2028 学年度第一学期校历。

课程数据已经保存。

在校历更新前，教学周、放假和调休信息
可能无法完全准确计算。
```

禁止要求用户手工填写：

* 开学日期；
* 教学周；
* 假期；
* 作息。

---

# 20. Class Times

作息时间作为 NWU 固定常量写入应用。

当前现有 `/schedule` 使用：

| 节次 | 时间         |
| ---- | ------------ |
| 1    | 08:00–08:50 |
| 2    | 09:00–09:50 |
| 3    | 10:10–11:00 |
| 4    | 11:10–12:00 |
| 5    | 14:00–14:50 |
| 6    | 15:00–15:50 |
| 7    | 16:00–16:50 |
| 8    | 17:00–17:50 |
| 9    | 19:00–19:50 |
| 10   | 20:00–20:50 |
| 11   | 21:00–21:50 |

正式发布前再根据西北大学正式作息核验一次。

不得允许普通用户随意编辑学校作息。

---

# 21. Timezone

所有教学时间一律以：

```text
Asia/Shanghai
```

计算。

即使用户正在：

* 日本；
* 美国；
* 欧洲；

仍以西安校园时间确定课程。

例如：

```text
西安 14:00 上课

用户人在东京
→ 手机当地时间 15:00 时触发上课状态
```

数据库中的：

```text
教学日期
节次
校园时间
```

不得错误转换为设备本地日期。

---

# 22. Effective Schedule Engine

整个项目最核心模块：

```text
ScheduleEngine
```

所有页面不得自己计算课程。

禁止：

```text
Home 自己判断周次
Widget 自己判断周次
Notification 自己判断周次
Week 页面再写一次判断
```

必须统一：

```text
ScheduleEngine
       ↓
Home
Week
Month
Widget
Notification
```

---

# 23. Schedule Resolution Pipeline

计算日期 `D` 的课程：

```text
CalendarDefinition
        ↓
得到 AcademicTemplateDate

Base Courses
        ↓
Local Course Modification
        ↓
WeekRule Matching
        ↓
MeetingRule Matching
        ↓
Calendar Override
        ↓
CourseException
        ↓
EffectiveCourseInstance[]
```

---

# 24. CourseException

任何“只修改某一次”的行为均不得修改原始周期课程。

定义：

```text
CourseException
```

类型：

```text
MOVE
CANCEL
ADD
```

---

# 25. MOVE

原课程：

```text
第 7 周
周一 3–4 节
3406
```

老师通知：

```text
本周改到
周二 7–8 节
3508
```

保存：

```dart
CourseException {
    type: MOVE

    courseId
    sourceMeetingId

    sourceDate

    targetDate
    targetStartSection
    targetEndSection

    teacherOverride?
    campusOverride?
    roomOverride?
}
```

Schedule Engine 必须：

1. 删除 source instance；
2. 在 targetDate 插入新的 instance。

---

# 26. CANCEL

```dart
CourseException {
    type: CANCEL

    courseId
    sourceMeetingId
    sourceDate
}
```

仅取消本次。

不修改后续课程。

---

# 27. ADD

支持：

> 临时加课

用户可：

1. 选择已有课程作为模板；
2. 创建临时课程。

字段：

```text
日期
课程名
教师
地点
开始节
结束节
```

ADD 应具有最高优先级，即：

即使目标日期原本是学校假期，用户主动添加的临时课程仍然显示。

---

# 28. Modification UI

点击某次课程 → 编辑。

仅提供：

```text
仅修改本次
修改整门课程
```

不提供：

> “从本次开始修改后面全部课程”

避免引入复杂 recurrence splitting。

---

# 29. Whole Course Edit

“修改整门课程”允许修改：

* 课程名；
* 教师；
* 地点；
* 校区；
* 星期；
* 节次；
* 周次；
* 备注；
* 颜色。

内部仍保留上一次 Import Snapshot。

这样重新导入教务数据时可以执行 Three-way Merge。

---

# 30. Imported Data Snapshot

每次成功导入后保存：

```text
ImportSnapshot
```

包含：

```text
semesterId
importTime
adapterVersion
normalizedData
hash
```

不得保存：

* HTML 页面；
* Cookie；
* 密码；
* 登录账号；
* Session；
* 完整 HTTP Response。

只保存规范化后的课程结构。

---

# 31. Re-import Same Semester

如果已有：

```text
2026–2027 第一学期
```

再次导入同一 Semester：

必须执行：

```text
Diff
```

而不是直接覆盖。

例如：

```text
课表发生变化

新增 1
删除 1
修改 2

＋ 机器学习实验

－ 大学语文

~ 软件测试
  教室
  3406 → 3508
```

用户确认：

```text
更新课表
取消
```

取消必须保证：

> 数据库完全不发生变化。

---

# 32. Import Different Semester

当前：

```text
2026–2027 第一学期
```

导入：

```text
2026–2027 第二学期
```

自动判断为新 Semester。

显示：

```text
发现新的学期

2026–2027 学年度
第二学期

建立新课表
取消
```

不显示“覆盖第一学期”。

---

# 33. Semester Auto Selection

根据当前 `Asia/Shanghai` 日期和 CalendarDefinition：

自动选择当前学期。

如果：

```text
第二学期课表已经提前导入
```

到了第二学期开学日期：

自动切换。

无需用户确认。

---

# 34. Historical Semesters

全部保留。

设置：

```text
学期管理

● 2026–2027 第一学期
  当前

  2025–2026 第二学期
  2025–2026 第一学期
```

用户可以：

* 查看；
* 手动切换；
* 删除。

---

# 35. Three-way Merge

这是重新导入最重要的规则。

定义：

```text
S0 = 上次教务导入值
L  = 当前本地值
S1 = 新教务值
```

---

## Case A

```text
S0 == L
S0 != S1
```

说明用户没有改过。

结果：

> 使用 S1。

---

## Case B

```text
S0 != L
S0 == S1
```

说明只有用户修改。

结果：

> 保留 L。

---

## Case C

```text
S0 != L
S0 != S1
L != S1
```

产生冲突。

显示：

```text
软件测试

教室发生冲突

我的设置
3508

教务系统
3407

[使用我的]
[使用教务]
```

---

## Case D

```text
L == S1
```

无需冲突。

---

# 36. Fields Never Conflicted

以下字段永远属于用户本地数据：

```text
note
colorOverride
hidden
```

重新导入不得覆盖。

---

# 37. Local Modification UI

用户手动修改课程后：

**不显示长期“已手动修改”Badge。**

避免 UI 变脏。

内部仍必须记录足够的信息完成 Three-way Merge。

只有下一次导入发生实际冲突时再提醒用户。

---

# 38. Deleted Imported Course

如果用户删除了一门教务导入课程：

不能在下一次导入时无条件复活。

内部建立：

```text
Local Tombstone
```

若 remote course 仍存在：

默认继续保持删除状态。

Diff 页面可提供：

```text
恢复该课程
```

---

# 39. Manual Course

用户手动添加课程：

```text
sourceType = manual
```

重新导入教务系统时：

完全不参与 Remote Diff。

永远保留。

---

# 40. NWU Import Experience

入口：

```text
设置
→ 学期与课表
→ 从教务系统导入
```

---

# 41. Import Flow

完整流程：

```text
从教务系统导入
        ↓
打开专用 WebView
        ↓
西北大学正方教务系统
        ↓
用户自行登录
        ↓
App 检测 Authentication Success
        ↓
获取可用 Semester
        ↓
用户选择 Semester
        ↓
读取课程数据
        ↓
Normalize
        ↓
Validate
        ↓
Preview
        ↓
Diff / New Semester
        ↓
用户确认
        ↓
Database Transaction
        ↓
Clear WebView
        ↓
Refresh Schedule
        ↓
Reschedule Notification
        ↓
Refresh Widget
```

---

# 42. Login Privacy

App 不得：

* 读取账号；
* 保存学号；
* 保存密码；
* 注入密码获取代码；
* Hook 输入框；
* 拦截密码；
* 上传密码；
* 保存 Cookie。

登录行为只发生于：

> 系统 WebView 中的 NWU 官方网页。

---

# 43. WebView Session

用户明确要求：

> 每次导入后清除登录状态。

因此：

进入 Import：

```text
创建临时 WebView Session
```

结束 Import，无论：

* 成功；
* 失败；
* 用户取消；

都执行：

```text
remove cookies
clear web storage
clear cache
clear history
clear form data
destroy importer session
```

下一次导入：

> 重新登录。

---

# 44. JS Injection Safety

JavaScript Bridge 不应从登录页面开始注入。

推荐：

```text
Login Page
→ no parser bridge

Authenticated Page
→ validate URL/domain

Timetable Context
→ inject parser
```

允许域必须是：

```text
NWU 官方教务 / 官方认证域
```

非白名单域：

> 禁止访问 Bridge。

---

# 45. Import Strategy

优先：

> 正方内部课程接口。

Fallback：

> DOM Parser。

流程：

```text
API Parser
   ↓ fail
DOM Parser
   ↓ fail
Import Error
```

公开的正方 V9 适配实现表明，个人课表通常包含类似：

```text
/kbcx/xskbcx_cxXskbcxIndex.html

/kbcx/xskbcx_cxXsgrkb.html
```

的页面/数据接口，并能返回课程、教师、地点、星期、节次和周次等结构。

但：

> **西北大学实际 endpoint、gnmkdm、POST 参数和响应 schema 必须在真实 NWU 登录环境中验证。**

不得直接硬编码其他学校使用的：

```text
N2151
N253508
```

---

# 46. Adapter Architecture

定义：

```dart
abstract interface class TimetableImporter {
    Future<List<RemoteSemester>> getSemesters();

    Future<ImportResult> importSemester(
        RemoteSemester semester
    );
}
```

实现：

```text
NwuZhengfangV9Importer
```

未来如果正方升级：

```text
NwuZhengfangV10Importer
```

无需修改 Schedule Engine。

---

# 47. Normalized Imported Fields

只提取以下产品课表字段：

```text
课程名
教师
校区
教室
星期
开始节
结束节
周次
单双周
```

允许内部额外保存：

```text
opaque source id
fingerprint
```

仅用于 Diff Match。

不可显示给用户，也不属于个人资料采集。

---

# 48. Remote Matching

优先级：

```text
1 Remote Stable ID
2 Versioned synthetic fingerprint from semester, normalized name and schedule shape
3 Conservative similarity matching across complete meeting sets
4 Add / Remove
```

如果无法安全确定：

> 宁可显示“一项删除 + 一项新增”，也不要错误合并两门课程。

---

# 49. Import Preview

首次导入必须 Preview。

例如：

```text
读取完成

8 门课程
14 个上课安排

软件测试
周一 3–4节
1–18周
3406

计算机网络
周二 3–4节
1–18周
1310

...

确认导入
重新读取
取消
```

---

# 50. Import Validation

在写数据库前验证：

* Course Name 非空；
* Weekday ∈ 1..7；
* StartSection 合法；
* EndSection 合法；
* start <= end；
* Week 不超过合理范围；
* Semester 合法；
* 无非法空 ID；
* 无完全重复 MeetingRule。

异常课程不应直接静默丢弃。

Preview 应显示：

```text
发现 1 条可能异常的数据
```

---

# 51. Import Transaction

最终确认时：

必须 SQLite Transaction。

即：

```text
BEGIN

write semester
write courses
write meetings
write source snapshot
write diff result

COMMIT
```

任何异常：

```text
ROLLBACK
```

禁止留下“导入了一半”的课表。

---

# 52. Diagnostic Export

导入失败：

```text
无法读取课表

重新尝试
导出诊断信息
```

只有用户主动点击后才生成。

Diagnostic 可包含：

```text
App Version
Android Version
WebView Version
Importer Version

current URL path
HTTP status
parser stage
selector existence
response schema keys
error stack
```

不得包含：

```text
Cookie
Password
Username
Student ID
Full HTML
Authentication Token
完整课程内容
```

生成本地文件，由用户自行：

* 保存；
* 分享；
* 发给开发者。

App 不主动上传。

---

# 53. Notification

全局设置：

```text
上课提醒
[开启]

提前：
15 分钟
```

默认：

```text
15 分钟
```

用户可以统一修改。

推荐：

```text
5
10
15
20
30
60
```

---

# 54. Notification Scope

不支持：

* 每门课单独时间；
* 两次提醒；
* “第一节课特殊提醒”。

保持简单。

---

# 55. Notification Content

```text
软件测试

3406 · 苏峙之
10:10 上课
```

必须包含：

```text
课程名
地点
教师
```

---

# 56. Notification Permission

App 首次启动：

> 不主动请求通知权限。

只有用户：

```text
设置 → 开启课程提醒
```

时才请求系统权限。

拒绝后：

App 正常工作。

---

# 57. Notification Engine

通知必须基于：

```text
EffectiveCourseInstance
```

而不是原始 Course。

意味着：

假期：

> 不通知。

调休：

> 按调休后课程通知。

临时 MOVE：

> 按新时间通知。

CANCEL：

> 取消通知。

ADD：

> 新建通知。

---

# 58. Notification Rebuild

以下行为之后必须：

```text
NotificationScheduler.rebuild()
```

包括：

* 导入；
* Diff 更新；
* 新建 Semester；
* 删除课程；
* 修改课程；
* MOVE；
* CANCEL；
* ADD；
* Calendar Revision Update；
* 恢复备份；
* App 升级。

---

# 59. Android Alarm Policy

V1 优先避免为了课程提醒申请额外的高敏感 Exact Alarm 权限。

先使用普通系统允许的本地定时通知机制。

如果实际 Android 测试证明部分厂商 ROM 延迟严重，再单独评估 Exact Alarm。

不能为了理论上的秒级准确性增加不必要权限。

---

# 60. Android Widget

V1 实现三个尺寸。

---

# 61. Small Widget

显示：

> 下一节真正需要去上的课程。

```text
NEXT

软件测试
10:10
3406
```

如果当前正在上课：

仍寻找之后的下一节。

---

# 62. Medium Widget

显示：

```text
TODAY

08:00 数据结构实验
10:10 软件测试
14:00 人工智能
```

可以通过样式突出：

* Current；
* Next。

---

# 63. Large Widget

显示：

```text
TODAY

...

TOMORROW

...
```

即：

> 今天 + 明天。

如果明天无课程：

仍显示：

```text
Tomorrow
No Class
```

而不是继续无限向后展开。

---

# 64. Widget Click

小 Widget：

```text
点击 → Home
```

Medium / Large：

点击具体课程：

```text
→ Course Detail
```

点击空白：

```text
→ Home
```

---

# 65. Widget Architecture

禁止 Widget 自己实现 Schedule Engine。

Flutter：

```text
ScheduleEngine
       ↓
WidgetSnapshotBuilder
       ↓
WidgetSnapshot JSON
       ↓
Android Shared Storage
       ↓
Kotlin Widget
```

例如：

```json
{
  "generatedAt": "...",

  "next": {},

  "today": [],
  "tomorrow": []
}
```

Native Widget 只负责：

> Render。

不负责：

* 周次判断；
* 调休判断；
* 下一节计算。

---

# 66. Widget Refresh

以下事件立即更新：

* 导入；
* 编辑；
* 调课；
* 停课；
* 加课；
* Calendar Update；
* 日期变化；
* 课程边界变化。

因为没有分钟倒计时，不需要高频刷新。

---

# 67. Theme System

仅提供：

> 官方内置主题。

不允许：

* 用户安装主题文件；
* 在线主题；
* JS Theme；
* 第三方代码；
* Theme Store。

---

# 68. Theme Ownership

主题必须随 App Release 打包。

可以由项目贡献者提交代码建议，但：

> 最终主题必须由项目 Owner 审核、合并并作为官方 App 代码发布。

用户不能自行安装外部 Theme Package。

---

# 69. Theme Capability

主题可以改变：

* 背景；
* 课程配色；
* 卡片圆角；
* 边框；
* 阴影；
* 字号；
* 字重；
* 间距；
* Grid 风格；
* Course Card 信息排列；
* Today Card 风格；
* Month Cell 风格。

不能改变：

* Navigation；
* Domain Logic；
* Schedule Engine；
* 数据模型；
* Import；
* Notification；
* Widget Semantic。

---

# 70. Theme Contract

所有官方主题必须实现同一个：

```dart
ScheduleThemeDefinition
```

例如：

```dart
ScheduleThemeDefinition {
    id
    name

    colors
    typography
    spacing

    courseCardStyle
    weekGridStyle
    todayCardStyle
    monthStyle
}
```

官方可以提供多个主题。

V1 推荐至少：

```text
3 套
```

---

# 71. Course Color Override

用户可单独修改某门课程颜色。

优先级：

```text
Course Override Color
        >
Theme Course Color
        >
Default
```

颜色设置属于用户本地数据。

重新导入不得清除。

---

# 72. Local Database

推荐 Drift + SQLite。

主要表：

```text
semesters

courses

meeting_rules

course_exceptions

import_snapshots

deleted_source_items
```

设置类小数据可以存 Preferences。

---

# 73. Database Schema

核心关系：

```text
Semester
   │
   ├──── Course
   │        │
   │        └──── MeetingRule
   │
   ├──── CourseException
   │
   └──── ImportSnapshot
```

---

# 74. Domain Layer

Domain 必须：

> Pure Dart。

禁止依赖：

```text
Flutter Widget
BuildContext
Android API
WebView
SQLite implementation
```

核心接口：

```dart
ScheduleEngine

CalendarEngine

ImportDiffEngine

SemesterResolver

NotificationPlanner

WidgetSnapshotBuilder
```

---

# 75. ScheduleEngine Interface

建议：

```dart
abstract interface class ScheduleEngine {
  Future<List<EffectiveCourseInstance>>
      getCoursesForDate(LocalDate date);

  Future<ScheduleNowState>
      getStateAt(DateTime instant);

  Future<EffectiveCourseInstance?>
      getNextCourse(DateTime instant);

  Future<List<EffectiveCourseInstance>>
      getCoursesForWeek(int teachingWeek);
}
```

---

# 76. ScheduleNowState

```dart
sealed class ScheduleNowState
```

类型：

```text
current

next

finishedToday

noClassToday
```

Home 页面只渲染这个状态。

---

# 77. Next Course Definition

`getNextCourse(now)`：

必须考虑：

```text
当前 Semester
Calendar
教学周
单双周
周末
Holiday
UseScheduleOf
Local Edit
MOVE
CANCEL
ADD
```

搜索直到：

```text
Semester End
```

如果整个 Semester 都没有课程：

返回 null。

---

# 78. App Architecture

采用：

```text
Presentation
     ↓
Application
     ↓
Domain
     ↓
Repository Interface
     ↓
Data / Platform
```

---

# 79. Recommended Project Structure

```text
lib/

  app/
    app.dart
    router.dart
    bootstrap.dart

  core/
    errors/
    time/
    utils/

  domain/

    calendar/
      calendar_definition.dart
      calendar_engine.dart

    course/
      course.dart
      meeting_rule.dart
      course_exception.dart

    semester/
      semester.dart
      semester_resolver.dart

    schedule/
      effective_course_instance.dart
      schedule_engine.dart
      schedule_now_state.dart

    import/
      import_models.dart
      import_diff_engine.dart

  data/

    database/
      app_database.dart
      tables/
      migrations/

    repositories/

    calendar/
      bundled_calendar_repository.dart

    import/
      nwu_zhengfang/

  features/

    home/
      presentation/
      application/

    timetable/
      presentation/
      application/

    month/
      presentation/
      application/

    import/
      presentation/
      application/

    course_detail/

    semester_management/

    settings/

    backup/

    appearance/

  platform/

    notifications/

    widget/

    webview/

  theme/
    theme_registry.dart
    themes/

assets/

  calendars/
    nwu/

android/

  widget/
```

---

# 80. Android Native Responsibilities

Kotlin 仅负责：

* AppWidget；
* Flutter Platform Channel；
* Widget Shared Storage；
* 必要 Android lifecycle hooks。

业务逻辑禁止写入 Kotlin。

否则未来 iOS 会被迫重新实现。

---

# 81. Backup

系统自动云备份：

> 禁止。

Android：

```text
Auto Backup disabled
```

未来 iOS：

App 数据库标记为：

> 不进入 iCloud Backup。

---

# 82. Manual Export

提供：

```text
设置
→ 数据与隐私
→ 导出完整备份
```

文件：

```text
nwu-schedule-backup.json
```

建议：

```json
{
  "format": "nwu-schedule-backup",
  "schemaVersion": 1,
  "createdAt": "...",

  "semesters": [],
  "courses": [],
  "meetingRules": [],
  "exceptions": [],

  "settings": {},
  "appearance": {}
}
```

---

# 83. Backup Must Not Contain

禁止：

```text
Cookie
Password
Username
Session
SSO Token
WebView Storage
```

---

# 84. Restore

```text
导入完整备份
```

流程：

```text
选择文件
↓
Validate Schema
↓
显示概要
↓
确认恢复
↓
Replace Local Dataset
↓
Rebuild Notifications
↓
Refresh Widget
```

V1 不做复杂的：

> Backup Merge。

恢复行为：

> 替换当前本地数据。

执行前必须二次确认。

---

# 85. Clear All Data

设置：

```text
清除所有数据
```

执行后删除：

* SQLite；
* Preferences；
* Semester；
* Course；
* Exception；
* Backup cache；
* WebView Cookie；
* WebStorage；
* Notification；
* Widget Snapshot。

恢复：

> 首次安装状态。

---

# 86. Privacy Model

本项目禁止集成：

* Analytics；
* Ads；
* Firebase Analytics；
* 用户追踪；
* 自动 Crash Reporter；
* Device Fingerprint；
* 第三方行为 SDK。

---

# 87. Network Model

正常运行：

```text
0 network request
```

用户主动：

```text
从教务系统导入
```

才允许 WebView 联网。

App 自己没有课表 API。

---

# 88. Permissions

V1 预期权限保持最低。

需要：

```text
INTERNET
POST_NOTIFICATIONS
```

其中 Notification 只有用户开启提醒后请求。

不需要：

```text
Location
Contacts
Calendar
Camera
Microphone
SMS
Phone
Storage 全盘权限
Bluetooth
```

备份文件使用系统 Document Picker。

---

# 89. Security

Release Build：

```text
WebView Debugging = false
```

禁止 cleartext HTTP。

网络默认只接受 HTTPS。

教务 Adapter 必须校验：

```text
scheme
host
path
```

JavaScript Channel 数据必须：

* JSON；
* Schema Validation；
* Payload Size Limit；
* Field Whitelist。

---

# 90. UI Design Language

参考现有 `/schedule`：

* 简洁；
* 大量留白；
* 低饱和；
* 非商业化；
* 非“超级 App”；
* 信息层级明显；
* 时间信息优先。

避免：

* Dashboard 堆卡片；
* 十几个功能入口；
* 彩色渐变滥用；
* Banner；
* 广告式 UI。

---

# 91. Course Card Priority

信息层级：

```text
课程名
↓
地点
↓
时间
↓
教师
↓
辅助信息
```

课程代码、教学班、学分和考核方式不是产品级课程字段，不进入课程卡片、详情、导入 Diff、备份或普通课表逻辑。

---

# 92. Accessibility

必须满足：

* 48dp 左右触控区域；
* 文字与背景保持可读对比度；
* 不仅依赖颜色表达状态；
* TalkBack 提供 Course semantic label；
* 当前 / 下一节有文字状态；
* 字体放大后不能发生核心信息消失。

---

# 93. Error Handling

错误必须按照 Domain Error 分类。

例如：

```text
AuthenticationExpired
TimetableEndpointUnavailable
ParserMismatch
InvalidRemoteData
CalendarMissing
DatabaseFailure
BackupInvalid
NotificationPermissionDenied
```

UI 不直接显示：

```text
NullPointer
JSONDecodeException
SQLiteException
```

---

# 94. Import Errors

示例：

```text
登录状态已经失效

请重新登录教务系统。
```

而不是：

```text
HTTP 401
```

Parser：

```text
当前版本暂时无法识别教务系统课表。

教务系统页面可能已经发生变化。

[重新尝试]
[导出诊断信息]
```

---

# 95. Empty States

无课表：

```text
还没有课表

从西北大学教务系统导入后，
这里会自动结合校历显示课程。

[导入课表]
```

---

# 96. First Launch

首次启动不要：

* 强制注册；
* 强制登录；
* 强制通知授权；
* 强制看教程。

页面：

```text
欢迎

西北大学课程表

无广告
本地存储
结合学校校历

[导入我的课表]

稍后再说
```

---

# 97. Settings Structure

建议：

```text
设置

学期与课表
  当前学期
  学期管理
  从教务系统导入

提醒
  上课提醒
  提前时间

外观
  主题
  课程颜色

数据与隐私
  导出备份
  导入备份
  清除所有数据

关于
  App Version
  隐私说明
  开源许可证
```

---

# 98. Test Strategy

测试是项目重点。

Schedule Engine 必须优先写测试，再写 UI。

---

# 99. Unit Tests — Calendar

覆盖：

```text
普通日期
学期第一天
学期最后一天
Semester 外日期

Holiday

UseScheduleOf

单周
双周

跨月
跨年
```

---

# 100. Unit Tests — Schedule

覆盖：

```text
当前课程
下一课程
当天全部结束

今天无课程
明天有课程

连续三天无课
跨周寻找下一课

周末课程

Holiday

调休
```

---

# 101. Exception Tests

MOVE：

```text
Source 不再出现
Target 正确出现
```

CANCEL：

```text
Source 消失
```

ADD：

```text
目标日期出现
```

尤其测试：

```text
MOVE 到 Holiday
ADD 到 Holiday
```

显式用户 Exception 应生效。

---

# 102. Diff Tests

必须测试完整 Three-way Merge：

```text
Remote only changes
Local only changes
Both same change
Both conflicting change
Remote delete
Remote add
Local delete
Manual course
```

---

# 103. Import Parser Tests

不得在 CI 使用真实教务账号。

建立脱敏 Fixtures：

```text
test/
 fixtures/
   zhengfang/
     timetable_index.html
     timetable_response.json
```

测试：

```text
parseSemester
parseCourse
parseWeekRule
parseTeacher
parseRoom
parseSections
```

真实 NWU 登录：

> Manual Integration Test。

---

# 104. Golden UI Tests

关键页面：

* Home NOW；
* Home NEXT；
* Home DONE；
* Home NO CLASS；
* Week；
* Month；
* Course Detail；
* Import Preview；
* Diff；
* Theme A；
* Theme B；
* Theme C。

---

# 105. Privacy Test

Release 前用 Network Inspector 验证：

Home：

```text
0 request
```

Week：

```text
0 request
```

Month：

```text
0 request
```

Widget：

```text
0 request
```

Notification：

```text
0 request
```

只有 Import WebView：

```text
NWU official domains
```

可以联网。

---

# 106. WebView Privacy Acceptance Test

导入完成后：

重新进入 Import：

> 必须要求重新登录。

证明：

```text
Cookie 已清除。
```

---

# 107. Backup Test

流程：

```text
创建课表
修改颜色
添加临时调课
添加手工课程
设置通知
设置主题

↓ Export
↓ Clear App
↓ Restore

所有数据一致
```

---

# 108. Widget Acceptance

Small：

必须显示正确下一节。

Medium：

必须和 App Today 一致。

Large：

必须和 App Today + Tomorrow 一致。

任何情况下：

> Widget 与 Home 不得对同一时刻给出不同课程结果。

---

# 109. Notification Acceptance

例如：

```text
课程
14:00

Reminder
15 min
```

应计划：

```text
13:45 Asia/Shanghai
```

MOVE 到 16:00：

旧：

```text
13:45 notification
```

必须取消。

新：

```text
15:45 notification
```

必须创建。

---

# 110. Performance Target

目标：

冷启动：

> 中端 Android 设备约 1 秒级出现基础 UI。

Home Schedule Query：

> 应接近即时。

单学期只有几十个课程规则，不允许在运行时采用低效全量暴力扫描。

Widget：

> 不启动完整 Flutter Engine 进行课表计算。

使用 Snapshot。

---

# 111. CI

每次 PR：

```text
dart format check
flutter analyze
unit tests
parser tests
database migration tests
golden tests
calendar validation
```

Main Branch：

再：

```text
build Android release
```

---

# 112. Calendar Validation Script

Build 前检查所有 Calendar Asset：

```text
ID unique
Academic Year valid
Term valid
Date valid
week1StartDate valid
totalWeeks valid
Override duplicate
sourceDate valid
revision valid
```

错误：

> CI Fail。

不能等用户更新 App 后才发现校历 JSON 写错。

---

# 113. Database Migration

数据库：

```text
schemaVersion
```

每次结构修改必须 Migration。

禁止：

> App 更新 → 删除旧数据库重新建。

用户历史学期必须永久兼容升级。

---

# 114. Release Strategy

V1 初期：

```text
APK / GitHub Release / 内测
```

稳定后：

```text
Android App Store Distribution
```

因此从第一版开始：

* Release Signing；
* Migration；
* Privacy；
* Package Name；
* Version Code；

都按正式产品标准处理。

---

# 115. Development Phases

## Phase 0 — Foundation

建立：

```text
Flutter Project
CI
Riverpod
Router
Drift
Theme
```

不要马上碰教务系统。

---

## Phase 1 — Domain Engine

先完成：

```text
Semester
Calendar
Course
MeetingRule
Exception

ScheduleEngine
NextCourse
NowState
```

全部 Unit Test。

这是整个项目最重要的 Phase。

---

## Phase 2 — Static UI Prototype

使用现有 `/schedule` 的示例课程数据。

完成：

```text
Home
Week
Month
Course Detail
```

此时 App 不需要教务导入。

先验证产品体验。

---

## Phase 3 — Database

将 Static Data 替换：

```text
SQLite / Drift
```

实现：

```text
CRUD
Semester
Course
Exception
```

---

## Phase 4 — Manual Editing

实现：

```text
添加课程
编辑
删除
隐藏
颜色
MOVE
CANCEL
ADD
```

---

## Phase 5 — Zhengfang Adapter

真实研究西北大学：

```text
Authentication
Timetable URL
Semester Params
Course API
Response Schema
```

建立：

```text
NwuZhengfangV9Importer
```

先 API。

再 DOM Fallback。

---

## Phase 6 — Import

完成：

```text
WebView
Semester Select
Normalize
Validation
Preview
Transaction
Cookie Cleanup
```

---

## Phase 7 — Diff

实现：

```text
ImportSnapshot
Remote Matching
Three-way Merge
Conflict UI
Tombstone
```

---

## Phase 8 — Notification

统一使用 Schedule Engine 结果。

实现：

```text
Scheduler
Permission
Rebuild
```

---

## Phase 9 — Widget

实现：

```text
WidgetSnapshotBuilder
Kotlin Widget

Small
Medium
Large
```

---

## Phase 10 — Backup & Privacy

实现：

```text
Export
Import
Clear Data
Diagnostic
Network Audit
```

---

## Phase 11 — Themes

至少提供：

```text
3 套官方主题
```

然后做 Golden Tests。

---

## Phase 12 — Release QA

真实学生账号：

```text
Fresh Import
Re-import
Semester Switch
Holiday
Makeup
Notification
Widget
Backup
Offline
```

确认后 Release。

---

# 116. Critical Architecture Rules

以下规则属于项目红线。

### Rule 1

任何页面不得自行实现周次计算。

必须调用：

```text
ScheduleEngine
```

### Rule 2

教务系统数据不得直接进入 UI。

必须：

```text
Remote
→ Normalize
→ Validate
→ Domain
→ Database
→ UI
```

### Rule 3

Calendar 和 Course 分离。

禁止把：

```text
国庆节
```

写进 Course。

### Rule 4

单次调课必须使用 Exception。

不得破坏原 recurrence。

### Rule 5

用户修改不得覆盖 Import Snapshot。

否则无法 Three-way Merge。

### Rule 6

Widget 不维护第二套课表逻辑。

### Rule 7

Notification 不维护第二套课表逻辑。

### Rule 8

Import Flow 结束必须销毁 WebView Login Session。

### Rule 9

正常 App 页面不得依赖网络。

### Rule 10

任何新增功能都不得以牺牲“简单课程表工具”的产品定位为代价。

---

# 117. Core Domain Formula

最终真正显示的课表可以概括为：

```text
Imported / Manual Course Rules
            +
Local Whole-course Modification
            +
NWU Calendar
            +
Date-specific Exception
            =
Effective Schedule
```

然后：

```text
Effective Schedule
      │
      ├── Home
      ├── Week
      ├── Month
      ├── Notification
      └── Widget
```

这是整个工程最重要的设计。

---

# 118. Definition of Done — V1

只有同时满足以下条件才能称为 V1 完成：

### Import

西北大学本科生可以：

```text
登录正方
→ 选择学期
→ 读取课表
→ Preview
→ 保存
```

App 不保存账号密码或 Cookie。

### Calendar

课程可以正确结合：

```text
教学周
单双周
节假日
调休
补课
```

### Home

任何时间打开 App：

能够正确显示：

```text
NOW
NEXT
TODAY DONE
NO CLASS
```

### Next Course

能够跨：

```text
天
周末
假期
单双周
```

找到真正下一课程。

### Re-import

同一学期重新导入：

必须展示 Diff。

不得静默覆盖用户修改。

### Exception

可以：

```text
仅本次调课
停课
临时加课
```

### Offline

教务导入完成后：

断网仍可使用全部核心功能。

### Notification

能按照 Effective Schedule 提醒。

### Widget

具有：

```text
Small → Next
Medium → Today
Large → Today + Tomorrow
```

### Privacy

无：

```text
广告
账号
Analytics
Backend
自动数据上传
```

### Backup

支持：

```text
Export
Restore
Clear All Data
```

### Stability

数据库升级不能破坏历史数据。

---

# 119. Final Product Boundary

这个 App 最终不是：

> “另一个教务系统”。

也不是：

> “大学生生活超级 App”。

它应该一直保持：

> **一个打开就告诉你“下一节课什么时候、在哪”的西北大学专用课程表。**

完整课表、月历、通知、Widget、校历和调课全部围绕这一目标服务。

产品复杂度应该主要存在于：

> **内部 Schedule Engine**

而不是暴露给用户。

因此用户最终体验应尽量接近：

```text
第一次：

登录教务
→ 导入

以后：

打开 App
→ 看下一节

甚至：

不用打开 App
→ 看 Widget
```

这就是 V1 的核心产品形态。
