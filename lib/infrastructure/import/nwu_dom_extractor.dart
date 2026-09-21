/// JavaScript executed inside the authenticated NWU Zhengfang WebView.
///
/// Keep this script isolated from the page widget so its DOM contract can be
/// reviewed and regression-tested without rendering Flutter UI.
class NwuDomExtractor {
  const NwuDomExtractor._();

  static const extractionScript = r'''(() => {
  const candidates = [
    window.__NWU_SCHEDULE_PAYLOAD__,
    window.__NWU_TIMETABLE__,
    window.nwuSchedulePayload,
  ];
  for (const candidate of candidates) {
    if (candidate == null) continue;
    try {
      return JSON.stringify(typeof candidate === 'string' ? JSON.parse(candidate) : candidate);
    } catch (_) {}
  }

  const bodyText = document.body ? document.body.innerText : '';
  const year = bodyText.match(/(20\d{2})\s*[-—~至]\s*(20\d{2})/);
  const termText = bodyText.match(/第\s*([一二三123])\s*学期/);
  if (!year || !termText) return JSON.stringify(null);

  const termMap = { '一': 1, '二': 2, '三': 3, '1': 1, '2': 2, '3': 3 };
  const term = termMap[termText[1]];
  if (!term) return JSON.stringify(null);
  const academicYear = year[1] + '-' + year[2];

  const normalize = (value) => String(value == null ? '' : value)
    .replace(/\s+/g, ' ').trim();
  const text = (node) => normalize(
    node && (node.innerText || node.textContent)
      ? (node.innerText || node.textContent)
      : '',
  );

  // Zhengfang pages currently replace Array.prototype.filter/some/every with
  // legacy callbacks whose argument order is incompatible with standard JS.
  // The extractor runs in that page context, so keep these operations local
  // and deterministic instead of trusting page-owned prototypes.
  const filterItems = (items, predicate) => {
    const result = [];
    for (let index = 0; index < items.length; index++) {
      const item = items[index];
      if (predicate(item, index, items)) result.push(item);
    }
    return result;
  };
  const someItems = (items, predicate) => {
    for (let index = 0; index < items.length; index++) {
      if (predicate(items[index], index, items)) return true;
    }
    return false;
  };
  const everyItems = (items, predicate) => {
    for (let index = 0; index < items.length; index++) {
      if (!predicate(items[index], index, items)) return false;
    }
    return true;
  };

  const courses = [];
  const issues = [];
  let maxWeek = 0;
  // NWU's current undergraduate timetable has eleven schedulable periods.
  // Keep malformed DOM section values out of the normalized payload instead
  // of waiting for the Dart validator to reject them later.
  const maxSupportedSections = 11;

  const hashIdentity = (value) => {
    let hash = 2166136261;
    for (let index = 0; index < value.length; index++) {
      hash ^= value.charCodeAt(index);
      hash = Math.imul(hash, 16777619);
    }
    return (hash >>> 0).toString(16).padStart(8, '0');
  };

  const issue = (path, message, severity = 'warning', details = null) => {
    const item = { path: path, message: message, severity: severity };
    if (details && typeof details === 'object') item.details = details;
    issues.push(item);
  };

  const weekShape = (value, numbers) => {
    if (/单|双|全/.test(value) && !numbers.length) return 'parity';
    if (/[\-~～—至]/.test(value)) return 'range';
    if (/[^\d\s,，、()（）周单双全\-~～—至]/.test(value)) return 'mixed';
    return 'numeric';
  };

  const validateWeekText = (weekText, path, details) => {
    const weekNumbers = Array.from(
      weekText.matchAll(/\d+/g),
      (match) => Number(match[0]),
    );
    const unexpectedCharacters = filterItems(Array.from(weekText), (character) =>
      /[^\d\s,，、()（）\[\]{}单双全周次第\-~～—至]/u.test(character));
    const unexpectedCharacterClasses = Array.from(new Set(
      unexpectedCharacters.map((character) => {
        if (/[\u3400-\u9fff]/u.test(character)) return 'han';
        if (/[A-Za-z]/.test(character)) return 'latin';
        return 'symbol';
      }),
    ));
    const weekDetails = {
      ...details,
      rawLength: weekText.length,
      rawShape: weekShape(weekText, weekNumbers),
      parsedNumbers: weekNumbers,
      unexpectedCharacterClasses: unexpectedCharacterClasses,
      unexpectedCharacterCount: unexpectedCharacters.length,
    };
    const invalid =
      unexpectedCharacters.length > 0 ||
      (!weekNumbers.length && !/单|双|全/.test(weekText)) ||
      someItems(
        weekNumbers,
        (week) => !Number.isInteger(week) || week < 1 || week > 64,
      );
    if (invalid) {
      issue(path, '周次字段包含无法识别的内容，已跳过该行', 'error', weekDetails);
      return false;
    }
    if (/单|双|全/.test(weekText) && !weekNumbers.length) {
      maxWeek = Math.max(maxWeek, 20);
    }
    for (const week of weekNumbers) maxWeek = Math.max(maxWeek, week);
    return true;
  };

  const addMeeting = ({
    courseGroupKey,
    name,
    weekday,
    startSection,
    endSection,
    teacher,
    campus,
    room,
    weekText,
    path,
    details,
    identityHint = '',
  }) => {
    if (!validateWeekText(weekText, path + '.weeks', details)) return;

    // courseGroupKey exists only while walking the DOM. It may contain a row
    // ordinal to keep two visually separate rows apart during parsing, but it
    // must never become part of the persisted sourceCourseKey. The latter is
    // derived from stable structural data in buildPayload().
    let course = courses.find((item) => item.groupKey === courseGroupKey);
    if (!course) {
      course = {
        groupKey: courseGroupKey,
        name: name,
        meetings: [],
        identityHint: identityHint,
      };
      courses.push(course);
    }

    // Keep identity tied to the recurring time pattern, not mutable display
    // metadata such as teacher or room. Re-import reconciliation can therefore
    // preserve local overrides when a teacher or classroom changes.
    const meetingKey = [
      weekday,
      startSection,
      endSection,
      weekText,
    ].join('|');
    const sourceMeetingKey =
      courseGroupKey + '|meeting|' + meetingKey;

    if (
      someItems(
        course.meetings,
        (item) => item.sourceMeetingKey === sourceMeetingKey,
      )
    ) {
      issue(path, '重复的上课安排已忽略', 'warning', details);
      return;
    }

    course.meetings.push({
      sourceMeetingKey: sourceMeetingKey,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      teacher: teacher || null,
      campus: campus || null,
      room: room || null,
      weekText: weekText,
    });
  };

  const marker = (source, pattern) => {
    const match = pattern.exec(source);
    return match == null
      ? null
      : {
          index: match.index,
          end: match.index + match[0].length,
        };
  };

  const markerAfter = (source, after, pattern) => {
    const match = pattern.exec(source.slice(after));
    return match == null
      ? null
      : {
          index: after + match.index,
          end: after + match.index + match[0].length,
        };
  };

  const parseListCourseInfo = ({
    source,
    weekday,
    startSection,
    endSection,
    path,
    details,
    courseGroupKey,
    identityHint,
  }) => {
    const week = marker(source, /周数\s*[:：]/);
    const campus = marker(source, /校区\s*[:：]/);
    const room = marker(source, /上课地点\s*[:：]/);
    const teacher = marker(source, /教师\s*[:：]/);

    if (week == null) {
      issue(
        path + '.weeks',
        '周次标签无法识别，已跳过该行',
        'error',
        details,
      );
      return;
    }
    if (campus == null) {
      issue(
        path + '.campus',
        '校区标签无法识别，已跳过该行',
        'error',
        details,
      );
      return;
    }
    if (room == null) {
      issue(
        path + '.room',
        '上课地点标签无法识别，已跳过该行',
        'error',
        details,
      );
      return;
    }
    if (teacher == null) {
      issue(
        path + '.teacher',
        '教师标签无法识别，已跳过该行',
        'error',
        details,
      );
      return;
    }
    if (
      !(week.index < campus.index &&
        campus.index < room.index &&
        room.index < teacher.index)
    ) {
      issue(
        path + '.structure',
        '课表信息标签顺序无法识别，已跳过该行',
        'error',
        details,
      );
      return;
    }

    const rawName = normalize(source.slice(0, week.index));
    const name = normalize(
      rawName
        .replace(/^(?:【调】|\[自修\])\s*/u, '')
        .replace(/[◎★〇◆■☆]+$/u, ''),
    );
    const weekText = normalize(source.slice(week.end, campus.index));
    const campusText = normalize(source.slice(campus.end, room.index));
    const roomText = normalize(source.slice(room.end, teacher.index));
    // These labels are delimiters only. Their values are never read into the
    // product payload, identity fingerprint, diagnostics, or diff. Keeping a
    // single boundary matcher here prevents obsolete academic metadata from
    // becoming an accidental product field again while still trimming the
    // teacher value before the next Zhengfang label.
    const teacherBoundary = markerAfter(
      source,
      teacher.end,
      /(?:教学班(?:组成)?|考核方式|选课备注|课程学时组成|周学时|总学时|学分|课程(?:代码|编号|号))\s*[:：]/,
    );
    const teacherText = normalize(
      source.slice(teacher.end, teacherBoundary?.index ?? source.length),
    );
    if (!name) {
      issue(path + '.courseName', '课程名为空，已跳过该行', 'error', details);
      return;
    }
    if (!weekText) {
      issue(path + '.weeks', '周次为空，已跳过该行', 'error', details);
      return;
    }

    addMeeting({
      courseGroupKey: courseGroupKey,
      name: name,
      weekday: weekday,
      startSection: startSection,
      endSection: endSection,
      teacher: teacherText || null,
      campus: campusText || null,
      room: roomText || null,
      weekText: weekText,
      path: path,
      details: details,
      // Keep only the structural grouping token supplied by the table walker.
      // The text of obsolete metadata labels is used above solely as a
      // delimiter for teacher/room fields.
      identityHint: identityHint,
    });
  };

  const parseVerifiedListTable = () => {
    const table =
      typeof document.querySelector === 'function'
        ? document.querySelector('#kblist_table')
        : null;
    if (!table) return false;

    const rows = Array.from(table.rows || table.querySelectorAll('tr'));
    let currentWeekday = null;
    let currentRange = null;
    let currentGroupKey = null;
    let currentIdentityHint = '';
    let currentRangeRowsRemaining = 0;
    let sawCourseInfo = false;

    for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      const row = rows[rowIndex];
      const cells = Array.from(row.cells || row.querySelectorAll('td,th'));
      if (!cells.length) continue;

      const weekdayCell = cells.find((cell) =>
        /^xq_rowspan_([1-7])$/.test(cell.id || ''),
      );
      if (weekdayCell) {
        const match = /^xq_rowspan_([1-7])$/.exec(weekdayCell.id || '');
        currentWeekday = match ? Number(match[1]) : null;
        currentRange = null;
        currentGroupKey = null;
        currentIdentityHint = '';
        currentRangeRowsRemaining = 0;
      }

      const sectionCell = cells.find((cell) =>
        /^jc_([1-7])-(\d+)-(\d+)$/.test(cell.id || ''),
      );
      if (sectionCell) {
        const match =
          /^jc_([1-7])-(\d+)-(\d+)$/.exec(sectionCell.id || '');
        if (match) {
          currentWeekday = Number(match[1]);
          const start = Number(match[2]);
          const end = Number(match[3]);
          currentRange = {
            startSection: Math.min(start, end),
            endSection: Math.max(start, end),
          };
          const declaredRowSpan = Number(sectionCell.rowSpan);
          const rowGroup = row.parentElement && row.parentElement.rows
            ? Array.from(row.parentElement.rows)
            : rows;
          const rowGroupIndex = rowGroup.indexOf(row);
          const span = declaredRowSpan === 0
            ? Math.max(1, rowGroup.length - Math.max(0, rowGroupIndex))
            : Math.max(1, declaredRowSpan || 1);
          currentGroupKey = span > 1
            ? 'verified-span-' + rowIndex + '-' + sectionCell.id
            : 'verified-row-' + rowIndex;
          currentIdentityHint = span > 1
            ? 'section|' + sectionCell.id
            : '';
          currentRangeRowsRemaining = span;
        }
      }

      if (!sectionCell && currentRangeRowsRemaining <= 0) {
        currentRange = null;
        currentGroupKey = null;
      }

      // Once a section context is present, every non-empty non-key cell is a
      // candidate course detail cell. Do not filter only by the `周数` label:
      // a malformed row missing that label must become a validation error,
      // rather than disappearing and being interpreted as a remote deletion.
      const infoCells = filterItems(cells, (cell) => {
        const id = cell.id || '';
        if (/^xq_rowspan_[1-7]$/.test(id)) return false;
        if (/^jc_[1-7]-\d+-\d+$/.test(id)) return false;
        const value = text(cell);
        if (!value) return false;
        if (currentRange != null) return true;
        // A broken section cell can leave the row without a valid range. It
        // is still recognisable as a course row from its detail labels, and
        // must reach the section validation below instead of disappearing.
        return /(?:周数\s*[:：]|校区\s*[:：]|上课地点\s*[:：]|教师\s*[:：])/.test(value);
      });

      for (let infoIndex = 0; infoIndex < infoCells.length; infoIndex++) {
        const infoText = text(infoCells[infoIndex]);
        const path =
          'tables#kblist_table.rows[' + rowIndex + '].courses[' + infoIndex + ']';
        const details = {
          tableId: 'kblist_table',
          rowIndex: rowIndex,
          courseIndex: infoIndex,
        };
        sawCourseInfo = true;

        if (
          currentWeekday == null ||
          currentWeekday < 1 ||
          currentWeekday > 7
        ) {
          issue(path + '.weekday', '星期上下文无法识别，已跳过该行', 'error', details);
          continue;
        }
        if (
          currentRange == null ||
          currentRange.startSection < 1 ||
          currentRange.endSection > maxSupportedSections ||
          currentRange.endSection < currentRange.startSection
        ) {
          issue(path + '.sections', '节次上下文无法识别，已跳过该行', 'error', details);
          continue;
        }

        parseListCourseInfo({
          source: infoText,
          weekday: currentWeekday,
          startSection: currentRange.startSection,
          endSection: currentRange.endSection,
          path: path,
          details: details,
          courseGroupKey: currentGroupKey || 'verified-row-' + rowIndex,
          identityHint: currentIdentityHint,
        });
      }

      if (currentRangeRowsRemaining > 0) {
        currentRangeRowsRemaining -= 1;
      }
    }

    if (!sawCourseInfo) {
      issue(
        'tables#kblist_table',
        '已找到课表列表，但没有读取到课程信息',
        'error',
        { tableId: 'kblist_table', rowCount: rows.length },
      );
    }
    return true;
  };

  const buildPayload = () => {
    const totalWeeks = maxWeek > 0 ? maxWeek : 20;
    const fingerprints = new Map();
    const normalizedCourses = courses.map((course) => {
      const shapes = course.meetings.map((meeting) => [
        meeting.weekday,
        meeting.startSection,
        meeting.endSection,
        normalize(meeting.weekText),
      ].join('|')).sort();
      const fingerprint = 'nwu-v3|course|' + hashIdentity([
        academicYear,
        term,
        normalize(course.name),
        normalize(course.identityHint || ''),
        ...shapes,
      ].join('|'));
      const ordinal = fingerprints.get(fingerprint) || 0;
      fingerprints.set(fingerprint, ordinal + 1);
      const sourceCourseKey = ordinal === 0
        ? fingerprint
        : fingerprint + '|duplicate-' + ordinal;
      return {
        sourceCourseKey: sourceCourseKey,
        name: course.name,
        meetings: course.meetings.map((meeting) => ({
          ...meeting,
          sourceMeetingKey: sourceCourseKey + '|meeting|' + [
            meeting.weekday,
            meeting.startSection,
            meeting.endSection,
            normalize(meeting.weekText),
          ].join('|'),
        })),
      };
    });
    return {
      semester: {
        remoteTermKey: academicYear + '-' + term,
        academicYear: academicYear,
        term: term,
        label: academicYear + ' 第' + term + '学期',
        totalWeeks: totalWeeks,
      },
      totalWeeks: totalWeeks,
      courses: normalizedCourses,
      issues: issues,
    };
  };

  // The authenticated NWU page exposes a stable list view that is materially
  // easier and safer to parse than the visual timetable grid:
  //   #kblist_table
  //   xq_rowspan_<weekday>
  //   jc_<weekday>-<start>-<end>
  // Prefer it whenever present. If it exists but is malformed, return the
  // validation errors instead of silently falling back to a heuristic parser.
  if (parseVerifiedListTable()) {
    return JSON.stringify(buildPayload());
  }

  const headerMatches = (headers, patterns) => {
    const exact = filterItems(
      headers.map((header, index) => patterns.includes(header) ? index : -1),
      (index) => index >= 0,
    );
    if (exact.length) return exact;
    return filterItems(
      headers.map((header, index) => someItems(patterns, (pattern) =>
        pattern !== '课程' && header.includes(pattern)) ? index : -1),
      (index) => index >= 0,
    );
  };
  const headerIndex = (headers, patterns) => {
    const matches = headerMatches(headers, patterns);
    return matches.length ? matches[0] : -1;
  };
  const uniqueHeaderIndex = (headers, patterns) => {
    const matches = headerMatches(headers, patterns);
    return matches.length === 1 ? matches[0] : -1;
  };
  const headerScore = (headers) => [
    ['课程名称', '课程名', '课程'],
    ['星期', '周几', '上课星期'],
    ['节次', '上课节次'],
    ['周次', '上课周次'],
  ].reduce(
    (score, patterns) =>
      score + (headerMatches(headers, patterns).length ? 1 : 0),
    0,
  );
  const buildTableGrid = (table) => {
    const rows = Array.from(table.rows || table.querySelectorAll('tr'));
    const rowIndexes = new Map(rows.map((row, index) => [row, index]));
    const grid = [];
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      const row = rows[rowIndex];
      if (!grid[rowIndex]) grid[rowIndex] = [];
      const cells = Array.from(row.cells || row.querySelectorAll('td,th'));
      let columnIndex = 0;
      for (const cell of cells) {
        while (grid[rowIndex][columnIndex] !== undefined) columnIndex++;
        const declaredRowSpan = Number(cell.rowSpan);
        // HTML uses rowspan="0" to mean all remaining rows in the current
        // table section. The DOM exposes that value as 0; treating it as one
        // row shifts every following logical column.
        const rowGroup = row.parentElement && row.parentElement.rows
          ? Array.from(row.parentElement.rows)
          : rows;
        const rowGroupIndex = rowGroup.indexOf(row);
        const rowSpan = declaredRowSpan === 0
          ? Math.max(
              1,
              rowGroup.length - Math.max(0, rowGroupIndex),
            )
          : Math.max(1, declaredRowSpan || 1);
        const colSpan = Math.max(1, Number(cell.colSpan) || 1);
        const value = text(cell);
        for (let rowOffset = 0; rowOffset < rowSpan; rowOffset++) {
          const groupRow = rowGroup[rowGroupIndex + rowOffset];
          const targetRow = rowIndexes.has(groupRow)
            ? rowIndexes.get(groupRow)
            : rowIndex + rowOffset;
          if (targetRow == null || targetRow >= rows.length) break;
          if (!grid[targetRow]) grid[targetRow] = [];
          for (let columnOffset = 0; columnOffset < colSpan; columnOffset++) {
            const targetColumn = columnIndex + columnOffset;
            if (grid[targetRow][targetColumn] === undefined) {
              grid[targetRow][targetColumn] = value;
            }
          }
        }
        columnIndex += colSpan;
      }
    }
    return grid.slice(0, rows.length).map((row) => row || []);
  };
  const dayNumber = (value) => {
    const source = normalize(value).replace(/\s+/g, '');
    const numeric = source.match(/^(?:星期|周|礼拜)?([1-7])$/);
    if (numeric) {
      const day = Number(numeric[1]);
      return day >= 1 && day <= 7 ? day : null;
    }
    const match = source.match(/[一二三四五六日天]/);
    if (!match) return null;
    return ({
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '日': 7,
      '天': 7,
    })[match[0]] || null;
  };
  const sectionRange = (value) => {
    const numbers = String(value).match(/\d+/g) || [];
    if (!numbers.length) return null;
    const start = Number(numbers[0]);
    const end = Number(numbers[numbers.length - 1]);
    if (
      !Number.isInteger(start) ||
      !Number.isInteger(end) ||
      start < 1 ||
      end < 1 ||
      start > maxSupportedSections ||
      end > maxSupportedSections
    ) {
      return null;
    }
    return {
      startSection: Math.min(start, end),
      endSection: Math.max(start, end),
    };
  };

  let sawScheduleTable = false;
  for (
    const [tableIndex, table]
    of Array.from(document.querySelectorAll('table')).entries()
  ) {
    const grid = buildTableGrid(table);
    if (!grid.length) continue;

    let headerEnd = -1;
    let headers = [];
    let bestScore = 0;
    let bestHeaderEnd = 0;
    let bestHeaders = [];
    const headerLimit = Math.min(grid.length, 5);

    for (let candidateEnd = 0; candidateEnd < headerLimit; candidateEnd++) {
      const width = Math.max(
        ...grid.slice(0, candidateEnd + 1).map((row) => row.length),
      );
      const candidateHeaders = Array.from(
        { length: width },
        (_, columnIndex) => normalize(
          filterItems(
            grid
              .slice(0, candidateEnd + 1)
              .map((row) => row[columnIndex] || ''),
            (value) => value,
          ).join(' '),
        ),
      );
      const score = headerScore(candidateHeaders);
      if (score > bestScore) {
        bestScore = score;
        bestHeaderEnd = candidateEnd;
        bestHeaders = candidateHeaders;
      }
      if (score >= 4) {
        headerEnd = candidateEnd;
        headers = candidateHeaders;
        break;
      }
    }

    if (headerEnd < 0) {
      if (bestScore >= 2) {
        sawScheduleTable = true;
        issue(
          'tables[' + tableIndex + '].header',
          '关键课表列无法识别，未读取该表',
          'error',
          {
            tableIndex: tableIndex,
            headerRow: bestHeaderEnd,
            columnCount: bestHeaders.length,
            detectedRequiredColumns: bestScore,
          },
        );
      }
      continue;
    }

    sawScheduleTable = true;
    const requiredHeaders = [
      ['courseName', ['课程名称', '课程名', '课程']],
      ['weekday', ['星期', '周几', '上课星期']],
      ['sections', ['节次', '上课节次']],
      ['weeks', ['周次', '上课周次']],
    ];
    const requiredIndexes = Object.fromEntries(
      requiredHeaders.map(([field, patterns]) => [
        field,
        headerMatches(headers, patterns),
      ]),
    );
    const invalidRequired = filterItems(
      requiredHeaders,
      ([field]) => requiredIndexes[field].length !== 1,
    )
      .map(([field]) => field);
    const duplicateRequired = filterItems(
      filterItems(
        requiredHeaders,
        ([field]) => requiredIndexes[field].length === 1,
      ),
      ([field], fieldIndex, fields) => {
        const index = requiredIndexes[field][0];
        return someItems(
          fields,
          ([otherField], otherIndex) =>
            otherIndex !== fieldIndex &&
            requiredIndexes[otherField].length === 1 &&
            requiredIndexes[otherField][0] === index,
        );
      },
    )
      .map(([field]) => field);
    const invalidColumns = [
      ...new Set([...invalidRequired, ...duplicateRequired]),
    ];
    if (invalidColumns.length) {
      issue(
        'tables[' + tableIndex + '].header',
        '关键课表列无法唯一识别，未读取该表',
        'error',
        {
          tableIndex: tableIndex,
          headerRow: headerEnd,
          columnCount: headers.length,
          invalidColumns: invalidColumns,
          duplicateColumns: duplicateRequired,
        },
      );
      continue;
    }

    const nameIndex =
      uniqueHeaderIndex(headers, ['课程名称', '课程名', '课程']);
    const dayIndex =
      uniqueHeaderIndex(headers, ['星期', '周几', '上课星期']);
    const sectionIndex =
      uniqueHeaderIndex(headers, ['节次', '上课节次']);
    const weekIndex =
      uniqueHeaderIndex(headers, ['周次', '上课周次']);
    const teacherIndex =
      headerIndex(headers, ['教师', '任课教师', '上课教师']);
    const campusIndex =
      headerIndex(headers, ['校区', '校区名称']);
    const roomIndex =
      headerIndex(headers, ['教室', '上课地点', '地点']);
    for (let rowIndex = headerEnd + 1; rowIndex < grid.length; rowIndex++) {
      const rowPath = 'tables[' + tableIndex + '].rows[' + rowIndex + ']';
      const cells = grid[rowIndex] || [];
      if (!cells.length || everyItems(cells, (value) => !normalize(value))) {
        continue;
      }

      const cellAt = (index) => index >= 0 ? normalize(cells[index]) : '';
      const name = cellAt(nameIndex);
      const weekday = dayNumber(cellAt(dayIndex));
      const range = sectionRange(cellAt(sectionIndex));
      const weekText = cellAt(weekIndex);
      const rowDetails = {
        tableIndex: tableIndex,
        rowIndex: rowIndex,
        columnCount: cells.length,
      };

      if (!name) {
        issue(
          rowPath + '.courseName',
          '课程名为空，已跳过该行',
          'error',
          rowDetails,
        );
        continue;
      }
      if (!weekday) {
        issue(
          rowPath + '.weekday',
          '星期无法识别，已跳过该行',
          'error',
          rowDetails,
        );
        continue;
      }
      if (!range) {
        issue(
          rowPath + '.sections',
          '节次无法识别，已跳过该行',
          'error',
          rowDetails,
        );
        continue;
      }
      if (!weekText) {
        issue(
          rowPath + '.weeks',
          '周次为空，已跳过该行',
          'error',
          rowDetails,
        );
        continue;
      }

      // A rowspan on the course-name cell is the only structural grouping
      // signal available in a metadata-free generic table. Preserve that
      // group; when no rowspan exists, keep rows separate so two same-name
      // offerings are never silently merged.
      let spanStart = null;
      for (let candidate = rowIndex; candidate > headerEnd; candidate--) {
        const candidateRow = table.rows[candidate];
        if (!candidateRow) continue;
        const candidateNameCell = Array.from(
          candidateRow.cells || candidateRow.querySelectorAll('td,th'),
        ).find((cell) => text(cell) === name);
        if (!candidateNameCell) continue;
        const declaredSpan = Number(candidateNameCell.rowSpan);
        const groupRows = candidateRow.parentElement && candidateRow.parentElement.rows
          ? Array.from(candidateRow.parentElement.rows)
          : table.rows;
        const groupIndex = groupRows.indexOf(candidateRow);
        const span = declaredSpan === 0
          ? Math.max(1, groupRows.length - Math.max(0, groupIndex))
          : Math.max(1, declaredSpan || 1);
        if (candidate + span > rowIndex) spanStart = candidate;
        break;
      }
      // A row/section ordinal is useful only for keeping the current DOM
      // group separate while parsing. Generic tables do not expose a stable
      // remote identifier, so the final course fingerprint intentionally uses
      // only the course name and meeting structure.
      const courseGroupKey = spanStart == null
        ? 'generic-row-' + rowIndex
        : 'generic-span-' + spanStart;

      addMeeting({
        courseGroupKey: courseGroupKey,
        name: name,
        weekday: weekday,
        startSection: range.startSection,
        endSection: range.endSection,
        teacher: teacherIndex >= 0 ? cellAt(teacherIndex) || null : null,
        campus: campusIndex >= 0 ? cellAt(campusIndex) || null : null,
        room: roomIndex >= 0 ? cellAt(roomIndex) || null : null,
        weekText: weekText,
        path: rowPath,
        details: rowDetails,
        identityHint: '',
      });
    }
  }

  if (!courses.length && !sawScheduleTable) {
    return JSON.stringify(null);
  }
  return JSON.stringify(buildPayload());
})()''';

  static const prepareListViewScript = r'''(() => {
  const payloadHint = window.__NWU_SCHEDULE_PAYLOAD__ != null ||
    window.__NWU_TIMETABLE__ != null ||
    window.nwuSchedulePayload != null;
  if (payloadHint) return 'ready';

  const listTable = document.querySelector('#kblist_table');
  if (listTable) return 'ready';

  const gridTable = document.querySelector('#kbgrid_table_0');
  if (!gridTable) return 'not-timetable';

  const controls = Array.from(
    document.querySelectorAll(
      'a, button, input[type="button"], input[type="submit"]',
    ),
  );
  let listControl = null;
  for (let index = 0; index < controls.length; index++) {
    const element = controls[index];
    const label = String(
      element.innerText || element.textContent || element.value || '',
    ).replace(/\s+/g, '').trim();
    if (label === '列表') {
      listControl = element;
      break;
    }
  }
  if (!listControl) return 'list-control-missing';

  listControl.click();
  return 'switching';
})()''';

  static const listViewReadyScript = r'''(() => {
  const payloadHint = window.__NWU_SCHEDULE_PAYLOAD__ != null ||
    window.__NWU_TIMETABLE__ != null ||
    window.nwuSchedulePayload != null;
  if (payloadHint) return 'ready';
  return document.querySelector('#kblist_table') ? 'ready' : 'waiting';
})()''';

  static const contextScript = r'''(() => {
  const isVisible = (element) => {
    if (!element || element.hidden ||
        element.getAttribute?.('aria-hidden') === 'true') {
      return false;
    }
    try {
      const style = typeof window.getComputedStyle === 'function'
        ? window.getComputedStyle(element)
        : null;
      if (style && (style.display === 'none' ||
          style.visibility === 'hidden' || style.opacity === '0')) {
        return false;
      }
      if (typeof element.getClientRects === 'function' &&
          element.getClientRects().length === 0) {
        return false;
      }
    } catch (_) {
      // A missing layout API must not make the context detector crash. The
      // URL and concrete timetable checks below remain the safety boundary.
    }
    return true;
  };
  const loginSelector = 'input[type="password"], #yhm, #mm, '
    + 'input[name*="password" i], input[id*="password" i]';
  const loginCandidate = typeof document.querySelector === 'function'
    ? document.querySelector(loginSelector)
    : null;
  const loginControls = typeof document.querySelectorAll === 'function'
    ? Array.from(document.querySelectorAll(loginSelector))
    : loginCandidate ? [loginCandidate] : [];
  let loginControl = null;
  for (let index = 0; index < loginControls.length; index++) {
    if (isVisible(loginControls[index])) {
      loginControl = loginControls[index];
      break;
    }
  }
  const bodyText = (document.body ? document.body.innerText : '')
    .replace(/\s+/g, ' ').trim();
  const loginText = bodyText.includes('用户登录') && bodyText.includes('密码');
  if (loginControl || loginText) return 'login';

  const listTable = typeof document.querySelector === 'function'
    ? document.querySelector('#kblist_table')
    : null;
  const gridTable = typeof document.querySelector === 'function'
    ? document.querySelector('#kbgrid_table_0')
    : null;
  if (listTable || gridTable) return 'timetable';

  // The URL allowlist is enforced by the Flutter WebView layer. Inside an
  // allowlisted page, still require a concrete extraction source before the
  // bridge can be enabled. A path fragment or a couple of Chinese labels are
  // not sufficient: ordinary Zhengfang pages may contain both while exposing
  // no timetable data at all.
  const payloadHint = window.__NWU_SCHEDULE_PAYLOAD__ != null ||
    window.__NWU_TIMETABLE__ != null ||
    window.nwuSchedulePayload != null;
  return payloadHint ? 'timetable' : 'other';
})()''';
}
