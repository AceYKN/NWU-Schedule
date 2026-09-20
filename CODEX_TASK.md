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


---

# 20. CONCRETE IMPLEMENTATION PLAYBOOK — follow this order

The sections above define requirements. This section defines the **default implementation strategy**. Do not spend a full iteration rediscovering the architecture unless real code or real DOM evidence disproves this plan.

## 20.1 Work loop: test-first, narrow commit, full regression

For every phase:

1. add/adjust the smallest test that demonstrates the required behavior;
2. run that targeted test and confirm it fails for the expected reason;
3. implement the smallest production change;
4. rerun the targeted test;
5. run the adjacent test group;
6. commit;
7. after 2–3 narrow commits, run the complete suite.

Recommended commands during development:

```bash
flutter test test/domain/import_diff_test.dart
flutter test test/data/drift_schedule_data_repository_test.dart
flutter test test/domain/schedule_engine_test.dart
flutter test test/domain/notification_planner_test.dart
flutter test test/domain/widget_snapshot_test.dart
flutter test test/widget/timetable_import_preview_test.dart
flutter test test/golden/timetable_import_preview_golden_test.dart
flutter test test/golden/actual_schedule_pages_golden_test.dart
node tool/test_nwu_dom_extractor.mjs
```

Then periodically:

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
```

If a phase introduces broad unrelated failures, stop and fix/revert that phase before continuing. Do not stack identity, backup, UI, and Android-native changes into one unresolved working tree.

---

## 20.2 Add one reusable fixture test harness before adding many tests

Create a small test helper, preferably:

`test/support/zhengfang_fixture.dart`

It should provide helpers similar to:

```dart
Map<String, dynamic> loadNormalizedTimetableFixture();
RemoteTimetable loadRemoteTimetableFixture();
RemoteTimetable mutateRemoteTimetable(
  RemoteTimetable base, {
  // named transformations used by tests
});
Future<ScheduleDataSnapshot> importFixtureInto(
  DriftScheduleDataRepository repository, {
  RemoteTimetable? timetable,
});
ScheduleEngine buildEngineFromSnapshot(
  ScheduleDataSnapshot snapshot,
  CalendarDefinition calendar,
);
```

Do not create a huge fake framework. The goal is to stop every test from manually recreating the same semester/courses/rules.

Use `test/fixtures/zhengfang/timetable_response.json` as the Dart-side normalized fixture.

For the HTML side, keep `tool/test_nwu_dom_extractor.mjs` as the JavaScript/DOM boundary. Add a canonical semantic assertion so:

`nwu_kblist_fixture.html -> extractionScript -> normalized payload`

matches the expected semantic content in `timetable_response.json` for fields that belong to the product contract.

Do not compare volatile diagnostic ordering or raw HTML.

The testing architecture should therefore be:

```text
HTML fixture --Node/jsdom--> extracted normalized JSON
                               |
                               v
                    timetable_response.json
                               |
                               v
Dart Parser -> ImportDiff -> Drift -> ScheduleEngine -> UI/notification/widget
```

This makes a DOM parser change visible before it contaminates downstream tests.

---

## 20.3 Course identity implementation: exact code strategy

### A. First inspect real DOM identity

Before replacing the current key algorithm, perform the authorized read-only DOM inspection on the personal timetable page.

Add a **temporary local-only** inspection snippet/tool if needed. It may inspect the course information cell and its nearest ancestors for:

- `data-*` attributes;
- `id`;
- `href`;
- `onclick`;
- hidden inputs;
- stable opaque JS parameters.

Do not commit the captured authenticated output.

The final committed fixture may contain invented opaque IDs with the same **shape**, for example:

```html
<td data-offering-id="fixture-offering-a">...</td>
```

only if the real page actually exposes an equivalent structural attribute.

### B. Prefer a remote opaque identity

If a stable offering/course ID exists, update `lib/infrastructure/import/nwu_dom_extractor.dart` so the final key is versioned and semester-scoped.

Recommended format:

```text
nwu-zf-v2|<academicYear>|<term>|course|<opaqueOfferingId>
```

If a stable meeting ID exists:

```text
nwu-zf-v2|<academicYear>|<term>|course|<opaqueOfferingId>|meeting|<opaqueMeetingId>
```

If the course has an opaque ID but a meeting does not, use:

```text
<courseKey>|meeting|<weekday>|<startSection>|<endSection>|<normalizedWeekMask>
```

The meeting key is allowed to rotate when recurrence changes because repository reconciliation already has a structural rematcher. The **course key** is the critical stable anchor.

Do not put teacher, room, campus, code, teaching class, credits, or assessment in the stable course key.

### C. If there is NO stable remote course ID

Do not replace the current key with `course name only`.

The sanitized fixture already demonstrates why this is unsafe: multiple rows may have the same visible course name while representing distinct offerings/meeting groups.

Implement this conservative fallback:

1. parse each course row into an intermediate raw meeting record;
2. compute a normalized course name;
3. only auto-group multiple rows into one course when the page structure provides a non-obsolete structural grouping signal;
4. if two or more same-name groups cannot be distinguished safely, keep them separate rather than merging them;
5. let ImportDiff show add/remove when identity is genuinely ambiguous.

A wrong split is inconvenient; a wrong merge corrupts a user's schedule and local exceptions. Prefer false-negative matching over false-positive merging.

If this fallback prevents reliable grouping of a real multi-meeting course, record that as a release blocker in the completion report instead of inventing a hidden dependency on teaching class/course code.

---

## 20.4 Replace metadata matching in ImportDiffEngine

Current `ImportDiffEngine` contains:

- `_uniqueLocalMetadataMatch`
- `_uniquePreviousMetadataMatch`
- `_sameCourseMetadata`

which match using course code + teaching class.

Delete/replace these after the new identity strategy is protected by tests.

Recommended new pure helper:

`lib/domain/import/import_identity.dart`

Suggested API:

```dart
enum CourseIdentityMatchKind { exactKey, structural, ambiguous, none }

class CourseIdentityMatch<T> {
  const CourseIdentityMatch(this.kind, this.value);
  final CourseIdentityMatchKind kind;
  final T? value;
}

class ImportCourseMatcher {
  const ImportCourseMatcher();

  CourseIdentityMatch<Course> matchLocal({
    required ImportedCourse remote,
    required Iterable<Course> candidates,
    required Map<String, List<MeetingRule>> localRules,
  });

  CourseIdentityMatch<ImportedCourse> matchPrevious({
    required ImportedCourse remote,
    required Iterable<ImportedCourse> candidates,
  });
}
```

The helper must be Flutter-independent and easy to unit test.

### Matching order

Use this order:

1. exact `sourceCourseKey`;
2. unique stable remote identity alias if a version migration is explicitly supported;
3. unique structural match;
4. ambiguous/none -> do not auto-reuse local course ID.

### Structural hard gate

A structural candidate should normally require normalized course-name equality first.

Normalize with:

- trim;
- collapse repeated whitespace;
- normalize common full-width/half-width whitespace/punctuation only where safe;
- do not remove meaningful Chinese/English alphanumeric content.

Do **not** use fuzzy edit-distance matching for course names.

### Structural meeting score

Reuse the philosophy already implemented by `_bestMeetingMatch`: mutable display fields may be tie-breakers but not sole evidence.

For a pair of meeting rules, a reasonable score is:

- same weekday: +8
- exact same start/end sections: +6
- one boundary matches / ranges overlap: +2
- exact week mask: +5
- overlapping week masks: +1
- same teacher: +1
- same campus: +1
- same room: +1

Teacher/campus/room must not rescue a candidate with zero schedule-structure overlap.

For course-level matching:

- compute the best unique meeting pairing between remote and candidate;
- prefer candidates with more structurally matched meetings;
- then compare total score;
- require a unique winner;
- ties are ambiguous -> no automatic merge.

Most courses contain very few meeting rules, so a simple deterministic greedy or small maximum-score pairing is acceptable. Keep it readable and tested; do not add an optimization library.

### Important: ambiguity behavior

Do not choose “the first” candidate.

If two same-name courses score equally:

```dart
return const CourseIdentityMatch(CourseIdentityMatchKind.ambiguous, null);
```

Then ImportDiff should leave them as visible add/remove operations instead of silently corrupting identity.

---

## 20.5 Preserve database IDs when source keys rotate

When `ImportDiffEngine` identifies a unique structural match:

- `change.localCourse` must point to the existing course;
- `sourceCourseKey` on the database course may adopt the new remote key;
- the existing database `Course.id` must remain unchanged;
- local note/color/hidden/deleted state must remain attached to that `Course.id`.

This is already close to current behavior in `_courseFromRemote`; preserve it.

Do not derive a new DB `Course.id` when a matched existing course is available.

For a genuinely new course only, continue generating an imported ID from semester + source key.

Add a regression assertion:

```dart
expect(after.courses.single.id, before.courses.single.id);
expect(after.courses.single.sourceCourseKey, newRemoteKey);
```

---

## 20.6 Keep and harden meeting-rule reconciliation

Current `DriftScheduleDataRepository._rulesFromRemote` already performs:

1. exact `sourceMeetingKey` match;
2. fallback `_bestMeetingMatch`;
3. existing ID reuse;
4. exception ID remap;
5. exception cleanup for removed rules.

Do not replace this with “delete every rule and generate new IDs”.

Refactor only if necessary.

Specific tests to add around this existing logic:

- teacher-only change keeps `MeetingRule.id`;
- room-only change keeps `MeetingRule.id`;
- week-mask change with same weekday/sections keeps ID;
- section shift with weekday/week overlap keeps ID when uniquely identifiable;
- two equally-scored candidate rules return no best match;
- removed meeting deletes only exceptions that reference that removed rule;
- remapped meeting updates `CourseException.sourceMeetingId`;
- standalone ADD exception is not deleted because it has no source meeting.

If you extract `_bestMeetingMatch`, put the pure logic in the domain/import layer and keep the SQL remap operations in the repository.

---

## 20.7 Remove the four obsolete metadata fields without breaking schema v2

Make these concrete edits.

### `lib/domain/course/course.dart`

Remove:

- constructor args `code`, `teachingClass`, `credits`, `assessment`;
- fields;
- credits validation;
- corresponding `copyWith` parameters/branches.

Do not change note/color/hidden/deleted behavior.

### `lib/domain/import/timetable_import.dart`

Remove the same four fields from `ImportedCourse`, `toJson`, parser construction and validation.

Parser must tolerate legacy JSON keys by simply ignoring unknown keys.

### `lib/domain/import/import_diff.dart`

After identity matcher is in place:

- delete `_uniqueLocalMetadataMatch`;
- delete `_uniquePreviousMetadataMatch`;
- delete `_sameCourseMetadata`;
- `_fields()` should compare only active product fields:
  - `name`
  - `meetings`
- keep three-way merge behavior for those fields.

### `lib/features/import/presentation/timetable_import_page.dart`

Change `_fieldLabel` to only expose active conflict fields. Remove labels for:

- code;
- teachingClass;
- credits;
- assessment.

### `lib/features/schedule/presentation/course_detail_page.dart`

Remove all rendering of obsolete metadata.

### `lib/data/repositories/drift_schedule_data_repository.dart`

**Keep physical DB columns for schema-v2 compatibility**, but disconnect them from domain.

On DB -> domain load:

```dart
domain.Course(
  id: row.id,
  ...
  name: row.name,
  note: row.note,
  ...
)
```

Do not pass row.code etc.

On domain -> DB writes, explicitly clear old values for newly saved/updated courses:

```dart
code: const Value(null),
teachingClass: const Value(null),
credits: const Value(null),
assessment: const Value(null),
```

Do the same in:

- `saveCourse`;
- `_upsertCourse`;
- backup restore insert.

This prevents stale old metadata from silently surviving active edits.

### `lib/domain/backup/schedule_backup.dart`

New backup serialization must omit the four keys.

Legacy decoding must simply not read them.

That means `_courseFromJson` constructs `Course` from the remaining fields and silently ignores old extra JSON keys.

Keep `schemaVersion = 1` if the format remains backward compatible. Do not bump the backup schema merely because optional obsolete keys disappeared.

Add tests:

- old JSON with all four keys decodes;
- re-encoding that backup omits all four keys;
- resulting Course/domain behavior is identical otherwise.

---

## 20.8 DOM extractor: remove product metadata but KEEP labels as delimiters where required

Do not make the parser worse while removing fields.

Current verified-list parser uses labels such as `教学班`, `考核方式`, `学分`, `课程代码` not only to store values, but also to determine where teacher/room/etc. text ends.

Therefore:

- it is acceptable to recognize those strings as **structural delimiters**;
- it is not acceptable to emit/store/diff/display them as product data;
- it is not acceptable to use their extracted values as identity.

Concrete change:

1. simplify `parseListCourseInfo` output to:
   - identity signal;
   - name;
   - weekday;
   - start/end section;
   - week text;
   - teacher;
   - campus;
   - room.
2. keep obsolete label markers only in the delimiter list needed to stop text slicing.
3. remove:
   - `courseCodeText`;
   - `teachingClassText`;
   - parsed `credits`;
   - `assessmentText`;
   - related warning issues;
   - emission in `addMeeting`.
4. generic grid parser should stop reading optional code/class/credit/assessment columns.
5. update fixture expectations accordingly.

Also increment `NwuZhengfangV9Importer.adapterVersion` when normalized payload/identity semantics change, e.g. from v4 to the next version. Do not reuse an adapter version for a materially different identity contract.

---

## 20.9 Exact fixture mutation strategy for repeat-import tests

Do not create many almost-identical fixture files.

Load one base `RemoteTimetable` and produce variants in test code.

Recommended helper operations:

```dart
withTeacher(courseKey, meetingKey, '新教师')
withRoom(courseKey, meetingKey, '新教室')
withCampus(courseKey, meetingKey, '太白校区')
withWeekMask(courseKey, meetingKey, WeekMask.fromWeeks([...]))
moveMeeting(courseKey, meetingKey, weekday: 3, start: 5, end: 6)
removeMeeting(courseKey, meetingKey)
addMeeting(courseKey, ...)
removeCourse(courseKey)
addCourse(...)
rotateCourseKey(oldKey, newKey)
rotateMeetingKey(oldKey, newKey)
```

Each transformation should return a new immutable `RemoteTimetable` / `ImportedCourse` structure rather than mutate shared state between tests.

For every transformation:

1. import base;
2. capture local course/rule IDs;
3. preview transformed remote;
4. assert exact diff kind/fields;
5. commit;
6. reload DB;
7. assert which IDs were preserved/remapped;
8. build ScheduleEngine and assert effective schedule.

This is more valuable than testing ImportDiff alone.

---

## 20.10 Build one fixture-backed integration test covering the full schedule pipeline

Add a test such as:

`test/integration/fixture_schedule_pipeline_test.dart`

Use in-memory Drift DB.

Scenario:

1. load `timetable_response.json`;
2. parse to `RemoteTimetable`;
3. commit import;
4. load semester snapshot;
5. load bundled/test CalendarDefinition;
6. build `ScheduleEngine`;
7. assert representative Monday/Tuesday/Thursday occurrences;
8. assert Home state at deterministic instants;
9. create MOVE;
10. rebuild engine;
11. assert source removed and target added;
12. run `NotificationPlanner`;
13. run `WidgetSnapshotBuilder`;
14. assert both reflect the same moved occurrence;
15. replace MOVE with CANCEL and repeat;
16. add ADD and repeat;
17. backup;
18. clear;
19. restore;
20. assert effective schedule equals pre-clear state.

Do not test Flutter pixels in this test. It is the domain/data integration spine.

---

## 20.11 UI tests should consume the same repository state

For `actual_schedule_pages_golden_test.dart` and widget tests, add a helper that seeds the test repository from the normalized fixture rather than hand-building unrelated courses everywhere.

Keep small isolated manual models only where a UI state cannot be naturally produced from the fixture.

For each important effective state, use deterministic `now`:

- before first class -> NEXT;
- during class -> NOW;
- after final class -> finished;
- empty day -> no class;
- moved occurrence;
- cancelled occurrence;
- added occurrence.

The UI test should not recalculate expected weekdays/weeks itself. Assert on rendered output resulting from provider/ScheduleEngine state.

---

## 20.12 Notification implementation/testing strategy

Do not add scheduling logic to Android native code.

Expected architecture remains:

```text
ScheduleEngine
   -> NotificationPlanner
      -> planned local notifications
         -> platform scheduling service
```

Expand `test/domain/notification_planner_test.dart` using the fixture-backed engine.

For each lead time `[5, 10, 15, 20, 30, 60]`:

```dart
expect(item.fireAtUtc, item.classStartUtc.subtract(Duration(minutes: lead)));
```

For MOVE:

- no source-date payload;
- one target-date payload;
- fire time derived from target section time.

For CANCEL:

- no plan item for the cancelled occurrence.

For ADD:

- a plan item exists even if the date is otherwise a holiday, matching ScheduleEngine semantics.

At coordinator/service level verify refresh is replacement-oriented:

1. compute new complete plan;
2. cancel/replace stale scheduled entries;
3. schedule desired entries;
4. repeated refresh with identical input does not create duplicates.

On device, test permission denied/granted separately from planner correctness.

---

## 20.13 Widget implementation/testing strategy

Expected architecture remains:

```text
ScheduleEngine
   -> WidgetSnapshotBuilder
      -> serialized snapshot
         -> Kotlin RemoteViews renderer
```

Kotlin must not parse week masks or implement calendar overrides.

Extend `widget_snapshot_test.dart` with fixture-backed:

- NOW;
- NEXT;
- MOVE;
- CANCEL;
- ADD;
- tomorrow;
- empty day.

For multi-widget Android testing, preserve the recent PendingIntent namespace fix. Verify request codes/intents remain widget-instance-specific.

When changing Kotlin:

- test one Small + one Medium + one Large widget simultaneously;
- clicking each should open the app correctly;
- refreshing one must not hijack another's PendingIntent.

---

## 20.14 MOVE / CANCEL / ADD implementation rules

Do not mutate the base imported MeetingRule to implement a one-day change.

- MOVE = suppress source occurrence + synthesize target occurrence.
- CANCEL = suppress source occurrence.
- ADD = synthesize target occurrence.
- base MeetingRule remains the recurrence template.

Continue using `CourseException`.

When an imported meeting rule is reconciled after a new remote import:

- preserve exception references if the meeting is uniquely matched;
- remap `sourceMeetingId` to retained rule ID if needed;
- only delete an exception when its referenced meeting truly disappeared and no safe mapping exists.

Add an invariant test:

> changing teacher/room/week text on an imported recurring meeting must not silently delete the user's MOVE/CANCEL attached to that logical meeting.

---

## 20.15 Manual multi-meeting implementation strategy

Do not create duplicate Course rows for Monday + Wednesday.

One `Course` owns N `MeetingRule` rows.

Continue using `MeetingDraft` as presentation state.

Save algorithm:

1. validate course name;
2. require at least one valid meeting;
3. validate each draft independently;
4. convert each start/end week + pattern to `WeekMask`;
5. preserve `sourceMeetingKey` when editing an imported existing meeting;
6. call one atomic `saveCourse(course, rules, removeExceptionIds: ...)`.

For irregular imported masks:

- opening edit must not normalize/lose the mask;
- display it as irregular/readable;
- only when the user explicitly changes start/end/pattern should a new regular mask replace it.

Add widget tests for two meeting cards and save/reopen.

---

## 20.16 Calendar selection strategy

Do not let each screen infer teaching week independently.

All date-based pages must receive/use `ScheduleEngine`.

For imported semester:

1. derive semester id from academicYear + term;
2. resolve bundled CalendarDefinition by `calendarId`;
3. if found, update/persist revision;
4. create ScheduleEngine;
5. if missing, return `ScheduleCalendarMissing` and do not fake dates from device weekdays.

Test the exact imported fixture semester against the intended bundled calendar ID.

For calendar revision update:

- keep course/rules/exceptions untouched;
- rebuild engine;
- refresh notification plan;
- refresh widget snapshot;
- display one non-blocking update notice.

---

## 20.17 Backup compatibility implementation details

Before restore, decode + validate the entire backup **before** clearing existing tables.

Current transaction behavior must remain atomic.

Add a test that deliberately introduces an invalid reference late in the backup and assert:

```dart
expect(restore, throwsA(...));
expect(await repository.loadSemester(existingId), stillExists);
```

For obsolete course metadata:

- decoder ignores it;
- writer omits it;
- no schema bump required.

For imported snapshots from older adapters:

- keep them readable if current parser accepts the normalized JSON;
- if a legacy snapshot contains ignored metadata keys, parser ignores them;
- do not rewrite historical snapshot JSON in place during ordinary app startup.

---

## 20.18 Real-device NWU test procedure

Use the user's separately supplied authorized test credentials only at runtime.

Execution procedure:

1. install/debug the current app build on the connected Android device;
2. start from a cleared app import session;
3. open Import;
4. authenticate;
5. navigate only to **选课 → 个人课表查询**;
6. confirm URL/context allowlist;
7. trigger timetable read;
8. before save, manually compare several visible rows against Preview:
   - a normal all-week course;
   - an odd/even course if present;
   - a course with multiple meetings if present;
   - teacher;
   - room;
   - weekday;
   - sections;
   - week range;
9. save;
10. inspect Home/Week/Month/Course Detail;
11. close/leave import;
12. re-enter import and verify authentication state was cleared;
13. do not navigate elsewhere.

For DOM identity inspection, do it during step 6–7 only and collect the minimum structural evidence needed.

If a real-page incompatibility appears:

- reproduce its structure with synthetic values in `nwu_kblist_fixture.html`;
- make the fixture fail first;
- fix parser;
- rerun deterministic tests;
- then rerun the narrow real-device path.

Do not “fix on the live page” without a regression fixture.

---

## 20.19 Concrete stop conditions / rollback rules

Stop the current phase and do not continue stacking changes if any of these happen:

- same-name courses are merged unexpectedly;
- a repeated no-op import produces duplicate Course rows;
- a teacher/room-only remote update changes Course.id;
- a meeting-only update loses MOVE/CANCEL exceptions;
- old backup cannot be restored;
- malformed verified `#kblist_table` begins silently importing partial data;
- WebView navigation restrictions need to be loosened to make extraction work;
- full CI becomes red for unrelated modules.

Rollback the smallest offending commit, add a reproducing test, then reimplement.

If no safe course identity can be obtained from the real DOM and synthetic fallback cannot distinguish repeated same-name offerings, **do not use obsolete metadata as a hidden dependency**. Preserve data conservatively and report the identity limitation as a blocker.

---

## 20.20 File-by-file expected touch list

The implementation will likely touch these files. Use this as a checklist, not as permission to rewrite them all.

### Identity/import

- `lib/infrastructure/import/nwu_dom_extractor.dart`
- `lib/infrastructure/import/nwu_zhengfang_v9_importer.dart`
- `lib/domain/import/timetable_import.dart`
- `lib/domain/import/import_diff.dart`
- new `lib/domain/import/import_identity.dart` if the matcher is extracted
- `lib/data/repositories/drift_schedule_data_repository.dart`

### Domain/product metadata removal

- `lib/domain/course/course.dart`
- `lib/features/schedule/presentation/course_detail_page.dart`
- `lib/features/import/presentation/timetable_import_page.dart`
- any remaining UI found by repository search.

### Persistence/backup

- `lib/domain/backup/schedule_backup.dart`
- repository mappings above
- DB schema file only if needed for generated API compatibility; do not physically drop v2 columns in this task.

### Regression tests

- `tool/test_nwu_dom_extractor.mjs`
- `test/domain/import_diff_test.dart`
- `test/data/drift_schedule_data_repository_test.dart`
- `test/domain/schedule_engine_test.dart`
- `test/domain/notification_planner_test.dart`
- `test/domain/widget_snapshot_test.dart`
- `test/widget/timetable_import_preview_test.dart`
- `test/golden/timetable_import_preview_golden_test.dart`
- `test/golden/actual_schedule_pages_golden_test.dart`
- new `test/support/zhengfang_fixture.dart`
- new `test/integration/fixture_schedule_pipeline_test.dart` if useful.

### Documentation

- `SPEC.md`
- `docs/manual-integration.md`
- README only where the behavior summary changed.

---

## 20.21 Search commands before declaring obsolete metadata removed

Run repository-wide searches and inspect every hit:

```bash
git grep -n "teachingClass"
git grep -n "credits"
git grep -n "assessment"
git grep -n "课程代码"
git grep -n "教学班"
git grep -n "学分"
git grep -n "考核方式"
```

Expected remaining matches are allowed only when they are:

- legacy DB column definitions/generated Drift code;
- test input proving old-backup compatibility;
- DOM delimiter recognition that does not emit/store/use the value;
- historical documentation explicitly marked legacy, if intentionally retained.

Any active domain/UI/import-diff match must be justified or removed.

---

## 20.22 Definition of “implemented”, not just “described”

For each checklist item, Codex must leave behind at least one of:

- production code change;
- automated regression test;
- documented real-device verification result.

A comment/TODO stating what should happen is not completion.

The final report must include a table:

```text
Requirement | Implementation file/function | Test | Result
```

Examples:

```text
course key rotation | ImportCourseMatcher + ImportDiffEngine.build | import_diff_test | PASS
MOVE notification   | ScheduleEngine -> NotificationPlanner         | fixture pipeline | PASS
legacy backup       | ScheduleBackup._courseFromJson                | backup test      | PASS
real NWU DOM        | NwuDomExtractor verified-list adapter         | device + fixture | PASS
```

If an item cannot be verified, mark it BLOCKED with the exact reason rather than silently omitting it.


---

# 21. PHASED EXECUTION PLAN — exact order of work

This section is the default execution sequence. Follow it unless real repository state proves one phase must be reordered.

## Phase 0 — Synchronize and freeze scope

### Input
Current local branch/worktree.

### Actions
1. `git status`.
2. Preserve any uncommitted user/agent work; do not discard it.
3. `git fetch origin`.
4. Rebase or merge onto current `origin/main` according to the active branch strategy.
5. Read:
   - `CODEX_TASK.md`
   - `SPEC.md`
   - `docs/manual-integration.md`
6. Record current HEAD.
7. Run the full baseline suite.
8. If baseline is already red, fix only baseline failures before feature/refactor work.

### Output
A clean known baseline and a short local note of failing/passing commands.

### Gate
Do not start Phase 1 until failures are understood.

---

## Phase 1 — Protect current behavior with fixture tests

### Goal
Create enough deterministic coverage that identity/refactor work cannot silently break the importer.

### Files
- `tool/test_nwu_dom_extractor.mjs`
- `test/fixtures/zhengfang/*`
- new `test/support/zhengfang_fixture.dart`
- `test/domain/timetable_import_test.dart`
- `test/domain/import_diff_test.dart`
- `test/data/drift_schedule_data_repository_test.dart`

### Actions
1. Load current sanitized DOM fixture.
2. Execute extractor.
3. Assert normalized semantic result:
   - semester;
   - totalWeeks;
   - course count;
   - course names;
   - meeting count;
   - weekday/section/week masks;
   - teacher/campus/room.
4. Add no-op repeated-import test.
5. Add DB ID preservation assertions.
6. Add two same-name-course cases.
7. Add malformed verified-list fail-closed cases.

### Implementation rule
Do not modify identity algorithm yet except to expose pure functions needed for testing.

### Gate
Phase passes only if a future identity bug would be caught by tests.

---

## Phase 2 — Inspect real NWU DOM identity, read-only

### Goal
Answer one question: **Does the real personal-timetable DOM expose a stable opaque course/offering ID or meeting ID?**

### Actions
1. Run the app on the authorized device/emulator.
2. Login with the separately supplied authorized test credentials.
3. Navigate only:
   `教务系统 → 选课 → 个人课表查询`.
4. Inspect only the timetable nodes and nearest structural ancestors.
5. Check:
   - element IDs;
   - data attributes;
   - hidden values;
   - links;
   - onclick arguments;
   - stable JS parameters.
6. Compare at least two rows from the same logical course and two rows from different courses.
7. Determine whether a candidate identifier:
   - stays the same for meetings belonging to the same course;
   - differs for distinct same-name offerings;
   - appears independent of display metadata.
8. Do not commit live values. Convert any needed shape into synthetic fixture attributes.

### Decision
- If stable opaque course ID exists → use Strategy A.
- If only stable meeting IDs exist → use Strategy B.
- If neither exists → use Strategy C.

### Strategy A
Course key = remote opaque course/offering ID.
Meeting key = remote meeting ID if present, otherwise structural meeting signature.

### Strategy B
Group remote meetings conservatively using page structure; derive course identity from stable group evidence. Meeting identity uses remote meeting ID.

### Strategy C
Use conservative structural fallback. Never use obsolete fields secretly. Ambiguous same-name courses remain separate/add-remove.

### Gate
Write the chosen strategy into a code comment/doc and add a sanitized fixture reproducing the structural evidence before Phase 3.

---

## Phase 3 — Implement the new identity layer

### Goal
Make identity independent of course code / teaching class / credits / assessment.

### Files
- new `lib/domain/import/import_identity.dart`
- `lib/infrastructure/import/nwu_dom_extractor.dart`
- `lib/domain/import/import_diff.dart`
- `lib/data/repositories/drift_schedule_data_repository.dart`
- identity tests.

### Actions
1. Introduce pure normalization helpers.
2. Introduce `ImportCourseMatcher`.
3. Implement exact-key matching first.
4. Implement structural fallback with unique-winner requirement.
5. Replace metadata matcher calls.
6. Preserve existing `Course.id` when a match is found.
7. Update `sourceCourseKey` to the new remote key if key rotation occurs.
8. Preserve local note/color/hidden/deleted.
9. Preserve/remap MeetingRule IDs using existing reconciliation.
10. Preserve/remap CourseException references.

### Required tests
- exact-key no-op;
- teacher-only change;
- room-only change;
- campus-only change;
- week-mask change;
- section change;
- meeting add/remove;
- sourceCourseKey rotation;
- same-name ambiguity;
- tombstone restoration;
- MOVE/CANCEL survives remote update.

### Gate
No identity test may use code/teachingClass/credits/assessment.

---

## Phase 4 — Remove obsolete metadata from active product model

### Goal
Delete those fields from active behavior without breaking old DB/backups.

### Files
- `course.dart`
- `timetable_import.dart`
- `import_diff.dart`
- repository mappings;
- backup;
- import/course-detail UI;
- tests/docs.

### Actions
1. Remove fields from domain constructors/classes.
2. Fix compile errors systematically.
3. In DB reads, ignore legacy columns.
4. In DB writes, clear legacy columns to null.
5. In backup writer, omit legacy keys.
6. In backup reader, tolerate but ignore legacy keys.
7. In extractor, retain obsolete text labels only as delimiters if needed.
8. In diff, compare only active fields.
9. Remove conflict labels/UI.
10. Update docs.

### Search verification
Run every grep in section 20.21.

### Gate
Remaining hits must be only approved compatibility/delimiter/generated-code cases.

---

## Phase 5 — Build the full fixture-backed pipeline test

### Goal
Prove the imported timetable behaves correctly after persistence, local exceptions, notifications, widgets, and backup.

### File
- new `test/integration/fixture_schedule_pipeline_test.dart`

### Exact scenario
1. Import base fixture.
2. Load DB snapshot.
3. Assert expected courses/rules.
4. Build ScheduleEngine.
5. Assert representative dates.
6. Assert NOW/NEXT.
7. Add MOVE.
8. Assert engine + notification + widget.
9. Remove MOVE.
10. Add CANCEL.
11. Assert engine + notification + widget.
12. Remove CANCEL.
13. Add ADD.
14. Assert engine + notification + widget.
15. Backup.
16. Clear.
17. Assert empty DB / notification/widget clear at coordinator tests.
18. Restore.
19. Rebuild engine.
20. Assert schedule equivalence.

### Gate
This one test should catch cross-module semantic drift.

---

## Phase 6 — UI regression

### Goal
Ensure real product pages correctly render the same effective schedule.

### Actions
Use fixture-seeded repository state for:
- Home;
- Week;
- Month;
- Course Detail;
- import preview;
- manual edit;
- exception sheets.

Add or update golden tests only after domain/data behavior is green.

### Required states
- NOW;
- NEXT;
- no class;
- finished;
- MOVE;
- CANCEL;
- ADD;
- multiple meetings;
- odd/even;
- irregular weeks;
- long text;
- narrow screen;
- larger text scale.

### Gate
Do not “fix” a domain bug by special-casing UI output.

---

## Phase 7 — Notification/device validation

### Actions
1. Run planner unit tests.
2. Run coordinator tests.
3. Install on device.
4. Test permission denied.
5. Test permission granted.
6. Use a controlled near-future local test occurrence if current debug tooling permits without changing server data.
7. Verify one notification fires.
8. Refresh/reimport and ensure no duplicates.
9. Verify MOVE/CANCEL/ADD rebuild behavior.

### Rule
Use local fixture/manual data for timing-sensitive notification tests when possible. Real NWU account is not required for every notification run.

---

## Phase 8 — Widget/device validation

### Actions
1. Add Small widget.
2. Add Medium widget.
3. Add Large widget.
4. Keep all three simultaneously.
5. Verify NOW/NEXT state.
6. Apply local MOVE.
7. Verify refresh.
8. Apply CANCEL.
9. Verify disappearance.
10. Apply ADD.
11. Verify appearance.
12. Restart app.
13. Verify widgets still render from current snapshot.
14. Clear data.
15. Verify widget empty state.

### Gate
No PendingIntent collision or cross-widget hijacking.

---

## Phase 9 — Real NWU import final verification

Do this **after** deterministic tests pass, not before.

### Exact flow
1. clear import session only;
2. launch import;
3. authenticate;
4. navigate only to personal timetable;
5. read;
6. compare Preview to visible timetable;
7. save;
8. verify Home;
9. verify Week;
10. verify Month;
11. verify Course Detail;
12. exit;
13. re-enter Import;
14. verify login is required again.

### Repeat-import test
Without changing server data:
1. import the same real timetable again;
2. expected diff is no-op or only known benign adapter/version effects;
3. it must not duplicate courses.

For remote-change scenarios such as room/week changes, use mutated sanitized fixtures unless the server naturally contains such a case. Do not alter university data to manufacture a test.

---

## Phase 10 — Final cleanup and report

### Actions
1. Remove temporary debug code.
2. Remove any local captured authenticated DOM.
3. Search repository for credentials/sensitive strings.
4. Run formatter.
5. Run analyze.
6. Run full tests.
7. Run privacy/manifest tools.
8. Push.
9. Confirm GitHub Actions.
10. Produce completion matrix.

### Completion matrix format

```text
Phase | Change | Key file/function | Automated test | Device test | Status
```

Every P0 item must be PASS or BLOCKED with a precise reason.

---

# 22. Decision rules so the Agent does not guess

Use these rules when implementation choices are unclear:

1. **Data correctness > automatic matching.**
   If identity is ambiguous, do not merge.
2. **Stable local IDs > regenerating rows.**
   Preserve Course.id and MeetingRule.id whenever a logical match is unique.
3. **ScheduleEngine is authoritative.**
   UI, notifications and widgets consume it; they do not recreate recurrence logic.
4. **Remote timetable is read-only input.**
   The app never mutates Zhengfang.
5. **Local user changes survive refresh where semantically possible.**
   note/color/hidden/exceptions must not disappear because teacher/room changed remotely.
6. **Parser fails closed for a known verified table that is malformed.**
   Partial silent imports are worse than explicit errors.
7. **Legacy storage compatibility > immediate physical schema cleanup.**
   Ignore obsolete columns before dropping them.
8. **Fixtures are the regression source of truth; real account is the compatibility smoke test.**
9. **Do not use real-account data to manufacture edge cases.**
   Mutate sanitized fixtures locally.
10. **One issue = one narrow commit when practical.**
    Avoid giant refactors.

---

# 23. Minimum concrete deliverables expected from this task

At minimum, the final branch should contain:

1. an identity implementation independent of the four obsolete metadata fields;
2. unit tests for the identity matcher;
3. sanitized DOM extractor tests for the chosen real-page identity structure;
4. a reusable timetable fixture helper;
5. a fixture-backed Drift import/reimport test;
6. a fixture-backed full ScheduleEngine pipeline integration test;
7. MOVE/CANCEL/ADD propagation tests into notifications and widgets;
8. legacy-backup compatibility test;
9. updated UI/golden coverage where behavior changed;
10. updated SPEC/manual integration documentation;
11. a recorded real-device read-only personal-timetable smoke-test result;
12. a green CI result.

If one of these is omitted, the completion report must say exactly why.
