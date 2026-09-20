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
  const normalize = (value) => String(value == null ? '' : value)
    .replace(/\s+/g, ' ').trim();
  const text = (node) => normalize(
    node && (node.innerText || node.textContent) ? (node.innerText || node.textContent) : '',
  );
  const headerMatches = (headers, patterns) => {
    const exact = headers
      .map((header, index) => patterns.includes(header) ? index : -1)
      .filter((index) => index >= 0);
    if (exact.length) return exact;
    return headers
      .map((header, index) => patterns.some((pattern) =>
        pattern !== '课程' && header.includes(pattern)) ? index : -1)
      .filter((index) => index >= 0);
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
  ].reduce((score, patterns) => score + (headerMatches(headers, patterns).length ? 1 : 0), 0);
  const buildTableGrid = (table) => {
    const rows = Array.from(table.rows || table.querySelectorAll('tr'));
    const grid = [];
    for (let rowIndex = 0; rowIndex < rows.length; rowIndex++) {
      const row = rows[rowIndex];
      if (!grid[rowIndex]) grid[rowIndex] = [];
      const cells = Array.from(row.cells || row.querySelectorAll('td,th'));
      let columnIndex = 0;
      for (const cell of cells) {
        while (grid[rowIndex][columnIndex] !== undefined) columnIndex++;
        const rowSpan = Math.max(1, Number(cell.rowSpan) || 1);
        const colSpan = Math.max(1, Number(cell.colSpan) || 1);
        const value = text(cell);
        for (let rowOffset = 0; rowOffset < rowSpan; rowOffset++) {
          const targetRow = rowIndex + rowOffset;
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
    const source = normalize(value);
    const numeric = source.match(/\d+/);
    if (numeric) {
      const day = Number(numeric[0]);
      return day >= 1 && day <= 7 ? day : null;
    }
    const match = source.match(/[一二三四五六日天]/);
    if (!match) return null;
    return ({ '一': 1, '二': 2, '三': 3, '四': 4, '五': 5,
      '六': 6, '日': 7, '天': 7 })[match[0]] || null;
  };
  const sectionRange = (value) => {
    const numbers = String(value).match(/\d+/g) || [];
    if (!numbers.length) return null;
    const start = Number(numbers[0]);
    const end = Number(numbers[numbers.length - 1]);
    if (!Number.isInteger(start) || !Number.isInteger(end) || start < 1 || end < 1) {
      return null;
    }
    return { startSection: Math.min(start, end), endSection: Math.max(start, end) };
  };
  const weekShape = (value, numbers) => {
    if (/单|双|全/.test(value) && !numbers.length) return 'parity';
    if (/[\-~～—至]/.test(value)) return 'range';
    if (/[^\d\s,，]/.test(value)) return 'mixed';
    return 'numeric';
  };
  const courses = [];
  const issues = [];
  let maxWeek = 20;
  let sawScheduleTable = false;
  const issue = (path, message, severity = 'warning', details = null) => {
    const item = { path: path, message: message, severity: severity };
    if (details && typeof details === 'object') item.details = details;
    issues.push(item);
  };
  for (const [tableIndex, table] of Array.from(document.querySelectorAll('table')).entries()) {
    const grid = buildTableGrid(table);
    if (!grid.length) continue;
    let headerEnd = -1;
    let headers = [];
    let bestScore = 0;
    let bestHeaderEnd = 0;
    let bestHeaders = [];
    const headerLimit = Math.min(grid.length, 5);
    for (let candidateEnd = 0; candidateEnd < headerLimit; candidateEnd++) {
      const width = Math.max(...grid.slice(0, candidateEnd + 1).map((row) => row.length));
      const candidateHeaders = Array.from({ length: width }, (_, columnIndex) =>
        normalize(grid.slice(0, candidateEnd + 1)
          .map((row) => row[columnIndex] || '')
          .filter((value) => value)
          .join(' ')));
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
        issue('tables[' + tableIndex + '].header', '关键课表列无法识别，未读取该表', 'error', {
          tableIndex: tableIndex,
          headerRow: bestHeaderEnd,
          columnCount: bestHeaders.length,
          detectedRequiredColumns: bestScore,
        });
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
    const requiredIndexes = Object.fromEntries(requiredHeaders.map(([field, patterns]) => [
      field,
      headerMatches(headers, patterns),
    ]));
    const invalidRequired = requiredHeaders
      .filter(([field]) => requiredIndexes[field].length !== 1)
      .map(([field]) => field);
    if (invalidRequired.length) {
      issue('tables[' + tableIndex + '].header', '关键课表列无法唯一识别，未读取该表', 'error', {
        tableIndex: tableIndex,
        headerRow: headerEnd,
        columnCount: headers.length,
        invalidColumns: invalidRequired,
      });
      continue;
    }
    const nameIndex = uniqueHeaderIndex(headers, ['课程名称', '课程名', '课程']);
    const dayIndex = uniqueHeaderIndex(headers, ['星期', '周几', '上课星期']);
    const sectionIndex = uniqueHeaderIndex(headers, ['节次', '上课节次']);
    const weekIndex = uniqueHeaderIndex(headers, ['周次', '上课周次']);
    const codeIndex = headerIndex(headers, ['课程代码', '课程编号', '课程号']);
    const teacherIndex = headerIndex(headers, ['教师', '任课教师', '上课教师']);
    const campusIndex = headerIndex(headers, ['校区', '校区名称']);
    const roomIndex = headerIndex(headers, ['教室', '上课地点', '地点']);
    const classIndex = headerIndex(headers, ['教学班', '班级']);
    const creditIndex = headerIndex(headers, ['学分']);
    const assessmentIndex = headerIndex(headers, ['考核方式', '考试性质']);
    for (let rowIndex = headerEnd + 1; rowIndex < grid.length; rowIndex++) {
      const rowPath = 'tables[' + tableIndex + '].rows[' + rowIndex + ']';
      const cells = grid[rowIndex] || [];
      if (!cells.length || cells.every((value) => !normalize(value))) continue;
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
        issue(rowPath + '.courseName', '课程名为空，已跳过该行', 'error', rowDetails);
        continue;
      }
      if (!weekday) {
        issue(rowPath + '.weekday', '星期无法识别，已跳过该行', 'error', rowDetails);
        continue;
      }
      if (!range) {
        issue(rowPath + '.sections', '节次无法识别，已跳过该行', 'error', rowDetails);
        continue;
      }
      if (!weekText) {
        issue(rowPath + '.weeks', '周次为空，已跳过该行', 'error', rowDetails);
        continue;
      }
      const weekNumbers = Array.from(weekText.matchAll(/\d+/g), (match) => Number(match[0]));
      const weekDetails = {
        ...rowDetails,
        rawLength: weekText.length,
        rawShape: weekShape(weekText, weekNumbers),
        parsedNumbers: weekNumbers,
      };
      const invalidWeekText = (!weekNumbers.length && !/单|双|全/.test(weekText)) ||
        weekNumbers.some((week) => !Number.isInteger(week) || week < 1 || week > 64);
      if (invalidWeekText) {
        issue(rowPath + '.weeks', '周次格式无效，已跳过该行', 'error', weekDetails);
        continue;
      }
      for (const week of weekNumbers) maxWeek = Math.max(maxWeek, week);
      const code = codeIndex >= 0 ? cellAt(codeIndex) || null : null;
      const teachingClass = classIndex >= 0 ? cellAt(classIndex) || null : null;
      const teacher = teacherIndex >= 0 ? cellAt(teacherIndex) || null : null;
      const campus = campusIndex >= 0 ? cellAt(campusIndex) || null : null;
      const room = roomIndex >= 0 ? cellAt(roomIndex) || null : null;
      const rawCredits = creditIndex >= 0 ? cellAt(creditIndex) : '';
      const parsedCredits = rawCredits ? Number(rawCredits) : NaN;
      const credits = Number.isFinite(parsedCredits) && parsedCredits >= 0 ? parsedCredits : null;
      if (rawCredits && credits == null) {
        issue(rowPath + '.credits', '学分格式无法识别，已按空值处理', 'warning', rowDetails);
      }
      const key = code
        ? code + '|' + (teachingClass || '')
        : name + '|' + (teachingClass || '');
      let course = courses.find((item) => item.sourceCourseKey === key);
      if (!course) {
        course = {
          sourceCourseKey: key,
          name: name,
          code: code,
          teachingClass: teachingClass,
          credits: credits,
          assessment: assessmentIndex >= 0 ? cellAt(assessmentIndex) || null : null,
          meetings: [],
        };
        courses.push(course);
      }
      const meetingKey = [
        weekday,
        range.startSection,
        range.endSection,
        teacher || '',
        room || '',
        weekText,
      ].join('|');
      if (course.meetings.some((item) => item.sourceMeetingKey === key + '|meeting|' + meetingKey)) {
        issue(rowPath, '重复的上课安排已忽略', 'warning', rowDetails);
        continue;
      }
      course.meetings.push({
        sourceMeetingKey: key + '|meeting|' + meetingKey,
        weekday: weekday,
        startSection: range.startSection,
        endSection: range.endSection,
        teacher: teacher,
        campus: campus,
        room: room,
        weekText: weekText,
      });
    }
  }
  if (!courses.length && !sawScheduleTable) return JSON.stringify(null);
  const totalWeeks = maxWeek;
  const academicYear = year[1] + '-' + year[2];
  return JSON.stringify({
    semester: {
      remoteTermKey: academicYear + '-' + term,
      academicYear: academicYear,
      term: term,
      label: academicYear + ' 第' + term + '学期',
      totalWeeks: totalWeeks,
    },
    totalWeeks: totalWeeks,
    courses: courses,
    issues: issues,
  });
})()''';

  static const contextScript = r'''(() => {
  const loginControl = document.querySelector(
    'input[type="password"], #yhm, #mm, '
      + 'input[name*="password" i], input[id*="password" i]'
  );
  const bodyText = (document.body ? document.body.innerText : '')
    .replace(/\s+/g, ' ').trim();
  const loginText = bodyText.includes('用户登录') && bodyText.includes('密码');
  if (loginControl || loginText) return 'login';

  const path = location.pathname.toLowerCase();
  const pathHint = /(?:kbcx|xskbcx|timetable|schedule|course)/.test(path);
  const payloadHint = window.__NWU_SCHEDULE_PAYLOAD__ != null ||
    window.__NWU_TIMETABLE__ != null ||
    window.nwuSchedulePayload != null;
  const labels = ['课程', '星期', '节次', '周次', '教室']
    .filter((label) => bodyText.includes(label)).length;
  return pathHint || payloadHint || labels >= 2 ? 'timetable' : 'other';
})()''';
}
