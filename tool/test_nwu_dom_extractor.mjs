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
const contextScript = extractDartRawString('contextScript');
new vm.Script(extractionScript);
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

const runExtraction = (html) => {
  const fixtureDocument = parseFixtureDocument(html);
  const context = {
    window: {},
    location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
    document: fixtureDocument.document,
  };
  return {
    payload: JSON.parse(vm.runInNewContext(extractionScript, context)),
    context,
    fixtureDocument,
  };
};

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
assert.equal(software.code, 'CS301');
assert.equal(software.teachingClass, '软件2401');
assert.equal(software.credits, null);
assert.equal(software.assessment, null);
assert.equal(software.meetings.length, 2);
assert.equal(software.meetings[0].room, '321');
assert.equal(software.meetings[0].weekText, '1-16周');
assert.equal(software.meetings[1].weekText, '单周');

const network = generic.payload.courses.find(
  (course) => course.name === '计算机网络',
);
assert.ok(network);
assert.equal(network.meetings[0].room, '3508');
assert.equal(network.meetings[0].weekText, '2,4,6,8周');

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
assert.deepEqual(shiftedWeekIssue.details.unexpectedCharacters, ['教', '室']);
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

const realList = runExtraction(realListFixture);
assert.equal(realList.payload.totalWeeks, 18);
assert.equal(realList.payload.courses.length, 6);
assert.equal(
  realList.payload.issues.filter((issue) => issue.severity === 'error').length,
  0,
);

const experiment = realList.payload.courses.find(
  (course) => course.name === '数据结构实验',
);
assert.ok(experiment);
assert.equal(experiment.code, 'CS201');
assert.equal(experiment.teachingClass, '数据结构实验-0003');
assert.equal(experiment.credits, 1);
assert.equal(experiment.assessment, '考查');
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
assert.equal(realSoftware.code, null);
assert.equal(realSoftware.teachingClass, '软件测试（双语）-0002');
assert.equal(realSoftware.credits, 2.5);
assert.equal(realSoftware.assessment, '考试');
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
assert.equal(realSoftwareSecondClass.code, null);
assert.equal(
  realSoftwareSecondClass.teachingClass,
  '软件测试（双语）-0002A',
);
assert.equal(realSoftwareSecondClass.credits, 2.5);
assert.equal(realSoftwareSecondClass.assessment, '未安排');

const mining = realList.payload.courses.find(
  (course) => course.name === 'Web数据挖掘（双语）',
);
assert.ok(mining);
assert.equal(mining.code, null);
assert.equal(mining.teachingClass, 'Web数据挖掘（双语）-0001');
assert.equal(mining.credits, 3);
assert.equal(mining.meetings[0].weekday, 2);
assert.equal(mining.meetings[0].weekText, '1-8周,10-18周');

const project = realList.payload.courses.find(
  (course) => course.name === 'IT项目管理（双语)(含上机）',
);
assert.ok(project);
assert.equal(project.code, null);
assert.equal(project.teachingClass, 'IT项目管理-0002');
assert.equal(project.credits, 3.5);
assert.equal(project.meetings[0].weekText, '1-17周(单)');

const ml = realList.payload.courses.find(
  (course) => course.name === '机器学习',
);
assert.ok(ml);
assert.equal(ml.code, null);
assert.equal(ml.teachingClass, '机器学习-0001');
assert.equal(ml.credits, 3);
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
assert.equal(
  realList.payload.courses.filter((course) => course.code != null).length,
  1,
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

console.log('NWU DOM fixtures passed');
