import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const repoRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const dartSource = fs.readFileSync(
  path.join(repoRoot, 'lib', 'infrastructure', 'import', 'nwu_dom_extractor.dart'),
  'utf8',
);

const quote = String.fromCharCode(39).repeat(3);
const extractDartRawString = (markerName) => {
  const marker = 'static const ' + markerName + ' = r' + quote;
  const start = dartSource.indexOf(marker);
  assert.notEqual(start, -1, markerName + ' marker is present');
  const bodyStart = start + marker.length;
  const end = dartSource.indexOf(quote + ';', bodyStart);
  assert.notEqual(end, -1, markerName + ' terminator is present');
  return dartSource.slice(bodyStart, end);
};

const extractionScript = extractDartRawString('extractionScript');
const prepareListViewScript = extractDartRawString('prepareListViewScript');
const listViewReadyScript = extractDartRawString('listViewReadyScript');
const contextScript = extractDartRawString('contextScript');
new vm.Script(extractionScript);
new vm.Script(prepareListViewScript);
new vm.Script(listViewReadyScript);
new vm.Script(contextScript);

const decodeText = (value) => value
  .replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ')
  .replace(/&amp;/g, '&')
  .replace(/\s+/g, ' ')
  .trim();

const attribute = (source, name) =>
  source.match(new RegExp(name + '="([^"]*)"', 'i'))?.[1] ?? null;

const parseFixtureDocument = (html) => {
  const tables = [...html.matchAll(/<table\b([^>]*)>([\s\S]*?)<\/table>/gi)]
    .map((tableMatch) => {
      const tableAttributes = tableMatch[1];
      const parseRows = (source) => [...source.matchAll(
        /<tr\b[^>]*>([\s\S]*?)<\/tr>/gi,
      )].map((rowMatch) => ({
        cells: [...rowMatch[1].matchAll(
          /<(td|th)\b([^>]*)>([\s\S]*?)<\/\1>/gi,
        )].map((cellMatch) => {
          const attrs = cellMatch[2];
          const value = decodeText(cellMatch[3]);
          return {
            id: attribute(attrs, 'id') ?? '',
            innerText: value,
            textContent: value,
            rowSpan: Number(attribute(attrs, 'rowspan') ?? 1),
            colSpan: Number(attribute(attrs, 'colspan') ?? 1),
          };
        }),
      }));
      const sections = [...tableMatch[2].matchAll(
        /<(thead|tbody|tfoot)\b[^>]*>([\s\S]*?)<\/\1>/gi,
      )];
      const rowGroups = sections.length
        ? sections.map((section) => parseRows(section[2]))
        : [parseRows(tableMatch[2])];
      const rows = rowGroups.flat();
      for (const groupRows of rowGroups) {
        const parent = { rows: groupRows };
        for (const row of groupRows) {
          row.parentElement = parent;
          for (const cell of row.cells) cell.parentElement = row;
        }
      }
      const table = {
        id: attribute(tableAttributes, 'id') ?? '',
        rows,
      };
      table.querySelectorAll = (selector) =>
        selector === 'tr' ? table.rows : [];
      return table;
    });

  const document = {
    body: { innerText: decodeText(html) },
    querySelector(selector) {
      if (selector.startsWith('#')) {
        return tables.find((table) => table.id === selector.slice(1)) ?? null;
      }
      return null;
    },
    querySelectorAll(selector) {
      return selector === 'table' ? tables : [];
    },
  };

  return { document, tables };
};

const runExtraction = (html, { legacyArrayCallbacks = false } = {}) => {
  const fixtureDocument = parseFixtureDocument(html);
  const context = {
    window: {},
    location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
    document: fixtureDocument.document,
  };
  if (legacyArrayCallbacks) {
    vm.runInNewContext(`
      Array.prototype.filter = function(callback) {
        const result = [];
        for (let index = 0; index < this.length; index++) {
          if (callback(index, this[index], this)) result.push(this[index]);
        }
        return result;
      };
      Array.prototype.some = function(callback) {
        for (let index = 0; index < this.length; index++) {
          if (callback(index, this[index], this)) return true;
        }
        return false;
      };
      Array.prototype.every = function(callback) {
        for (let index = 0; index < this.length; index++) {
          if (!callback(index, this[index], this)) return false;
        }
        return true;
      };
    `, context);
  }
  return {
    payload: JSON.parse(vm.runInNewContext(extractionScript, context)),
    context,
    fixtureDocument,
  };
};

const makeStructuredElement = ({
  tagName = 'div',
  id = '',
  className = '',
  rowSpan = 1,
  colSpan = 1,
  ownText = '',
  children = [],
}) => {
  const element = {
    tagName: tagName.toUpperCase(),
    id,
    className,
    rowSpan,
    colSpan,
    children,
    parentElement: null,
    get innerText() {
      return ownText + children.map((child) => child.innerText).join('');
    },
    get textContent() {
      return this.innerText;
    },
    querySelectorAll(selector) {
      const matches = [];
      const selectors = selector.split(',').map((item) => item.trim());
      const matchesSelector = (candidate, item) => {
        if (item.startsWith('.')) {
          return candidate.className.split(/\s+/).includes(item.slice(1));
        }
        return candidate.tagName.toLowerCase() === item.toLowerCase();
      };
      const visit = (candidate) => {
        for (const item of selectors) {
          if (matchesSelector(candidate, item)) {
            matches.push(candidate);
            break;
          }
        }
        for (const child of candidate.children) visit(child);
      };
      for (const child of children) visit(child);
      return matches;
    },
    querySelector(selector) {
      return this.querySelectorAll(selector)[0] ?? null;
    },
  };
  for (const child of children) child.parentElement = element;
  return element;
};

const makeStructuredCourse = (title, schedule, location, teacher) => {
  const icon = (name) => makeStructuredElement({
    tagName: 'span',
    className: 'glyphicon ' + name,
  });
  const field = (iconName, value, extraIconName = null) =>
    makeStructuredElement({
      tagName: 'font',
      children: [
        icon(iconName),
        ...(extraIconName ? [icon(extraIconName)] : []),
      ],
      ownText: value,
    });
  return makeStructuredElement({
    className: 'timetable_con text-left',
    children: [
      makeStructuredElement({
        tagName: 'span',
        className: 'title',
        ownText: title,
      }),
      makeStructuredElement({
        tagName: 'p',
        children: [
          field('glyphicon-calendar', schedule),
          field('glyphicon-tower', location, 'glyphicon-map-marker'),
          field('glyphicon-user', teacher),
        ],
      }),
    ],
  });
};

const runStructuredExtraction = ({
  firstSchedule = '(1-2节)1-8周,10-18周',
  secondSchedule = '(1-2节)9周',
  bodyText = '2026-2027学年第1学期结构化课表',
  tableText = '2026-2027学年第1学期结构化课表',
} = {}) => {
  const makeRow = (cells) => ({ cells, parentElement: null });
  const firstWeekday = makeStructuredElement({
    tagName: 'td',
    id: 'xq_rowspan_1',
  });
  const section = makeStructuredElement({
    tagName: 'td',
    id: 'jc_1-1-2',
    rowSpan: 2,
  });
  const rows = [
    makeRow([makeStructuredElement({ tagName: 'td' })]),
    makeRow([makeStructuredElement({ tagName: 'td' })]),
    makeRow([firstWeekday]),
    makeRow([
      section,
      makeStructuredElement({
        tagName: 'td',
        children: [
          makeStructuredCourse(
            '结构课程★',
            firstSchedule,
            '长安校区 321',
            '教师甲',
          ),
        ],
      }),
    ]),
    makeRow([
      makeStructuredElement({
        tagName: 'td',
        children: [
          makeStructuredCourse(
            '结构课程★',
            secondSchedule,
            '长安校区 321',
            '教师乙',
          ),
        ],
      }),
    ]),
  ];
  const group = { rows };
  for (const row of rows) {
    row.parentElement = group;
    for (const cell of row.cells) cell.parentElement = row;
  }
  const table = {
    id: 'kblist_table',
    rows,
    innerText: tableText,
    textContent: tableText,
    querySelectorAll: (selector) => selector === 'tr' ? rows : [],
  };
  const document = {
    body: { innerText: bodyText },
    querySelector: (selector) => selector === '#kblist_table' ? table : null,
    querySelectorAll: () => [],
  };
  const context = {
    window: {},
    location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
    document,
  };
  return JSON.parse(vm.runInNewContext(extractionScript, context));
};

const structured = runStructuredExtraction();
assert.equal(structured.courses.length, 1);
assert.equal(structured.courses[0].name, '结构课程');
assert.deepEqual(
  structured.courses[0].meetings.map((meeting) => ({
    weekday: meeting.weekday,
    startSection: meeting.startSection,
    endSection: meeting.endSection,
    weekText: meeting.weekText,
    campus: meeting.campus,
    room: meeting.room,
    teacher: meeting.teacher,
  })),
  [
    {
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weekText: '1-8周,10-18周',
      campus: '长安校区',
      room: '321',
      teacher: '教师甲',
    },
    {
      weekday: 1,
      startSection: 1,
      endSection: 2,
      weekText: '9周',
      campus: '长安校区',
      room: '321',
      teacher: '教师乙',
    },
  ],
);
assert.equal(
  structured.issues.filter((issue) => issue.severity === 'error').length,
  0,
);

const structuredWithWeekLabel = runStructuredExtraction({
  firstSchedule: '周数：1-8周,10-18周',
});
assert.deepEqual(
  structuredWithWeekLabel.courses[0].meetings[0].weekText,
  '1-8周,10-18周',
);
assert.equal(
  structuredWithWeekLabel.issues.filter((issue) => issue.severity === 'error')
    .length,
  0,
);

const structuredWithScopedSemester = runStructuredExtraction({
  bodyText: '2032-2033 学年选项 2026-2027 学期页面',
  tableText: '2026-2027学年第1学期结构化课表',
});
assert.equal(
  structuredWithScopedSemester.semester.academicYear,
  '2026-2027',
);

// Keep the generic merged-cell fallback covered for variants that do not expose
// NWU's verified #kblist_table list view.
const genericFixture = fs.readFileSync(
  path.join(
    repoRoot,
    'test',
    'fixtures',
    'zhengfang',
    'timetable_grid_fixture.html',
  ),
  'utf8',
);
assert.match(genericFixture, /rowspan="2"/);
assert.match(genericFixture, /colspan="3"/);
assert.match(genericFixture, />321<\/td>/);

const generic = runExtraction(genericFixture);
assert.equal(generic.payload.courses.length, 2);
assert.equal(
  generic.payload.issues.filter((issue) => issue.severity === 'error').length,
  0,
);

const software = generic.payload.courses.find(
  (course) => course.name === '软件测试',
);
assert.ok(software);
assert.equal(software.meetings.length, 2);
assert.equal(software.meetings[0].room, '321');
assert.equal(software.meetings[0].weekText, '1-16周');
assert.equal(software.meetings[1].weekText, '单周');
assert.ok(generic.payload.courses.every((course) =>
  !Object.hasOwn(course, 'code') &&
  !Object.hasOwn(course, 'teachingClass') &&
  !Object.hasOwn(course, 'credits') &&
  !Object.hasOwn(course, 'assessment')));

const network = generic.payload.courses.find(
  (course) => course.name === '计算机网络',
);
assert.ok(network);
assert.equal(network.meetings[0].room, '3508');
assert.equal(network.meetings[0].weekText, '2,4,6,8周');

const commaSectionFixture = genericFixture.replace(
  '<td>5-6节</td>',
  '<td>1,2,3,4节</td>',
);
const commaSection = runExtraction(commaSectionFixture);
const commaSectionCourse = commaSection.payload.courses.find(
  (course) => course.name === '计算机网络',
);
assert.ok(commaSectionCourse);
assert.equal(commaSectionCourse.meetings[0].startSection, 1);
assert.equal(commaSectionCourse.meetings[0].endSection, 4);

const sameCodeDifferentClassFixture = genericFixture.replace(
  '<td rowspan="2">软件测试</td>',
  '<td>软件测试</td>',
).replace(
  /(<tr>\s*)<td>星期二<\/td>/,
  '$1<td>软件测试</td><td>星期二</td>',
).replace(
  /(<td>星期二<\/td>[\s\S]*?<td>)软件2401(<\/td>\s*<td>CS301)/,
  '$1软件2402$2',
);
const sameCodeDifferentClass = runExtraction(sameCodeDifferentClassFixture);
const sameNameCourses = sameCodeDifferentClass.payload.courses.filter(
  (course) => course.name === '软件测试',
);
assert.equal(sameNameCourses.length, 2);

const rowSpanZeroFixture = `
<!doctype html>
<html lang="zh-CN">
  <body>
    <h1>2026-2027 第一学期</h1>
    <table>
      <thead>
        <tr>
          <th rowspan="2">课程名称</th>
          <th colspan="3">上课安排</th>
          <th rowspan="2">教师</th>
          <th rowspan="2">教室</th>
          <th rowspan="2">教学班</th>
          <th rowspan="2">课程代码</th>
        </tr>
        <tr>
          <th>星期</th>
          <th>节次</th>
          <th>周次</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td rowspan="0">跨剩余行课程</td>
          <td>星期一</td>
          <td>1-2节</td>
          <td>1-8周</td>
          <td>教师甲</td>
          <td>101</td>
          <td>教学班甲</td>
          <td>CS399</td>
        </tr>
        <tr>
          <td>星期三</td>
          <td>3-4节</td>
          <td>单周</td>
          <td>教师甲</td>
          <td>101</td>
          <td>教学班甲</td>
          <td>CS399</td>
        </tr>
      </tbody>
    </table>
  </body>
</html>`;
const rowSpanZero = runExtraction(rowSpanZeroFixture);
assert.equal(
  rowSpanZero.payload.issues.filter((issue) => issue.severity === 'error').length,
  0,
);
assert.equal(rowSpanZero.payload.courses.length, 1);
assert.equal(rowSpanZero.payload.courses[0].name, '跨剩余行课程');
assert.deepEqual(
  rowSpanZero.payload.courses[0].meetings.map((meeting) => [
    meeting.weekday,
    meeting.startSection,
    meeting.endSection,
    meeting.weekText,
  ]),
  [
    [1, 1, 2, '1-8周'],
    [3, 3, 4, '单周'],
  ],
);

const rowSpanZeroGroupFixture = `
<!doctype html>
<html lang="zh-CN">
  <body>
    <h1>2026-2027 第一学期</h1>
    <table>
      <thead>
        <tr>
          <th>课程名称</th>
          <th>星期</th>
          <th>节次</th>
          <th>周次</th>
          <th>教室</th>
        </tr>
      </thead>
      <tbody>
        <tr>
          <td rowspan="0">第一组课程</td>
          <td>星期一</td>
          <td>1-2节</td>
          <td>1-8周</td>
          <td>101</td>
        </tr>
        <tr>
          <td>星期二</td>
          <td>3-4节</td>
          <td>单周</td>
          <td>102</td>
        </tr>
      </tbody>
      <tbody>
        <tr>
          <td>第二组课程</td>
          <td>星期三</td>
          <td>5-6节</td>
          <td>2-10周</td>
          <td>201</td>
        </tr>
      </tbody>
    </table>
  </body>
</html>`;
const rowSpanZeroGroups = runExtraction(rowSpanZeroGroupFixture);
assert.equal(
  rowSpanZeroGroups.payload.issues.filter((issue) => issue.severity === 'error').length,
  0,
);
assert.deepEqual(
  rowSpanZeroGroups.payload.courses.map((course) => course.name),
  ['第一组课程', '第二组课程'],
);
assert.equal(rowSpanZeroGroups.payload.courses[0].meetings.length, 2);
assert.equal(rowSpanZeroGroups.payload.courses[1].meetings.length, 1);

const invalidWeekDocument = parseFixtureDocument(genericFixture);
const invalidWeekTable = invalidWeekDocument.tables[0];
invalidWeekTable.rows[2].cells[3].innerText = '321';
invalidWeekTable.rows[2].cells[3].textContent = '321';
const invalidWeekPayload = JSON.parse(vm.runInNewContext(extractionScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: invalidWeekDocument.document,
}));
const invalidWeekIssue = invalidWeekPayload.issues.find((issue) =>
  issue.path.endsWith('.weeks') && issue.severity === 'error');
assert.ok(invalidWeekIssue);
assert.deepEqual(invalidWeekIssue.details.parsedNumbers, [321]);
assert.equal(
  invalidWeekPayload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.weekText === '321'),
  false,
);

const invalidSectionDocument = parseFixtureDocument(genericFixture);
const invalidSectionCell = invalidSectionDocument.tables[0].rows[2].cells[2];
invalidSectionCell.innerText = '1-12节';
invalidSectionCell.textContent = '1-12节';
const invalidSectionPayload = JSON.parse(vm.runInNewContext(extractionScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: invalidSectionDocument.document,
}));
const invalidSectionIssue = invalidSectionPayload.issues.find((issue) =>
  issue.path.endsWith('.sections') && issue.severity === 'error');
assert.ok(invalidSectionIssue);
assert.equal(
  invalidSectionPayload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.endSection > 11),
  false,
);

const shiftedWeekDocument = parseFixtureDocument(genericFixture);
const shiftedWeekCell = shiftedWeekDocument.tables[0].rows[2].cells[3];
shiftedWeekCell.innerText = '1-18周 教室32';
shiftedWeekCell.textContent = '1-18周 教室32';
const shiftedWeekPayload = JSON.parse(vm.runInNewContext(extractionScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: shiftedWeekDocument.document,
}));
const shiftedWeekIssue = shiftedWeekPayload.issues.find((issue) =>
  issue.path.endsWith('.weeks') && issue.severity === 'error');
assert.ok(shiftedWeekIssue);
assert.deepEqual(shiftedWeekIssue.details.parsedNumbers, [1, 18, 32]);
assert.deepEqual(
  shiftedWeekIssue.details.unexpectedCharacterClasses,
  ['han'],
);
assert.equal(shiftedWeekIssue.details.unexpectedCharacterCount, 2);
assert.equal(JSON.stringify(shiftedWeekIssue).includes('教室'), false);
assert.equal(
  shiftedWeekPayload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.weekText.includes('教室32')),
  false,
);

const duplicateHeaderDocument = parseFixtureDocument(genericFixture);
const duplicateHeaderCell = duplicateHeaderDocument.tables[0].rows[1].cells[0];
duplicateHeaderCell.innerText = '星期周次';
duplicateHeaderCell.textContent = '星期周次';
const duplicateWeekHeaderCell = duplicateHeaderDocument.tables[0].rows[1].cells[2];
duplicateWeekHeaderCell.innerText = '安排';
duplicateWeekHeaderCell.textContent = '安排';
const duplicateHeaderPayload = JSON.parse(vm.runInNewContext(extractionScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: duplicateHeaderDocument.document,
}));
const duplicateHeaderIssue = duplicateHeaderPayload.issues.find((issue) =>
  issue.path.endsWith('.header') && issue.severity === 'error');
assert.ok(duplicateHeaderIssue);
assert.deepEqual(
  duplicateHeaderIssue.details.duplicateColumns,
  ['weekday', 'weeks'],
);
assert.equal(duplicateHeaderPayload.courses.length, 0);

// Real NWU DOM shape captured from the authenticated student timetable page,
// with personal data replaced by synthetic values.
const realListFixture = fs.readFileSync(
  path.join(
    repoRoot,
    'test',
    'fixtures',
    'zhengfang',
    'nwu_kblist_fixture.html',
  ),
  'utf8',
);
assert.match(realListFixture, /id="kblist_table"/);
assert.match(realListFixture, /id="xq_rowspan_1"/);
assert.match(realListFixture, /id="jc_1-1-2"/);
assert.match(realListFixture, /计算机技术实验室-321/);

const sameShapeTeachingClassesFixture = `
<html><body>
  <div>2026-2027年第1学期某同学的课表</div>
  <table id="kblist_table">
    <tr><td>星期</td><td>节次</td><td>课表信息</td></tr>
    <tr><td id="xq_rowspan_1">星期一</td></tr>
    <tr>
      <td id="jc_1-1-2">1-2</td>
      <td>同名课程★周数：1-16周校区:长安校区上课地点：321教师：教师甲教学班：同名课程-A教学班组成：软件工程202401</td>
    </tr>
    <tr>
      <td id="jc_1-1-2">1-2</td>
      <td>同名课程★周数：1-16周校区:长安校区上课地点：322教师：教师乙教学班：同名课程-B教学班组成：软件工程202401</td>
    </tr>
  </table>
</body></html>`;
const sameShapeTeachingClasses = runExtraction(sameShapeTeachingClassesFixture);
assert.equal(sameShapeTeachingClasses.payload.issues.length, 0);
assert.equal(sameShapeTeachingClasses.payload.courses.length, 2);
assert.deepEqual(
  sameShapeTeachingClasses.payload.courses.map((course) => course.name),
  ['同名课程', '同名课程'],
);
assert.deepEqual(
  sameShapeTeachingClasses.payload.courses
    .map((course) => course.meetings[0].room),
  ['321', '322'],
);
assert.equal(
  JSON.stringify(sameShapeTeachingClasses.payload).includes('教学班-A'),
  false,
);

const sameTeachingClassDifferentMeetingsFixture = `
<html><body>
  <div>2026-2027年第1学期某同学的课表</div>
  <table id="kblist_table">
    <tr><td>星期</td><td>节次</td><td>课表信息</td></tr>
    <tr><td id="xq_rowspan_1">星期一</td></tr>
    <tr>
      <td id="jc_1-1-2" rowspan="2">1-2</td>
      <td>组合课程★周数：1-16周校区:长安校区上课地点：101教师：教师甲教学班：组合课程-A教学班组成：软件工程202401</td>
    </tr>
    <tr>
      <td>组合课程★周数：10-16周校区:长安校区上课地点：102教师：教师甲教学班：组合课程-A教学班组成：软件工程202401</td>
    </tr>
  </table>
</body></html>`;
const sameTeachingClassDifferentMeetings = runExtraction(
  sameTeachingClassDifferentMeetingsFixture,
);
assert.equal(
  sameTeachingClassDifferentMeetings.payload.issues.length,
  0,
);
assert.equal(sameTeachingClassDifferentMeetings.payload.courses.length, 1);
assert.equal(
  sameTeachingClassDifferentMeetings.payload.courses[0].meetings.length,
  2,
);
assert.deepEqual(
  sameTeachingClassDifferentMeetings.payload.courses[0].meetings.map(
    (meeting) => [
      meeting.startSection,
      meeting.endSection,
      meeting.room,
      meeting.weekText,
    ],
  ),
  [[1, 2, '101', '1-16周'], [1, 2, '102', '10-16周']],
);

const realList = runExtraction(realListFixture);
assert.equal(realList.payload.totalWeeks, 18);
assert.equal(realList.payload.courses.length, 6);
assert.equal(
  realList.payload.issues.filter((issue) => issue.severity === 'error').length,
  0,
);

// Zhengfang currently patches Array.prototype callbacks on the live page.
// The extractor must still parse the verified list table in that environment.
const realListWithLegacyArrayCallbacks = runExtraction(realListFixture, {
  legacyArrayCallbacks: true,
});
assert.equal(realListWithLegacyArrayCallbacks.payload.totalWeeks, 18);
assert.equal(realListWithLegacyArrayCallbacks.payload.courses.length, 6);
assert.equal(
  realListWithLegacyArrayCallbacks.payload.courses
    .flatMap((course) => course.meetings).length,
  realList.payload.courses.flatMap((course) => course.meetings).length,
);
assert.equal(
  realListWithLegacyArrayCallbacks.payload.issues
    .filter((issue) => issue.severity === 'error').length,
  0,
);

const obsoleteIdentityChanged = runExtraction(
  realListFixture.replace(/数据结构实验-0003/g, '数据结构实验-9999'),
);
assert.deepEqual(
  realList.payload.courses.map((course) => course.sourceCourseKey).sort(),
  obsoleteIdentityChanged.payload.courses
    .map((course) => course.sourceCourseKey)
    .sort(),
);

// DOM row positions are parser-local grouping aids, not remote identity. A
// newly inserted course row must not rotate the keys of existing courses or
// their meeting exceptions on the next import.
const insertedListRowFixture = realListFixture
  .replace(
    'id="xq_rowspan_1" rowspan="5"',
    'id="xq_rowspan_1" rowspan="6"',
  )
  .replace(
    '        <tr>\n          <td id="jc_1-1-2" rowspan="2">',
    `        <tr>
          <td id="jc_1-11-11">11</td>
          <td>前置课程★周数：1-18周校区:长安校区上课地点：101教师：教师前教学班：前置课程-0001教学班组成：软件工程202401</td>
        </tr>
        <tr>
          <td id="jc_1-1-2" rowspan="2">`,
  );
const insertedListRow = runExtraction(insertedListRowFixture);
assert.equal(
  insertedListRow.payload.issues.filter((issue) => issue.severity === 'error')
    .length,
  0,
);
const courseIdentity = (payload, name) => payload.courses
  .filter((course) => course.name === name)
  .map((course) => ({
    sourceCourseKey: course.sourceCourseKey,
    sourceMeetingKeys: course.meetings
      .map((meeting) => meeting.sourceMeetingKey)
      .sort(),
  }))
  .sort((left, right) =>
    left.sourceCourseKey.localeCompare(right.sourceCourseKey));
for (const course of realList.payload.courses) {
  assert.deepEqual(
    courseIdentity(insertedListRow.payload, course.name),
    courseIdentity(realList.payload, course.name),
  );
}

const insertedGenericRowFixture = genericFixture.replace(
  '        <tr>\n          <td>计算机网络</td>',
  `        <tr>
          <td>前置课程</td>
          <td>星期五</td>
          <td>7-8节</td>
          <td>1-18周</td>
          <td>教师前</td>
          <td>101</td>
          <td>教学班前</td>
          <td>CS399</td>
        </tr>
        <tr>
          <td>计算机网络</td>`,
);
const insertedGenericRow = runExtraction(insertedGenericRowFixture);
assert.equal(
  insertedGenericRow.payload.issues.filter((issue) => issue.severity === 'error')
    .length,
  0,
);
for (const course of generic.payload.courses) {
  assert.deepEqual(
    courseIdentity(insertedGenericRow.payload, course.name),
    courseIdentity(generic.payload, course.name),
  );
}

const experiment = realList.payload.courses.find(
  (course) => course.name === '数据结构实验',
);
assert.ok(experiment);
assert.equal(experiment.meetings.length, 2);
assert.deepEqual(
  experiment.meetings.map((meeting) => meeting.weekText),
  ['1-9周', '10-18周'],
);
assert.ok(
  experiment.meetings.every(
    (meeting) =>
      meeting.weekday === 1 &&
      meeting.startSection === 1 &&
      meeting.endSection === 2 &&
      meeting.room === '计算机技术实验室-321',
  ),
);

const realSoftware = realList.payload.courses.find(
  (course) => course.name === '软件测试（双语）',
);
assert.ok(realSoftware);
assert.equal(realSoftware.meetings.length, 1);
assert.deepEqual(
  realSoftware.meetings.map((meeting) => [
    meeting.weekday,
    meeting.startSection,
    meeting.endSection,
    meeting.weekText,
    meeting.room,
  ]),
  [
    [1, 3, 4, '1-18周', '3406'],
  ],
);

const realSoftwareSecondClass = realList.payload.courses.find(
  (course) => course.name === '软件测试（双语）' &&
    course.meetings[0]?.room === '计算机技术实验室-321',
);
assert.ok(realSoftwareSecondClass);
assert.equal(realSoftwareSecondClass.meetings.length, 1);

const mining = realList.payload.courses.find(
  (course) => course.name === 'Web数据挖掘（双语）',
);
assert.ok(mining);
assert.equal(mining.meetings[0].weekday, 2);
assert.equal(mining.meetings[0].weekText, '1-8周,10-18周');

const project = realList.payload.courses.find(
  (course) => course.name === 'IT项目管理（双语)(含上机）',
);
assert.ok(project);
assert.equal(project.meetings[0].weekText, '1-17周(单)');

const ml = realList.payload.courses.find(
  (course) => course.name === '机器学习',
);
assert.ok(ml);
assert.equal(ml.meetings[0].weekday, 4);
assert.equal(ml.meetings[0].startSection, 5);
assert.equal(ml.meetings[0].endSection, 8);
assert.equal(ml.meetings[0].weekText, '2-18周(双)');

assert.equal(
  realList.payload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => /\b321\b/.test(meeting.weekText)),
  false,
);
assert.ok(realList.payload.courses.every((course) =>
  !Object.hasOwn(course, 'code') &&
  !Object.hasOwn(course, 'teachingClass') &&
  !Object.hasOwn(course, 'credits') &&
  !Object.hasOwn(course, 'assessment')),
);

const missingWeekLabelFixture = realListFixture.replace(
  '数据结构实验☆周数：1-9周',
  '数据结构实验☆1-9周',
);
const missingWeekLabel = runExtraction(missingWeekLabelFixture);
const missingWeekIssue = missingWeekLabel.payload.issues.find((issue) =>
  issue.path.endsWith('.weeks') && issue.severity === 'error');
assert.ok(missingWeekIssue);
assert.equal(
  missingWeekLabel.payload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.weekText === '1-9周'),
  false,
);

const brokenSectionIdFixture = realListFixture.replace(
  'id="jc_1-1-2"',
  'id="broken-section-id"',
);
const brokenSectionId = runExtraction(brokenSectionIdFixture);
const brokenSectionIssue = brokenSectionId.payload.issues.find((issue) =>
  issue.path.endsWith('.sections') && issue.severity === 'error');
assert.ok(brokenSectionIssue);
assert.equal(
  brokenSectionId.payload.courses
    .some((course) => course.name === '数据结构实验'),
  false,
);

const missingSectionContextFixture = realListFixture.replace(
  '<td id="jc_1-3-4">3-4</td>',
  '<td>3-4</td>',
);
const missingSectionContext = runExtraction(missingSectionContextFixture);
const missingSectionIssue = missingSectionContext.payload.issues.find((issue) =>
  issue.path.endsWith('.sections') && issue.severity === 'error');
assert.ok(missingSectionIssue);
assert.equal(
  missingSectionContext.payload.courses
    .filter((course) => course.name === '软件测试（双语）')
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.startSection === 3),
  false,
);

const prefixed = runExtraction(
  realListFixture.replace('机器学习★', '【调】机器学习★'),
);
assert.ok(prefixed.payload.courses.some((course) => course.name === '机器学习'));
assert.equal(
  prefixed.payload.courses.some((course) => course.name.startsWith('【调】')),
  false,
);

const detectedContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: realList.fixtureDocument.document,
});
assert.equal(detectedContext, 'timetable');

// Zhengfang may keep a hidden login form in the authenticated page DOM. It
// must not disable the timetable bridge while the concrete list table exists.
const hiddenLoginControl = {
  hidden: true,
  getAttribute: () => null,
  getClientRects: () => [],
};
const hiddenLoginDocument = {
  body: realList.fixtureDocument.document.body,
  querySelector(selector) {
    if (selector === '#kblist_table') {
      return realList.fixtureDocument.document.querySelector(selector);
    }
    return selector.includes('input') || selector === '#yhm' || selector === '#mm'
      ? hiddenLoginControl
      : null;
  },
  querySelectorAll(selector) {
    return selector.includes('input') || selector.includes('#yhm') ||
      selector.includes('#mm')
      ? [hiddenLoginControl]
      : [];
  },
};
const hiddenLoginContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: hiddenLoginDocument,
});
assert.equal(hiddenLoginContext, 'timetable');

const visibleLoginControl = {
  hidden: false,
  getAttribute: () => null,
  getClientRects: () => [{}],
};
const timetableWithVisibleLoginDocument = {
  body: realList.fixtureDocument.document.body,
  querySelector(selector) {
    if (selector === '#kblist_table') {
      return realList.fixtureDocument.document.querySelector(selector);
    }
    return selector.includes('input') || selector === '#yhm' || selector === '#mm'
      ? visibleLoginControl
      : null;
  },
  querySelectorAll(selector) {
    return selector.includes('input') || selector.includes('#yhm') ||
      selector.includes('#mm')
      ? [visibleLoginControl]
      : [];
  },
};
const visibleLoginWithTableContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: timetableWithVisibleLoginDocument,
});
assert.equal(visibleLoginWithTableContext, 'login');

let listViewVisible = false;
const ajaxViewDocument = {
  body: { innerText: '2026-2027 第1学期 个人课表查询' },
  querySelector(selector) {
    if (selector === '#kblist_table') return listViewVisible ? {} : null;
    if (selector === '#kbgrid_table_0') return {};
    return null;
  },
  querySelectorAll(selector) {
    if (selector.includes('password') ||
        selector.includes('#yhm') ||
        selector.includes('#mm')) {
      return [];
    }
    if (!selector.includes('button') &&
        !selector.includes('input[type="button"]') &&
        !selector.includes('input[type="submit"]') &&
        !selector.includes('a')) {
      return [];
    }
    return [{
      innerText: '列表',
      textContent: '列表',
      value: '',
      click() {
        listViewVisible = true;
      },
    }];
  },
};
const gridContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: ajaxViewDocument,
});
assert.equal(gridContext, 'timetable');
const prepareState = vm.runInNewContext(prepareListViewScript, {
  window: {},
  document: ajaxViewDocument,
});
assert.equal(prepareState, 'switching');
const readyState = vm.runInNewContext(listViewReadyScript, {
  window: {},
  document: ajaxViewDocument,
});
assert.equal(readyState, 'ready');

const payloadPrepareState = vm.runInNewContext(prepareListViewScript, {
  window: { __NWU_SCHEDULE_PAYLOAD__: { courses: [] } },
  document: {
    querySelector: () => null,
    querySelectorAll: () => [],
  },
});
assert.equal(payloadPrepareState, 'ready');

const loginPageContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/xtgl/login_slogin.html' },
  document: {
    body: { innerText: '用户登录 密码' },
    querySelector: () => null,
    querySelectorAll: () => [],
  },
});
assert.equal(loginPageContext, 'login');

const pathOnlyContext = vm.runInNewContext(contextScript, {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: {
    body: { innerText: '课程 星期 节次 周次 教室' },
    querySelector: () => null,
  },
});
assert.equal(pathOnlyContext, 'other');

const payloadContext = vm.runInNewContext(contextScript, {
  window: { __NWU_SCHEDULE_PAYLOAD__: { courses: [] } },
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: {
    body: { innerText: '' },
    querySelector: () => null,
  },
});
assert.equal(payloadContext, 'timetable');

console.log('NWU DOM fixtures passed');
