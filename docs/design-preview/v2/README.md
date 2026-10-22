# 第二版：兩個獨立的設計方向

> 歷史留檔。第三版已撤下主題設定整合，以下描述對應當時的實驗版。

所有原圖都來自 Android API 35 模擬器執行真實 Dart 的 `adb screencap`，不是圖片生成。預覽共用正式應用的 `NwuScheduleApp`、路由及課表元件，只以記憶體資料庫載入固定示例課表。

[首頁對比](home-directions.png) · [週課表對比](week-directions.png)，均為左側日式手帳、右側校園刊物，並排圖僅拼接原始截圖。

| 方向 | 真正改動的排版 | 原圖 |
| --- | --- | --- |
| 日式手帳 | 大日期索引、明朝字體標題、靛藍與朱紅、細框線、平直課程塊、頁碼式導覽 | [首頁](japanese-home.png) · [週課表](japanese-week.png) |
| 台灣校園刊物 | 繁體宋體刊頭、中文日期、校園課表側標、雙分隔線與深綠文字 | [首頁](taiwan-home.png) · [週課表](taiwan-week.png) |

日式方向參考 [Hobonichi Weeks](https://www.1101.com/store/techo/en/2026/all_about/weeks/) 的日期索引、淡網格及分隔線。校園刊物是本次選定的排版方向，不代表台灣產品只有一種風格。

兩版都能透過實際設定頁的「日式手帳／校園刊物」主題切換，沿用既有主題 ID，因此不會改變已儲存的課程。原石墨藍 ID 對應日式手帳，原雪松綠 ID 對應校園刊物。

主要程式：

- `lib/app/theme/campus_design.dart`：兩個方向的紙色、墨色、標題字體及版式識別。
- `lib/features/shared/presentation/campus_header.dart`：各自獨立的日期與週課表頁首。
- `lib/features/shared/presentation/campus_navigation.dart`：頁碼式底部導覽。
- `lib/features/home/presentation/home_page.dart`：真實首頁與課程狀態卡。
- `lib/features/schedule/presentation/widgets/schedule_week_grid.dart`：真實週課表網格、日期索引及當前時間。
- `lib/dev/design_preview.dart`：固定示例資料入口，正式入口仍使用正常時鐘。

字體授權與來源見 [字體說明](../../../assets/fonts/README.md)。課程名稱、教師與地點保持原文和系統黑體，繁體明朝字體僅用於介面文字。

本輪靜態檢查與 318 項非 golden 測試通過。兩個方向均已在模擬器中執行及檢查；既有 golden 基線尚未更新。
