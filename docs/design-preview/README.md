# 介面設計預覽

目前為 [第四版：月曆、設定與細節文案](v4/README.md)。設計與翻譯僅由獨立預覽入口啟用，尚未接入正式主題設定。

- [月曆與設定](v4/calendar-settings.png)
- [授業詳情與編輯](v4/details-edit.png)
- [表示設定與其他設定](v4/settings-details.png)

共用正式 Flutter 路由、首頁、週課表與課程元件，日期固定為 2026 年 10 月 19 日 09:41，示例課程載入記憶體資料庫。正式入口仍使用正常時鐘與本機資料。Android 預覽套件 ID 為 `io.github.aceykn.nwuschedule.designpreview`，可與正常應用並存。

```powershell
flutter run -d emulator-5562 --target lib/dev/design_preview.dart --android-project-arg=nwuDesignPreview=true
```

[第三版留檔](v3/README.md) · [第二版留檔](v2/README.md) · [第一版留檔](overview.png)。歷史版本描述不代表目前設定或版式。
