# NWU 校历原始语义资产

这里保存从西北大学校历整理出的紧凑结构，作为长期维护源数据。

字段语义：

- `semesterStartDate`：学期上课起始日期。
- `week1StartDate`：第 1 教学周起始日期；用于教学周计算，单独保留，避免未来与学期起始日期不一致。
- `semesterEndDate`：校历中的本学期上课结束日期。
- `totalWeeks`：教学周总数。
- `followingBreak`：紧随本学期之后的寒假/暑假，仅作展示和学期元数据，不参与课程匹配。
- `holidayPeriods`：闭区间假期。运行时应展开为每天的 `CalendarDateOverride(type: holiday)`。
- `makeupDays`：调休映射。`date` 是实际上课日期，`useScheduleOf` 是应执行课表的模板日期。模板日期只提供教学周和星期信息，不应递归应用模板日期自身的放假 override。

当前 `CalendarDefinition.fromJson()` 已支持该目录并执行 normalizer；`source/index.json` 是运行时唯一校历目录：

```text
holidayPeriods -> CalendarDateOverride(holiday)
makeupDays      -> CalendarDateOverride(useScheduleOf)
```

五份数据来自项目讨论中提供的西北大学校历图片；正式发布前仍建议对照学校官方发布版本做一次复核。
