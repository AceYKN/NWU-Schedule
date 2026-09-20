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

其余仍在官方域名下的页面可以继续导航，但不会获得课表 JavaScript Bridge；页面路径或 DOM 结构变化时应导出诊断后再更新适配器。当前诊断版本为 `nwu-zhengfang-v9-dom-v3`。这项路径验证不等同于真实 API endpoint、`gnmkdm` 或响应 schema 已验证。

真实页面 DOM 已验证存在列表课表 `#kblist_table`。当前主 DOM 适配器只依赖以下已观察结构：

```text
#kblist_table
xq_rowspan_<1..7>             -> 星期分组
jc_<weekday>-<start>-<end>    -> 节次范围
```

课程详情文本已观察到稳定标签 `周数：`、`校区:`、`上课地点：`、`教师：`。DOM 适配器优先从这些标签切分字段，不再从视觉矩阵表中猜列位置；`#kbgrid_table_0` 不作为主解析源。若 `#kblist_table` 存在但结构不符合上述契约，应直接产生校验错误并停止导入，不回退到启发式解析。仓库中的 `nwu_kblist_fixture.html` 只保留脱敏后的结构与合成课程数据，不得提交真实姓名、学号或完整原始 DOM。

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
- 制造一次教务字段变化，确认冲突页可以分别选择“保留本地”和“采用教务”。
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
- 导入尚未收录校历的学期，确认课程仍保存，并明确提示教学周、放假和调休可能不完整。

## 发布前外部确认

- 正方真实认证后的 endpoint、`gnmkdm`、POST 参数和响应 schema 仍必须通过本清单的真实学生账号流程确认；当前代码不会把其他学校的参数当作 NWU 事实。
- SPEC 暂定第 11 节为 `21:00–21:50`。西北大学公开作息 PDF 当前列出第 1–10 节，教务通知允许排课到第 11 节但没有给出第 11 节时间；发布前须由项目 Owner 根据校方最新作息确认。参考：[公开作息 PDF](https://www.nwu.edu.cn/__local/A/1C/E3/5C1FC71F3FD6DD7D62660973AEB_437A7D4A_2517.pdf?e=.pdf)、[教务排课通知](https://jwc.nwu.edu.cn/info/1034/10591.htm)。

## 记录结果

验收记录至少包含：APK commit、设备/Android/WebView 版本、导入学期、通过/失败项、脱敏后的错误阶段和是否导出了诊断文件。诊断文件只能由测试人员主动保存和发送，应用不会自动上传。

真实认证 endpoint、`gnmkdm`、请求参数和响应 schema 只有在完成本清单第一个分组后，才能标记为已验证；脱敏 fixture 测试不能替代这一步。