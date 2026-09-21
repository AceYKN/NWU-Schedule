# NWU 正方真实集成验收

这份清单只用于本地 Android 真机或模拟器。不得把真实学号、密码、Cookie、Session、课表响应或诊断文件提交到仓库、Issue、PR 或 CI。

## 环境

- Android 真机或模拟器，系统 WebView 可用；
- 已安装当前 debug APK；
- 真实西北大学本科生账号；
- 能访问 `https://jwgl.nwu.edu.cn/jwglxt/`；
- 记录设备型号、Android 版本、WebView 版本和 APK commit，不记录账号信息。

公开入口 `https://jwgl.nwu.edu.cn/jwglxt/` 当前展示的是登录页；因此入口页和登录路径不应注入课表 Bridge，只有进入课表上下文后才允许读取页面数据。公开页面可见的登录入口为 [`/jwglxt/`](https://jwgl.nwu.edu.cn/jwglxt/) 和 [`/jwglxt/xtgl/login_slogin.html`](https://jwgl.nwu.edu.cn/jwglxt/xtgl/login_slogin.html)。

当前根据真实设备提供的课表页路径，Bridge 只信任以下两个已观察的个人课表页面：

```text
/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html
/jwglxt/kbcx/xskbcx_cxXsgrkb.html
```

其余仍在官方域名下的页面可以继续导航，但不会获得课表 JavaScript Bridge；即使路径匹配，页面仍必须实际暴露 `#kblist_table` 或明确的课表 payload 才会启用 Bridge。页面路径或 DOM 结构变化时应导出诊断后再更新适配器。当前诊断版本为 `nwu-zhengfang-v9-dom-v9`。这项路径验证不等同于真实 API endpoint、`gnmkdm` 或响应 schema 已验证。

真实页面 DOM 已验证存在列表课表 `#kblist_table`。当前主 DOM 适配器只依赖以下已观察结构：

```text
#kblist_table
xq_rowspan_<1..7>             -> 星期分组
jc_<weekday>-<start>-<end>    -> 节次范围
```

当前 V9 列表页的课程单元使用 `.timetable_con`：课程名在 `.title`，带 `glyphicon-calendar` 的字体节点提供“节次/周次”，带 `glyphicon-map-marker` 的字体节点提供“校区/教室”，带 `glyphicon-user` 的字体节点提供教师。真实页面的日历字段可能显示为 `周数：1-18周`，适配器会去掉这个展示标签后再解析周次。旧版或脱敏 fixture 中的 `周数：`、`校区:`、`上课地点：`、`教师：` 标签分支仍保留。DOM 适配器优先从这些结构化字段切分产品字段，不再从视觉矩阵表中猜列位置；`#kbgrid_table_0` 不作为主解析源。课程代码、教学班、学分和考核方式不属于产品课表字段，适配器不会解析或输出它们；没有稳定远端 ID 时使用版本化、学期作用域的课程名与完整上课结构指纹，并在 Dart Diff 层做保守匹配。若 `#kblist_table` 存在但结构不符合上述契约，应直接产生校验错误并停止导入，不回退到启发式解析。仓库中的 `nwu_kblist_fixture.html` 只保留脱敏后的结构与合成课程数据，不得提交真实姓名、学号或完整原始 DOM。

2026-09-21 的字段级真实页面观察还确认：课表筛选表单的 GET/POST action 都是 `/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html`，学年与学期字段名为 `xnm`、`xqm`；当前页返回的是服务端 HTML 列表，而不是已确认的 JSON 课表响应。课程节点及其父级只暴露展示 class，没有观察到稳定课程/教学班 ID，也没有在已加载脚本和资源路径中确认独立 JSON endpoint。因此当前实现把该服务端列表 DOM 作为经过 allowlist 保护的正式兜底源，并保留稳定远端 ID 一旦被真实接口提供后再接入的边界。

## 首次导入

1. 从“设置 → 从教务系统导入”进入。
2. 确认 WebView 初始地址和后续导航始终是允许的 NWU HTTPS 域名；其他域名应被阻止。
3. 在 WebView 内自行登录，不把账号、密码输入到 App 的其他控件。
4. 打开个人课表页面，点击“读取课表”。
5. 确认学期列表、课程名、教师、校区、上课地点、星期、节次和周次与教务系统一致。
6. 确认 Preview 先出现，点击确认后课程、上课安排和导入快照一起保存。
7. 关闭导入页面，再次进入导入，确认必须重新登录。

## Diff 与本地修改

- 同一学期再次导入时必须出现新增、更新、删除和冲突统计；取消后数据库不变。
- 先改课程备注、颜色、隐藏状态，再导入；确认这些本地字段不被覆盖。
- 制造一次教务字段变化，确认冲突页可以分别选择“保留本地”和“采用教务”；教师、校区、教室、星期、节次和周次按单个上课安排字段决策，不会把无关字段一起覆盖。
- 删除一门导入课程后再次导入，确认默认仍删除；明确勾选“恢复”后才复活。
- 导入不同学期，确认 Preview 显示“建立新课表”，其他学期不被覆盖。

## 离线与平台功能

导入完成后断网，逐项确认首页、周课表、月历、手动编辑、MOVE/CANCEL/ADD、历史学期、Widget 和通知计划仍可用。

开启提醒后确认：

- 首次启动不会主动申请通知权限；
- 只有在设置中开启时才申请；
- 提前时间可选 5/10/15/20/30/60 分钟；
- 节假日不通知，调休按有效课表通知，MOVE/CANCEL/ADD 重新计划。

添加 Small、Medium、Large Widget，确认分别显示下一节、今天、今天+明天；点击课程进入详情，点击空白进入首页。

## 备份与清除

1. 建立课程、颜色、手动课程和临时变更，设置主题与提醒。
2. 导出 `nwu-schedule-backup.json`，检查文件中没有账号、密码、Cookie、Session、Token 或 WebView Storage。
3. 清除全部数据，确认回到首次启动状态，通知、Widget、Cookie、Web Storage、缓存和表单数据均清理。
4. 恢复备份，确认数据和主题一致，提醒与 Widget 重新构建。

## 校历验收

- 当前校历的教学周、单双周、节假日、调休和补课与已核实的 NWU 资源一致；
- 修改 bundled calendar 的 revision 后重新安装/启动，确认出现非阻断的“西北大学校历已更新”提示，课表、提醒和 Widget 已按新 revision 计算；
- 导入尚未收录校历的学期，确认课程仍安全保存，并明确提示当前暂时无法生成按日期计算的完整课表；更新到包含该校历的版本后即可正常使用。

## 发布前外部确认

- 正方真实认证后的 form boundary 已观察到 action 与 `xnm`/`xqm` 字段；独立 JSON endpoint、完整响应 schema 和稳定远端 ID 仍必须通过后续真实接口观察确认，当前代码不会把其他学校的参数当作 NWU 事实。
- SPEC 暂定第 11 节为 `21:00–21:50`。西北大学公开作息 PDF 当前列出第 1–10 节，教务通知允许排课到第 11 节但没有给出第 11 节时间；发布前须由项目 Owner 根据校方最新作息确认。参考：[公开作息 PDF](https://www.nwu.edu.cn/__local/A/1C/E3/5C1FC71F3FD6DD7D62660973AEB_437A7D4A_2517.pdf?e=.pdf)、[教务排课通知](https://jwc.nwu.edu.cn/info/1034/10591.htm)。

## 记录结果

验收记录至少包含：APK commit、设备/Android/WebView 版本、导入学期、通过/失败项、脱敏后的错误阶段和是否导出了诊断文件。诊断文件只能由测试人员主动保存和发送，应用不会自动上传。

真实认证 form boundary 已有字段级记录；独立 endpoint、`gnmkdm` 的具体运行时值、完整请求参数和响应 schema 只有在完成真实接口观察后，才能标记为已验证；脱敏 fixture 测试不能替代这一步。
