# CODEX_TASK.md

## NWU-Schedule — 2026-09-20 review follow-up

**Priority: P0 stabilization before new feature work.**

This task is written against main at commit `53037c3612aeec0afabebc83163670e3712c5e8b` (`test(ui): tolerate month golden font rasterization`).

The repository already has a substantial working implementation. Do not rewrite the application. Preserve the local-first Flutter architecture, Drift persistence, ScheduleEngine as the single source of effective schedule truth, and the existing import preview/three-way-merge/tombstone behavior.

---

# 0. Operating rules

1. Pull/rebase the newest `main` before changing code.
2. Read this file, `SPEC.md`, and `docs/manual-integration.md` before implementation.
3. Do not add unrelated features while P0/P1 items below remain open.
4. Keep commits small and logically separated.
5. Never weaken existing privacy/security checks simply to make integration easier.
6. Any authenticated NWU test is strictly read-only.
7. User-authorized test access exists, but authentication material is supplied out-of-band. **Never put credentials into source code, fixtures, Git history, issue/PR text, screenshots, test output, diagnostics, shell history, or logs.**
8. For real NWU testing, only navigate the intended path:
   **教务系统 → 选课 → 个人课表查询**.
   Do not open unrelated student-information pages. Do not select/drop courses, submit academic forms, edit server-side data, or trigger any mutating operation.
9. Raw authenticated HTML/DOM containing student data must not be committed. Only sanitized structural fixtures may enter the repository.

---

# 1. Current baseline and important existing behavior

The application currently contains:

- Flutter Android-first client.
- No application server; all schedule data is local.
- Drift/SQLite persistence.
- Semester + bundled NWU CalendarDefinition.
- centralized `ScheduleEngine` / `CalendarEngine`.
- course + multiple MeetingRule support.
- MOVE / CANCEL / ADD local exceptions.
- WebView-based NWU Zhengfang import.
- DOM extraction and normalized `ImportedTimetable`.
- import preview / diff / three-way merge.
- import snapshots and locally-deleted tombstones.
- local notifications.
- Android Small/Medium/Large widgets.
- backup / restore / clear-data.
- week/month/home/course-detail UIs.
- golden/widget/domain tests.

Existing sanitized import fixtures include:

- `test/fixtures/zhengfang/nwu_kblist_fixture.html`
- `test/fixtures/zhengfang/timetable_grid_fixture.html`
- `test/fixtures/zhengfang/timetable_index.html`
- `test/fixtures/zhengfang/timetable_response.json`

The verified list timetable contract currently uses:

- `#kblist_table`
- weekday grouping IDs `xq_rowspan_<1..7>`
- section IDs `jc_<weekday>-<start>-<end>`
- observed labels such as `周数：`, `校区:`, `上课地点：`, `教师：`

The list view is preferred. If `#kblist_table` exists but is malformed, fail closed rather than silently switching to heuristic parsing.

---

# 2. P0-A — Get/keep main completely green

Before architecture changes, establish a clean baseline.

Run at minimum:

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
node tool/test_nwu_dom_extractor.mjs
dart run tool/validate_privacy.dart
```

Also run any repository-specific merged-manifest validation used by CI.

Investigate current GitHub Actions state. The previous commit before HEAD added real-page golden coverage and failed; HEAD attempted to tolerate font rasterization differences. Do not assume this is solved until the current workflow is green.

Golden policy:

- fix nondeterministic font/raster/platform differences without hiding real layout regressions;
- do not increase tolerances broadly just to force green;
- use the existing comparator only where a small known rendering tolerance is justified;
- preserve actual schedule page golden coverage.

Acceptance:

- `flutter analyze` passes;
- all unit/widget/golden tests pass;
- DOM extraction script passes;
- privacy/manifest validators pass;
- GitHub Actions for the resulting main commit is green.

---

# 3. P0-B — Redesign imported Course Identity BEFORE removing metadata

## Problem

The product requirement is now:

> course code, teaching class, credits, and assessment are not product-level schedule fields and should not participate in manual add/edit, imported course display, import diff/conflict handling, backup behavior, or ordinary schedule logic.

However current code still contains these fields in:

- `lib/domain/course/course.dart`
- `lib/domain/import/timetable_import.dart`
- `lib/domain/import/import_diff.dart`
- `lib/data/repositories/drift_schedule_data_repository.dart`
- `lib/data/database/app_database.dart`
- `lib/domain/backup/schedule_backup.dart`
- `lib/features/schedule/presentation/course_detail_page.dart`
- `lib/features/import/presentation/timetable_import_page.dart`
- `lib/infrastructure/import/nwu_dom_extractor.dart`
- tests/docs/SPEC.

More importantly, current reconciliation logic uses code/teaching-class metadata to recover course identity and current DOM list keys may include them.

**Do not simply delete those four fields first.** That can cause duplicate courses, merged distinct courses, broken repeated imports, broken tombstone restore, and exception/rule remapping.

## Required identity investigation

Using only the authorized personal timetable page, inspect the DOM structure of `#kblist_table` for stable opaque identity candidates.

Look for, in this order:

1. explicit stable `data-*` attributes attached to course/list/meeting elements;
2. hidden input values that identify a course offering;
3. opaque IDs embedded in `href`, `onclick`, JS arguments, or element IDs;
4. stable endpoint/query identifiers already present in the rendered page;
5. only if none exists, a carefully designed synthetic key.

Do not collect unrelated personal data.

A structural diagnostic may record only:

- tag names;
- attribute names;
- boolean presence/absence of candidate IDs;
- sanitized/hashed opaque candidate values if necessary for stability comparison;
- parent/child relationships needed to identify which attributes belong to the same course/meeting.

Never record:

- user name;
- student number;
- cookie;
- token;
- session identifier;
- full raw HTML;
- unrelated page text.

## Preferred identity design

If the page exposes a stable remote opaque course/offering identifier, normalize it into a versioned key, e.g.:

```text
nwu-v1|course|<opaque-id>
```

and meeting identity should be a child of that course identity plus recurrence identity:

```text
nwu-v1|course|<opaque-id>|meeting|<weekday>|<start>|<end>|<week-mask-or-stable-meeting-id>
```

If a stable remote meeting ID exists, prefer it over schedule-text composition.

### Synthetic fallback

If no stable remote ID exists, do **not** use the four removed metadata fields.

Construct a versioned conservative fingerprint from only schedule-relevant normalized information. The exact implementation may be adjusted after inspecting the real DOM, but it should follow these constraints:

- deterministic;
- normalized Unicode/whitespace;
- semester-scoped;
- does not include teacher or room, because those legitimately change and should produce an update rather than a new course;
- does not include credits/assessment/code/teachingClass;
- must avoid merging two same-name courses merely because their first meeting happens to match;
- use the complete set of normalized meeting signatures to disambiguate same-name courses where possible;
- version the algorithm so future changes can be migrated/reconciled.

Example conceptual fallback:

```text
courseIdentity = hash(
  version +
  semesterRemoteTermKey +
  normalizedCourseName +
  sorted(stableMeetingShapeSet)
)
```

where `stableMeetingShapeSet` should use recurrence structure but exclude mutable presentation metadata.

Because meeting weeks can change remotely, do not blindly make the whole recurrence mask the only identity anchor. Reconciliation should be capable of matching a prior course with a changed meeting set.

## Reconciliation requirements

Update `ImportDiff` / repository logic so repeated imports preserve local identity across:

- teacher change;
- room change;
- campus change;
- week-mask change;
- section change;
- one meeting added/removed;
- opaque key rotation if the site changes a non-semantic identifier and a unique safe match is possible.

Matching must be conservative. If multiple local candidates are equally plausible, do not auto-merge them. Surface a safe conflict or treat as create/delete rather than corrupting data.

Tombstones and local exceptions must continue to work.

Add explicit tests for:

- same course, teacher changed;
- same course, room changed;
- same course, recurrence weeks changed;
- same course, one meeting moved;
- two same-name courses that must not merge;
- key rotation;
- locally deleted imported course remains deleted on re-import until user restores it;
- restored tombstone maps to the correct course;
- exceptions tied to removed/remapped MeetingRules remain valid or are safely cleaned/remapped.

Acceptance:

- course identity no longer depends on code, teachingClass, credits, or assessment;
- repeated import remains stable;
- no duplicate course creation for ordinary remote edits;
- no accidental merging of distinct same-name courses.

---

# 4. P0-C — Remove course code / teaching class / credits / assessment from product behavior

After P0-B is complete, remove the four fields from all active product behavior.

Fields:

- course code;
- teaching class;
- credits;
- assessment.

## Domain

Remove them from:

- `Course`;
- `ImportedCourse`;
- equality/copy/serialization paths;
- validation paths;
- import snapshots where they are part of the normalized product payload.

Update constructors/tests.

## DOM extraction

`NwuDomExtractor` must stop parsing or emitting these values as product data.

If one of these values is temporarily needed only while studying identity, it must not remain as an ordinary product field. Once identity is independent, delete the parsing path.

Do not display these fields in diagnostics.

## Import Diff / conflict UI

Remove these fields from:

- field comparison;
- three-way merge decisions;
- conflict generation;
- conflict labels;
- preview UI.

A change to any of these values on Zhengfang must not create a product-level diff.

## Repository

Stop reading/writing/reconciling these fields as active course metadata.

### Database compatibility

Avoid an unnecessary risky migration solely to remove nullable columns immediately.

Preferred staged approach:

1. keep existing SQLite columns physically present in schema v2 for backward compatibility;
2. stop mapping/using them in active domain logic;
3. leave them null/ignored for new data;
4. plan physical column removal only in a later deliberate schema migration (e.g. schema v3) if worthwhile.

Do not bump database schema just for cosmetic cleanup unless Drift code generation or architecture genuinely requires it.

## Backup

New backups should not export these obsolete product fields.

Backward compatibility:

- old backups containing them should still be accepted;
- parser should ignore them;
- restoring an old backup must not resurrect them into active domain/UI behavior.

Add a migration/compatibility test for an old backup JSON containing all four fields.

## UI

Ensure they are absent from:

- manual add;
- manual edit;
- course detail;
- import preview;
- conflict resolution;
- course management;
- any card/subtitle/accessibility text.

Search the repository for Chinese and English variants and verify nothing remains in product UI.

## Docs

Update:

- `SPEC.md`;
- `docs/manual-integration.md`;
- README if relevant.

Current manual-integration text claiming these values are retained is now obsolete.

Acceptance:

- grep/search verifies no active product path still treats these as course metadata;
- old DB and old backup remain readable;
- importing a DOM where only these values changed produces no meaningful course change.

---

# 5. P0-D — Real NWU Zhengfang E2E, strictly limited to personal timetable

The user has explicitly authorized using a dedicated test account for this read-only verification. Authentication material is provided separately from Git and must remain secret.

## Allowed route only

Use the app WebView and navigate only:

1. NWU Zhengfang login;
2. `选课`;
3. `个人课表查询`;
4. read the timetable;
5. return/exit.

Do not inspect or operate other modules.

Do not perform course selection, drop, save, submit, or any remote mutation.

## Verify WebView boundary

Existing expected security behavior includes:

- HTTPS only;
- host `jwgl.nwu.edu.cn`;
- port 443;
- path under `/jwglxt`;
- JS bridge unavailable on login/non-timetable contexts;
- bridge enabled only on the observed personal timetable paths;
- `contextScript` must confirm timetable context;
- navigation generation must reject stale callbacks;
- session/cache/cookies/storage must be cleared on exit.

Verify these on a real device without weakening the implementation.

## Real import assertions

Compare actual visible timetable content with parser output:

- semester;
- course name;
- teacher;
- campus;
- room;
- weekday;
- start/end sections;
- teaching weeks;
- multiple weekly meetings belonging to one course.

Then:

1. open import;
2. login;
3. navigate only to personal timetable;
4. read;
5. preview;
6. verify diff;
7. save;
8. verify Home/Week/Month/Course Detail;
9. leave the import flow;
10. re-enter and verify the authenticated session was cleared and login is required again.

If any real DOM difference is discovered, create/update a **sanitized** fixture reproducing only the relevant structure.

Never commit the real DOM.

---

# 6. P0-E — Turn existing DOM/JSON fixtures into an end-to-end regression pipeline

Do not rely on a real account for routine regression.

Use the existing sanitized fixtures as the main deterministic test source.

The target pipeline is:

```text
sanitized DOM fixture
  -> NwuDomExtractor
  -> normalized JSON / ImportedTimetable
  -> validation
  -> ImportDiff
  -> commitImportedTimetable
  -> Drift DB
  -> ScheduleEngine
  -> Home / Week / Month / Course Detail
  -> NotificationPlanner
  -> WidgetSnapshotBuilder
```

The fixture suite must cover at least:

### Import/parsing

- verified `#kblist_table` parsing;
- generic fallback fixture;
- multiple meetings for one course;
- all weeks;
- odd weeks;
- even weeks;
- irregular week mask;
- malformed weekday context;
- malformed section ID;
- malformed/shifted week text;
- missing required context;
- duplicated structural columns;
- invalid section range;
- fail-closed behavior when verified table exists but violates contract.

### First import

Verify:

- Semester creation;
- bundled calendar binding;
- Course creation;
- multiple MeetingRules grouped under one Course;
- import snapshot persisted.

### Repeat import

Derive modified JSON fixtures in tests, rather than editing live account data.

Cover:

- no changes -> no-op diff;
- teacher changed;
- room changed;
- campus changed;
- week mask changed;
- section changed;
- meeting added;
- meeting removed;
- new course;
- removed course;
- same-name distinct courses;
- locally edited values;
- conflicts;
- tombstone preservation;
- explicit restore.

### Cross-semester

Import another semester and verify it does not overwrite the existing semester.

---

# 7. P0-F — MOVE / CANCEL / ADD regression must flow through ScheduleEngine

Use fixture-imported courses as the baseline, then apply local exceptions.

## MOVE

Test moving one occurrence:

- original date disappears;
- target date appears;
- target sections are correct;
- effective teacher/room behavior remains correct;
- Home/Week/Month all reflect the move;
- notification schedules for target occurrence only;
- widget snapshot contains target occurrence only.

## CANCEL

Test cancelling one occurrence:

- occurrence disappears everywhere;
- no notification remains for it;
- widget does not display it.

## ADD

Test:

1. add attached to an existing course;
2. standalone ADD if supported by current product behavior.

Verify:

- target date/sections;
- no corruption of original MeetingRule;
- current fix `preserve ADD meeting template` remains covered;
- backup/restore preserves the exception.

## Remove exception

Undo each exception and ensure base timetable returns identically.

Acceptance:

UI, notification planner, and widget must all consume `ScheduleEngine` output. They must not independently reimplement week-mask/calendar/exception rules.

---

# 8. P0-G — Notification regression

Using deterministic fixture data and deterministic `now`:

Verify:

- disabled -> no scheduled notification;
- enabled -> next relevant courses scheduled;
- 5/10/15/20/30/60 minute lead options;
- cancelled class -> notification removed;
- moved class -> notification time/date moves;
- added class -> notification added;
- semester switch -> stale alarms cleared/rebuilt;
- calendar revision update -> alarms rebuilt;
- clear-data -> all notifications removed.

For Android device validation:

- notification permission denied path;
- permission granted path;
- notification fires with correct course/time/location;
- tapping notification opens the intended app destination;
- no duplicate alarms after repeated refresh/import.

Do not make native Android code calculate recurrence independently of ScheduleEngine.

---

# 9. P0-H — Widget regression

Use `WidgetSnapshotBuilder` from the same ScheduleEngine fixture.

Automated tests must cover:

- no class;
- NOW;
- NEXT;
- moved class;
- cancelled class;
- added class;
- day rollover in NWU campus timezone;
- semester switch;
- clear-data -> empty snapshot;
- multiple widget instances have distinct PendingIntents.

Real device validation:

- Small;
- Medium;
- Large;
- multiple widgets simultaneously;
- app restart;
- device time/date transition;
- after import;
- after manual edit;
- after MOVE/CANCEL/ADD;
- after clear-data.

The Kotlin renderer may filter/display the published local snapshot by time/date but must not become a second schedule engine.

---

# 10. P1-A — UI regression and polish using deterministic data

Use fixture-backed data rather than manually constructed unrelated demo state wherever practical.

Validate at minimum:

- Home: NOW;
- Home: NEXT;
- Home: no class;
- Home: day finished;
- Week view with 2–3 classes;
- Week view with dense day;
- multiple meetings for same course;
- weekend hidden/shown;
- inactive-course preference;
- teacher hidden/shown;
- period time hidden/shown;
- current period highlight;
- back-to-current-week FAB;
- Month markers;
- Course Detail;
- import preview;
- conflict UI;
- manual add;
- manual edit;
- irregular imported week pattern;
- MOVE/CANCEL/ADD sheets.

Test presentation under:

- three bundled themes;
- light mode;
- dark mode if supported by current app;
- narrow Android width;
- large system font / text scale;
- long Chinese course names;
- long room names.

Golden tests should focus on stable visual contracts, not pixel-perfect platform font noise.

---

# 11. P1-B — Manual add/edit regression

Current desired behavior:

- no course-code field;
- no teaching-class field;
- no credits field;
- no assessment field;
- course name;
- optional note;
- teacher/campus/room as current meeting-related fields;
- multiple meetings per course;
- each meeting can have weekday, start/end section, start/end week, and all/odd/even mode;
- selected teaching weeks are visually obvious.

Cover:

- Monday + Wednesday meetings for one course;
- identical course name with independent meeting cards;
- add/remove meeting;
- startWeek > endWeek validation;
- odd/even masks;
- 1..64 week range;
- editing an imported irregular WeekMask preserves it until the user intentionally changes the recurrence selector;
- after changing it, deterministic conversion to regular pattern;
- save/reopen round-trip.

---

# 12. P1-C — Calendar/semester edge cases

Current import uses a semester ID such as:

```text
nwu-2026-2027-1
```

and repository behavior currently falls back:

```dart
calendarId: timetable.semester.calendarId ?? semesterId
```

Verify:

- imported 2026-2027 term 1 resolves to the intended bundled calendar;
- manual preferred semester remains selected until a later semester actually begins according to existing selection policy;
- rollover chooses current semester correctly;
- historical semester can be selected;
- missing bundled calendar preserves imported course data but clearly disables date-based effective schedule generation.

Improve the current missing-calendar copy. Do not imply teaching-week/holiday calculation is merely “possibly inaccurate” if no CalendarDefinition means ScheduleEngine cannot provide the normal date-based timetable. Use wording equivalent to:

> 课程数据已安全保存，但当前版本缺少该学期校历，因此暂时无法生成按日期计算的完整课表。更新到包含该校历的版本后即可正常使用。

Calendar revision change must:

- set/update stored revision;
- display the update notice;
- rebuild notification/widget outputs through the new ScheduleEngine.

---

# 13. P1-D — Period 11 remains unverified

Do not invent an official 11th-period clock time.

The current project documentation notes that public NWU timetable material confirms periods 1–10, while another notice allows teaching through period 11 but does not establish the exact period-11 time.

Until a primary NWU source or direct authorized observation verifies the time:

- keep this marked provisional;
- do not claim it is official;
- do not silently harden an assumed time into tests as authoritative.

---

# 14. P1-E — Backup / clear / restore regression

Using fixture-imported schedule plus local edits and exceptions:

Create a backup containing:

- semester;
- courses;
- MeetingRules;
- MOVE/CANCEL/ADD exceptions;
- theme;
- schedule display preferences;
- notification settings where the current backup format supports them.

Then:

1. clear all data;
2. confirm DB tables/settings are empty;
3. confirm WebView cookies/storage/session cleared;
4. confirm notifications cleared;
5. confirm widget snapshot cleared;
6. restore;
7. confirm schedule/UI/exceptions/settings return.

Also verify old backup compatibility where obsolete code/teachingClass/credits/assessment fields exist: accept but ignore them.

Restore must remain atomic: a failed validation must not leave a partially-restored database.

---

# 15. Privacy/security regression

Retain the current least-privilege posture.

At minimum test:

- HTTP blocked;
- wrong host blocked;
- non-443 port blocked;
- host spoofing/subdomain tricks blocked;
- non-`/jwglxt` path blocked;
- bridge disabled outside timetable context;
- bridge disabled on login;
- stale navigation-generation callback ignored;
- payload > limit rejected;
- diagnostics redact/suppress sensitive DOM text;
- leaving import clears session state;
- release WebView debugging disabled;
- Android manifest contains only expected permissions.

Review whether third-party subresources loaded by the official page create any unexpected data exposure, but do not break required official assets without evidence.

---

# 16. Refactor NwuDomExtractor after behavior is protected

`lib/infrastructure/import/nwu_dom_extractor.dart` has become large and high-risk.

Do not refactor it before the fixture suite protects behavior.

After coverage is sufficient, split responsibilities conceptually into independently testable helpers/modules where practical:

- context detection;
- semester extraction;
- verified list-table traversal;
- course/meeting structural identity;
- field text normalization;
- week parsing;
- diagnostics/issues;
- payload serialization.

Preserve the single bridge payload contract expected by Dart.

Goal: a site DOM change should affect a small adapter area rather than an ~800-line monolith.

---

# 17. Expected commit sequence

Prefer a sequence close to:

1. `test: stabilize current CI baseline`
2. `test(import): expand identity and fixture regression coverage`
3. `refactor(import): decouple course identity from obsolete metadata`
4. `refactor(domain): remove obsolete course metadata`
5. `fix(import): remove obsolete metadata from diff and persistence`
6. `fix(backup): ignore legacy course metadata while preserving compatibility`
7. `test(schedule): cover fixture-backed MOVE CANCEL ADD end to end`
8. `test(notification): cover effective schedule changes`
9. `test(widget): cover effective schedule changes`
10. `test(ui): expand fixture-backed schedule states`
11. `docs: update import contract and real-device checklist`
12. any small real-DOM compatibility fix discovered during authorized testing.

Do not squash all work into one giant commit during development.

---

# 18. Final acceptance checklist

Do not call this task complete until all are true:

- [ ] main CI is green.
- [ ] course identity does not depend on code / teaching class / credits / assessment.
- [ ] those four fields are removed from active domain/import/diff/backup/UI behavior.
- [ ] existing DB remains readable.
- [ ] legacy backup remains readable and obsolete fields are ignored.
- [ ] verified NWU list DOM fixture still parses.
- [ ] malformed verified-list DOM still fails closed.
- [ ] first import passes.
- [ ] repeat no-op import passes.
- [ ] remote schedule modifications reconcile safely.
- [ ] same-name distinct course test passes.
- [ ] tombstone delete/restore passes.
- [ ] multi-meeting course passes.
- [ ] odd/even/all/irregular week tests pass.
- [ ] MOVE passes across engine/UI/notification/widget.
- [ ] CANCEL passes across engine/UI/notification/widget.
- [ ] ADD passes across engine/UI/notification/widget.
- [ ] calendar binding/revision/missing-calendar tests pass.
- [ ] backup/clear/restore passes.
- [ ] notification real-device smoke test passes.
- [ ] Small/Medium/Large widget real-device smoke test passes.
- [ ] real-device NWU login → 选课 → 个人课表查询 → read → preview → save works.
- [ ] leaving import clears authenticated session.
- [ ] no credentials or personal authenticated DOM data exist in repository/history/logged artifacts.
- [ ] docs match actual implementation.

---

# 19. Completion report required from Agent

When finished, report:

1. exact commit SHAs;
2. changed architecture, especially the final course-identity algorithm;
3. tests added/updated;
4. automated test results;
5. real-device checks completed;
6. any behavior that could not be verified;
7. any sanitized DOM structural differences discovered;
8. any remaining release blockers.

Do not report “done” merely because unit tests pass. The task requires both deterministic fixture regression and the narrowly-scoped authorized real-device integration check.
