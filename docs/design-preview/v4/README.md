# 第四版：月曆、設定與細節文案

直接修改 Dart，執行 Android API 35 預覽包後擷取。短標籤使用日式用語，較長說明使用繁體中文，延續第三版的緊湊排版、暖白底、墨色與朱紅。

本輪包含月曆、設定、表示設定、授業詳情、授業編輯、授業管理、導入確認、常用彈窗、空狀態及表單驗證。教務網站本身及課程名稱、教師、校區、教室、學期名稱、備註等資料保持原文。介面句式先翻譯，再填入資料值，避免同名資料及花括號被錯誤替換。

- [月曆／設定](calendar-settings.png)
- [授業詳情／編輯](details-edit.png)
- [表示設定／其他設定](settings-details.png)

原圖：[月曆](calendar.png)、[設定](settings.png)、[詳情](course-details.png)、[編輯](course-edit.png)、[表示設定](display-settings.png)、[其他設定](settings-more.png)。原圖均為 `adb exec-out screencap -p` 的 1080×2400 PNG，並排圖僅拼接原圖及間隔。

譯文集中在 `lib/app/l10n/campus_strings.dart`，介面格式函式位於 `lib/features/shared/presentation/campus_text.dart`。正式主題定義保持原始內容；只有獨立預覽入口注入外觀與譯文。示例課程使用記憶體資料庫，並為編輯頁提供相同示例校曆。

靜態檢查通過，321 項非 golden 測試通過，debug APK 建置成功。新增頁面測試涵蓋原模式、預覽模式及 1.8 倍字體，驗證與介面詞彙同名的課程、教師及含花括號的教室資料保留原文。原生截圖核對月曆、設定、詳情、編輯及表示設定；教務匯入未進行真實登入。既有 golden 基線未更新。

字體授權與來源見 [字體說明](../../../assets/fonts/README.md)。
