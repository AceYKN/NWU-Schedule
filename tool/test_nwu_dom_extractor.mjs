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
const marker = `static const extractionScript = r${quote}`;
const scriptStart = dartSource.indexOf(marker);
assert.notEqual(scriptStart, -1, 'extraction script marker is present');
const scriptBodyStart = scriptStart + marker.length;
const scriptEnd = dartSource.indexOf(`${quote};`, scriptBodyStart);
assert.notEqual(scriptEnd, -1, 'extraction script terminator is present');
const extractionScript = dartSource.slice(scriptBodyStart, scriptEnd);
new vm.Script(extractionScript);
const contextMarker = `static const contextScript = r${quote}`;
const contextStart = dartSource.indexOf(contextMarker);
assert.notEqual(contextStart, -1, 'context script marker is present');
const contextBodyStart = contextStart + contextMarker.length;
const contextEnd = dartSource.indexOf(`${quote};`, contextBodyStart);
assert.notEqual(contextEnd, -1, 'context script terminator is present');
new vm.Script(dartSource.slice(contextBodyStart, contextEnd));

const fixture = fs.readFileSync(
  path.join(repoRoot, 'test', 'fixtures', 'zhengfang', 'timetable_grid_fixture.html'),
  'utf8',
);
assert.match(fixture, /rowspan="2"/);
assert.match(fixture, /colspan="3"/);
assert.match(fixture, />321<\/td>/);

const decodeText = (value) => value
  .replace(/<[^>]+>/g, '')
  .replace(/&nbsp;/g, ' ')
  .replace(/&amp;/g, '&')
  .trim();
const parseFixtureTable = (html) => {
  const tableHtml = html.match(/<table\b[^>]*>([\s\S]*?)<\/table>/i)?.[1];
  assert.ok(tableHtml, 'fixture contains a table');
  const rows = [...tableHtml.matchAll(/<tr\b[^>]*>([\s\S]*?)<\/tr>/gi)].map((rowMatch) => ({
    cells: [...rowMatch[1].matchAll(/<(td|th)\b([^>]*)>([\s\S]*?)<\/\1>/gi)].map((cellMatch) => ({
      innerText: decodeText(cellMatch[3]),
      rowSpan: Number(cellMatch[2].match(/rowspan="(\d+)"/i)?.[1] || 1),
      colSpan: Number(cellMatch[2].match(/colspan="(\d+)"/i)?.[1] || 1),
    })),
  }));
  return { rows };
};

const table = parseFixtureTable(fixture);
const context = {
  window: {},
  location: { pathname: '/jwglxt/kbcx/xskbcx_cxXskbcxIndex.html' },
  document: {
    body: { innerText: fixture.replace(/<[^>]+>/g, ' ') },
    querySelectorAll: () => [table],
  },
};
const payload = JSON.parse(vm.runInNewContext(extractionScript, context));
assert.equal(payload.courses.length, 2);
assert.equal(payload.issues.filter((issue) => issue.severity === 'error').length, 0);

const software = payload.courses.find((course) => course.code === 'CS301');
assert.ok(software);
assert.equal(software.meetings.length, 2);
assert.equal(software.meetings[0].room, '321');
assert.equal(software.meetings[0].weekText, '1-16周');
assert.equal(software.meetings[1].weekText, '单周');

const network = payload.courses.find((course) => course.code === 'CS302');
assert.ok(network);
assert.equal(network.meetings[0].room, '3508');
assert.equal(network.meetings[0].weekText, '2,4,6,8周');

const invalidWeekTable = parseFixtureTable(fixture);
invalidWeekTable.rows[2].cells[3].innerText = '321';
const invalidWeekPayload = JSON.parse(vm.runInNewContext(extractionScript, {
  ...context,
  document: {
    ...context.document,
    querySelectorAll: () => [invalidWeekTable],
  },
}));
const invalidWeekIssue = invalidWeekPayload.issues.find((issue) =>
  issue.path.endsWith('.weeks') && issue.severity === 'error');
assert.ok(invalidWeekIssue);
assert.deepEqual(invalidWeekIssue.details.parsedNumbers, [321]);
assert.equal(invalidWeekPayload.totalWeeks, 20);
assert.equal(
  invalidWeekPayload.courses
    .flatMap((course) => course.meetings)
    .some((meeting) => meeting.weekText === '321'),
  false,
);
console.log('NWU DOM merged-cell fixture passed');
