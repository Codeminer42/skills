#!/usr/bin/env node
// Checks this repository's Architecture Decision Records: each record's name,
// heading, sections and status, the index in its folder's README, the relative
// links in every file agents read, and every place code or docs cite a record.
// Installed by the adr-setup skill. adr.sh is the same check in bash; keep the
// two in step.
//
//   node scripts/adr.mjs                  check
//   node scripts/adr.mjs --base <commit>  also check merged records against <commit>
//   node scripts/adr.mjs --fix            regenerate the indexes, then check
//   node scripts/adr.mjs new "<title>"    create a record from the template
import { execFileSync } from 'node:child_process';
import {
  existsSync,
  readFileSync,
  readdirSync,
  statSync,
  writeFileSync,
} from 'node:fs';
import { dirname, join, posix, relative, resolve, sep } from 'node:path';
import { fileURLToPath } from 'node:url';

// Folders that hold records, relative to the repository root.
const ADR_DIRS = ['docs/adr'];

// Files agents read as instructions. Every relative link in them must resolve.
const GUIDE =
  /(^|\/)(AGENTS|CLAUDE|GEMINI)\.md$|^(README|CONTRIBUTING)\.md$|^\.github\/copilot-instructions\.md$|^\.cursor\/rules\/|^\.claude\/.+\.md$/;

const STATUSES = ['Proposed', 'Accepted', 'Rejected', 'Deprecated'];
// The statuses a merged record may move to, from each status.
const NEXT_STATUSES = {
  Proposed: ['Proposed', 'Accepted', 'Rejected'],
  Accepted: ['Accepted', 'Deprecated', 'Superseded'],
  Deprecated: ['Deprecated', 'Superseded'],
  Rejected: ['Rejected'],
  Superseded: ['Superseded'],
};
const SECTIONS = ['Status', 'Context', 'Decision', 'Consequences'];
const WORD_LIMIT = 800;
const INDEX_HEADING = '## Index';

const RECORD_FILE =
  /^\d{4}(\d{2})(\d{2})(\d{2})(\d{2})-[a-z0-9]+(-[a-z0-9]+)*\.md$/;
const NOT_RECORDS = new Set(['README.md', 'template.md']);
const STEM =
  /(?<![A-Za-z0-9_-])\d{12}-[a-z0-9]+(-[a-z0-9]+)*(?![A-Za-z0-9_-])/g;
const NUMBERED_MENTION = /(?<![A-Za-z0-9_])ADR[- #]?\d{1,4}(?![A-Za-z0-9_])/g;
const SUPERSEDED = /^Superseded by \[[^\]]+\]\((\.\/)?([^) \t]+)\)$/;
const ADR_FOLDER_NAMES = new Set(['adr', 'adrs', 'decisions']);
const SKIPPED_DIRECTORY =
  /(^|\/)(node_modules|vendor|\.git|dist|build|coverage|target|\.venv|venv|__pycache__|\.next|\.turbo)\//;
const SKIPPED_FILE =
  /(^|\/)(package-lock\.json|npm-shrinkwrap\.json|pnpm-lock\.yaml|yarn\.lock|bun\.lockb?|Gemfile\.lock|Cargo\.lock|poetry\.lock|uv\.lock|composer\.lock|go\.sum|mix\.lock|Podfile\.lock)$/;
const CITATION_CANDIDATE = /\d{12}-[a-z0-9]|ADR[- #]?\d/;
const LARGEST_SCANNED_FILE = 1024 * 1024;

const here = dirname(fileURLToPath(import.meta.url));
const root = repositoryRoot();
const script = toPosix(relative(root, fileURLToPath(import.meta.url)));
const fixHint = `; run node ${script} --fix`;

function toPosix(path) {
  return path.split(sep).join(posix.sep);
}

function repositoryRoot() {
  try {
    return execFileSync('git', ['-C', here, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return resolve(here, '..');
  }
}

const read = (path) =>
  readFileSync(join(root, path), 'utf8').replace(/\r\n/g, '\n');

const trim = (text) => text.replace(/^[ \t]+|[ \t]+$/g, '');

const stemOf = (file) => file.replace(/\.md$/, '');

function validRecordName(file) {
  const name = RECORD_FILE.exec(file);
  if (!name) return false;
  const [month, day, hour, minute] = name.slice(1, 5).map(Number);
  return (
    month >= 1 &&
    month <= 12 &&
    day >= 1 &&
    day <= 31 &&
    hour <= 23 &&
    minute <= 59
  );
}

// Drops HTML comments, line by line, so a comment that spans lines goes too.
function uncommented(lines) {
  let comment = false;
  return lines.map((line) => {
    let text = line;
    if (comment) {
      const close = text.indexOf('-->');
      if (close === -1) return '';
      text = text.slice(close + 3);
      comment = false;
    }
    let open;
    while ((open = text.indexOf('<!--')) !== -1) {
      const close = text.indexOf('-->', open + 4);
      if (close === -1) {
        text = text.slice(0, open);
        comment = true;
        break;
      }
      text = text.slice(0, open) + text.slice(close + 3);
    }
    return text;
  });
}

// Drops what markdown doesn't render as prose: comments, fenced and inline code.
function proseLines(lines) {
  let comment = false;
  let fence = false;
  return lines.map((line) => {
    let text = line;
    if (comment) {
      const close = text.indexOf('-->');
      if (close === -1) return '';
      text = text.slice(close + 3);
      comment = false;
    } else if (/^[ \t]*(```|~~~)/.test(text)) {
      fence = !fence;
      return '';
    }
    if (fence) return '';
    let open;
    while ((open = text.indexOf('<!--')) !== -1) {
      const close = text.indexOf('-->', open + 4);
      if (close === -1) {
        text = text.slice(0, open);
        comment = true;
        break;
      }
      text = text.slice(0, open) + text.slice(close + 3);
    }
    return text.replace(/`[^`]*`/g, '');
  });
}

// Reads the title, the section names, and the status from the first Status
// section, comments dropped and whitespace folded into single spaces.
function parseRecord(raw) {
  const lines = raw.split('\n');
  const heading = lines.find((line) => /^# ./.test(line));
  const sections = new Set();
  const statusLines = [];
  let inStatus = false;
  for (const line of lines) {
    if (line.startsWith('## ')) {
      const section = trim(line.slice(3));
      inStatus = section === 'Status' && !sections.has('Status');
      sections.add(section);
    } else if (inStatus) {
      statusLines.push(line);
    }
  }
  const statusText = sections.has('Status')
    ? trim(
        uncommented(statusLines)
          .join(' ')
          .replace(/[ \t]+/g, ' '),
      )
    : undefined;
  const superseded = statusText && SUPERSEDED.exec(statusText);
  return {
    title: heading ? trim(heading.slice(2)) : '',
    sections,
    statusText,
    status: superseded
      ? 'Superseded'
      : STATUSES.includes(statusText)
        ? statusText
        : undefined,
    supersededBy: superseded?.[2],
  };
}

// The record without its Status section: the part that never changes.
function withoutStatus(raw) {
  let status = false;
  const lines = raw.split('\n').filter((line) => {
    if (line.startsWith('## ')) status = trim(line.slice(3)) === 'Status';
    return !status;
  });
  while (lines.length && lines.at(-1) === '') lines.pop();
  return lines.join('\n');
}

const wordCount = (raw) =>
  uncommented(withoutStatus(raw).split('\n'))
    .join('\n')
    .split(/\s+/)
    .filter(Boolean).length;

function readRecords(dirs, violations) {
  const records = [];
  for (const dir of dirs) {
    if (!existsSync(join(root, dir))) {
      violations.push(`${dir}: is in ADR_DIRS but does not exist`);
      continue;
    }
    const files = readdirSync(join(root, dir), { withFileTypes: true })
      .filter((entry) => entry.isFile() && entry.name.endsWith('.md'))
      .map((entry) => entry.name)
      .filter((file) => !NOT_RECORDS.has(file))
      .sort();
    for (const file of files) {
      const path = posix.join(dir, file);
      if (!validRecordName(file)) {
        violations.push(
          `${path}: a record is named YYYYMMDDHHMM-<decision-slug>.md`,
        );
        continue;
      }
      const raw = read(path);
      records.push({
        dir,
        file,
        path,
        stem: stemOf(file),
        date: `${file.slice(0, 4)}-${file.slice(4, 6)}-${file.slice(6, 8)}`,
        raw,
        ...parseRecord(raw),
      });
    }
    if (!records.some((record) => record.dir === dir)) {
      violations.push(
        `${dir}: holds no records; the check would pass on nothing`,
      );
    }
  }
  return records;
}

const supersederOf = (record, records) =>
  records.find(
    (other) => other.dir === record.dir && other.file === record.supersededBy,
  );

function checkRecords(records, violations) {
  for (const record of records) {
    const { path } = record;
    if (!record.title) {
      violations.push(`${path}: has no "# <decision title>" heading`);
    } else if (record.title.includes('{{')) {
      violations.push(
        `${path}: the heading is still the template's placeholder`,
      );
    }
    for (const section of SECTIONS) {
      if (!record.sections.has(section)) {
        violations.push(`${path}: has no "## ${section}" section`);
      }
    }
    if (record.statusText === '') {
      violations.push(`${path}: the Status section is empty`);
    } else if (record.statusText !== undefined && !record.status) {
      violations.push(
        `${path}: status "${record.statusText}" is not Proposed, Accepted, Rejected, Deprecated, or Superseded by [title](./file.md)`,
      );
    }
    if (record.status !== 'Superseded') continue;
    const target = supersederOf(record, records);
    if (!target) {
      violations.push(
        `${path}: superseded by ${record.supersededBy}, which is not a record in this folder`,
      );
    } else if (target === record) {
      violations.push(`${path}: superseded by itself`);
    } else if (target.file.slice(0, 12) < record.file.slice(0, 12)) {
      violations.push(`${path}: superseded by ${target.file}, which is older`);
    } else if (target.status === 'Proposed' || target.status === 'Rejected') {
      violations.push(
        `${path}: superseded by ${target.file}, which is ${target.status.toLowerCase()}; only a decision in effect replaces one`,
      );
    }
  }
}

const escapeCell = (text) => text.replace(/\|/g, '\\|');

function statusCell(record, records) {
  if (record.status !== 'Superseded') return record.statusText ?? '';
  const target = supersederOf(record, records);
  return `Superseded by [${target?.title || stemOf(record.supersededBy)}](./${record.supersededBy})`;
}

function indexRows(dir, records) {
  return records
    .filter((record) => record.dir === dir)
    .map((record) => [
      record.date,
      `[${escapeCell(record.title || record.stem)}](./${record.file})`,
      escapeCell(statusCell(record, records)),
    ]);
}

function renderIndex(rows) {
  return [
    '| Date | Decision | Status |',
    '| --- | --- | --- |',
    ...rows.map((cells) => `| ${cells.join(' | ')} |`),
  ];
}

// Where the index table sits in a README, by line number.
function indexTable(lines) {
  const heading = lines.findIndex((line) => trim(line) === INDEX_HEADING);
  if (heading === -1) return { heading };
  let end = lines.findIndex(
    (line, at) => at > heading && /^#{1,2} /.test(line),
  );
  if (end === -1) end = lines.length;
  let start = heading + 1;
  while (start < end && !lines[start].trimStart().startsWith('|')) start += 1;
  if (start === end) return { heading, end };
  let stop = start;
  while (stop < end && lines[stop].trimStart().startsWith('|')) stop += 1;
  return { heading, end, start, stop };
}

function splitRow(line) {
  return trim(line)
    .replace(/^\|/, '')
    .replace(/\|$/, '')
    .replace(/\\\|/g, '\u0001')
    .split('|')
    .map((cell) =>
      trim(cell.replace(/[ \t]+/g, ' ')).replace(/\u0001/g, '\\|'),
    );
}

const linkedFile = (cells) =>
  /\]\((\.\/)?([^) \t]+)\)/.exec(cells[1] ?? '')?.[2];

function checkIndex(dir, records, violations) {
  const path = posix.join(dir, 'README.md');
  if (!existsSync(join(root, path))) {
    violations.push(`${path}: is missing; it holds the index`);
    return;
  }
  const lines = read(path).split('\n');
  const table = indexTable(lines);
  if (table.heading === -1) {
    violations.push(`${path}: has no "${INDEX_HEADING}" section${fixHint}`);
    return;
  }
  if (table.start === undefined) {
    violations.push(`${path}: the Index section has no table${fixHint}`);
    return;
  }
  const actual = lines
    .slice(table.start + 1, table.stop)
    .map(splitRow)
    .filter((cells) => !cells.every((cell) => /^:?-+:?$/.test(cell)));
  const expected = indexRows(dir, records);
  const text = (cells) => cells.join(' | ');
  if (
    actual.length === expected.length &&
    actual.every((cells, at) => text(cells) === text(expected[at]))
  )
    return;

  const problems = [];
  const rowFor = new Map(actual.map((cells) => [linkedFile(cells), cells]));
  for (const cells of expected) {
    const file = linkedFile(cells);
    const row = rowFor.get(file);
    if (!row) {
      problems.push(`the index has no row for ${file}`);
    } else if (text(row) !== text(cells)) {
      problems.push(
        `the index row for ${file} reads "${text(row)}", the record says "${text(cells)}"`,
      );
    }
  }
  const files = new Set(expected.map(linkedFile));
  for (const cells of actual) {
    const file = linkedFile(cells);
    if (!files.has(file)) {
      problems.push(
        `the index lists ${file ?? text(cells)}, which is not a record`,
      );
    }
  }
  if (!problems.length)
    problems.push('the index rows are out of order, oldest first');
  for (const problem of problems) {
    violations.push(`${path}: ${problem}${fixHint}`);
  }
}

function walkFiles(directory, found = []) {
  for (const entry of readdirSync(join(root, directory), {
    withFileTypes: true,
  })) {
    const path = directory ? posix.join(directory, entry.name) : entry.name;
    if (entry.isDirectory()) walkFiles(path, found);
    else if (entry.isFile()) found.push(path);
  }
  return found;
}

// Tracked and untracked-but-not-ignored files, or every file outside git.
function repositoryFiles() {
  let paths;
  try {
    paths = execFileSync(
      'git',
      [
        '-C',
        root,
        'ls-files',
        '-z',
        '--cached',
        '--others',
        '--exclude-standard',
      ],
      {
        encoding: 'utf8',
        maxBuffer: 1024 * 1024 * 1024,
        stdio: ['ignore', 'pipe', 'ignore'],
      },
    )
      .split('\0')
      .filter(Boolean);
  } catch {
    paths = walkFiles('');
  }
  return [...new Set(paths)]
    .filter((path) => !SKIPPED_DIRECTORY.test(path) && !SKIPPED_FILE.test(path))
    .filter((path) => {
      try {
        return statSync(join(root, path)).isFile();
      } catch {
        return false;
      }
    })
    .sort();
}

function linkTargets(lines) {
  const targets = [];
  for (const line of proseLines(lines)) {
    for (const match of line.matchAll(/\]\([ \t]*(?:<([^>]*)>|([^) \t]+))/g)) {
      targets.push(match[1] ?? match[2]);
    }
    const reference =
      /^ ? ? ?\[[^\]^][^\]]*\]:[ \t]*(?:<([^>]*)>|([^ \t>]+))/.exec(line);
    if (reference) targets.push(reference[1] ?? reference[2]);
  }
  return targets;
}

function checkLinks(paths, violations) {
  let examined = 0;
  for (const path of paths) {
    for (const target of linkTargets(read(path).split('\n'))) {
      if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(target) || target.startsWith('//'))
        continue;
      const file = target.split('#')[0].split('?')[0].replace(/%20/g, ' ');
      if (!file) continue;
      examined += 1;
      const resolved = file.startsWith('/')
        ? join(root, file)
        : join(root, posix.dirname(path), file);
      if (!existsSync(resolved)) {
        violations.push(`${path}: links to ${target}, which does not exist`);
      }
    }
  }
  return examined;
}

function readText(path) {
  const { size } = statSync(join(root, path));
  if (size > LARGEST_SCANNED_FILE) return undefined;
  const buffer = readFileSync(join(root, path));
  if (buffer.subarray(0, 8000).includes(0)) return undefined;
  return buffer.toString('utf8').replace(/\r\n/g, '\n');
}

function checkCitations(files, records, dirs, violations, warnings) {
  const byStem = new Map(records.map((record) => [record.stem, record]));
  let examined = 0;
  for (const path of files) {
    const text = readText(path);
    if (text === undefined || !CITATION_CANDIDATE.test(text)) continue;
    const inRecords = dirs.some((dir) => path.startsWith(`${dir}/`));
    text.split('\n').forEach((line, index) => {
      const at = `${path}:${index + 1}`;
      for (const [stem] of line.matchAll(STEM)) {
        examined += 1;
        const record = byStem.get(stem);
        if (!record) {
          violations.push(`${at}: cites ${stem}, which is not a record`);
        } else if (inRecords) {
          continue;
        } else if (record.status === 'Superseded') {
          warnings.push({
            path,
            line: index + 1,
            message: `cites ${stem}, which is superseded by ${stemOf(record.supersededBy)}; cite the record that stands, or drop the reference`,
          });
        } else if (record.status === 'Deprecated') {
          warnings.push({
            path,
            line: index + 1,
            message: `cites ${stem}, which is deprecated; drop the reference, or cite what replaced it`,
          });
        }
      }
      for (const [mention] of line.matchAll(NUMBERED_MENTION)) {
        examined += 1;
        violations.push(
          `${at}: cites ${mention}, but records are named by timestamp, not number; cite the record's file name`,
        );
      }
    });
  }
  return examined;
}

function checkUnreadFolders(files, dirs, violations) {
  const reported = new Set(dirs);
  for (const path of files) {
    const folder = posix.dirname(path);
    if (reported.has(folder)) continue;
    if (
      ADR_FOLDER_NAMES.has(posix.basename(folder)) &&
      validRecordName(posix.basename(path))
    ) {
      reported.add(folder);
      violations.push(
        `${folder}: holds records the check does not read; add it to ADR_DIRS in ${script}`,
      );
    }
  }
}

function check(dirs = ADR_DIRS) {
  const violations = [];
  const warnings = [];
  const records = readRecords(dirs, violations);
  checkRecords(records, violations);
  for (const dir of dirs) {
    if (existsSync(join(root, dir))) checkIndex(dir, records, violations);
  }
  const files = repositoryFiles();
  checkUnreadFolders(files, dirs, violations);
  const inRecords = (path) => dirs.some((dir) => path.startsWith(`${dir}/`));
  const documents = [
    ...records.map((record) => record.path),
    ...dirs
      .map((dir) => posix.join(dir, 'README.md'))
      .filter((path) => existsSync(join(root, path))),
    ...files.filter((path) => GUIDE.test(path) && !inRecords(path)),
  ];
  const links = checkLinks(documents, violations);
  const citations = checkCitations(files, records, dirs, violations, warnings);
  return {
    violations,
    warnings,
    stats: { records: records.length, folders: dirs.length, links, citations },
  };
}

function fix(dirs = ADR_DIRS) {
  const records = readRecords(dirs, []);
  for (const dir of dirs) {
    const path = posix.join(dir, 'README.md');
    if (!existsSync(join(root, path))) continue;
    const lines = read(path).split('\n');
    const rendered = renderIndex(indexRows(dir, records));
    const table = indexTable(lines);
    if (table.heading === -1) {
      while (lines.length && trim(lines.at(-1)) === '') lines.pop();
      lines.push('', INDEX_HEADING, '', ...rendered, '');
    } else if (table.start === undefined) {
      let at = table.end;
      while (at - 1 > table.heading && trim(lines[at - 1]) === '') at -= 1;
      lines.splice(at, 0, '', ...rendered);
      const after = at + 1 + rendered.length;
      if (after === lines.length) lines.push('');
      else if (lines[after] !== '') lines.splice(after, 0, '');
    } else {
      lines.splice(table.start, table.stop - table.start, ...rendered);
    }
    writeFileSync(join(root, path), lines.join('\n'));
  }
}

function gitText(args) {
  return execFileSync('git', ['-C', root, ...args], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
    maxBuffer: 1024 * 1024 * 1024,
  });
}

function checkHistory(base, dirs = ADR_DIRS) {
  const violations = [];
  const warnings = [];
  try {
    gitText(['rev-parse', '--verify', '--quiet', `${base}^{commit}`]);
  } catch {
    violations.push(
      `--base ${base ?? ''}: not a commit in this clone; fetch it, or run without --base`,
    );
    return { violations, warnings };
  }
  const merged = new Set(
    gitText(['ls-tree', '-r', '--name-only', base, '--', ...dirs])
      .split('\n')
      .filter(
        (path) =>
          dirs.includes(posix.dirname(path)) &&
          validRecordName(posix.basename(path)),
      ),
  );
  for (const path of [...merged].sort()) {
    if (!existsSync(join(root, path))) {
      violations.push(
        `${path}: a merged record is never deleted or renamed; supersede it with a new record`,
      );
      continue;
    }
    const before = gitText(['show', `${base}:${path}`]).replace(/\r\n/g, '\n');
    const after = read(path);
    if (withoutStatus(before) !== withoutStatus(after)) {
      violations.push(
        `${path}: a merged record changes only in its Status section; write a new record that supersedes it`,
      );
    }
    const was = parseRecord(before);
    const is = parseRecord(after);
    if (!was.status || !is.status) continue;
    const next = NEXT_STATUSES[was.status];
    if (!next.includes(is.status)) {
      const onward = next.filter((status) => status !== was.status);
      violations.push(
        `${path}: a merged record does not go from ${was.status} to ${is.status}; ${onward.length ? `from ${was.status} it goes to ${onward.join(' or ')}` : `${was.status} is final`}`,
      );
    } else if (
      was.status === 'Superseded' &&
      was.supersededBy !== is.supersededBy
    ) {
      violations.push(
        `${path}: a merged record keeps the record that superseded it (${was.supersededBy})`,
      );
    }
  }
  for (const dir of dirs) {
    if (!existsSync(join(root, dir))) continue;
    for (const file of readdirSync(join(root, dir)).sort()) {
      const path = posix.join(dir, file);
      if (!validRecordName(file) || merged.has(path)) continue;
      const words = wordCount(read(path));
      if (words > WORD_LIMIT) {
        warnings.push({
          path,
          message: `${words} words, over ${WORD_LIMIT}; one decision per record, and what the change did goes in the pull request`,
        });
      }
    }
  }
  return { violations, warnings };
}

const slugOf = (title) =>
  title
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/['"^~`’]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');

function timestamp(now) {
  const pad = (value) => String(value).padStart(2, '0');
  return `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}${pad(now.getHours())}${pad(now.getMinutes())}`;
}

function create(args) {
  const dirAt = args.indexOf('--dir');
  const dir = dirAt > -1 ? args[dirAt + 1] : ADR_DIRS[0];
  const words =
    dirAt > -1
      ? args.filter((_, at) => at !== dirAt && at !== dirAt + 1)
      : args;
  const title = trim(words.join(' '));
  if (!title) {
    console.log(
      `usage: node ${script} new [--dir <folder>] "<decision title>"\n\nfolders: ${ADR_DIRS.join(', ')}`,
    );
    process.exit(args.length ? 1 : 0);
  }
  const fail = (message) => {
    console.error(`adr: ${message}`);
    process.exit(1);
  };
  if (dirAt === -1 && ADR_DIRS.length > 1) {
    fail(`pick a folder with --dir: ${ADR_DIRS.join(', ')}`);
  }
  if (!ADR_DIRS.includes(dir)) {
    fail(`${dir ?? ''} is not in ADR_DIRS (${ADR_DIRS.join(', ')})`);
  }
  const slug = slugOf(title);
  if (!slug) fail('the title has no letters or digits to name the file');
  const templatePath = posix.join(dir, 'template.md');
  if (!existsSync(join(root, templatePath))) fail(`${templatePath} is missing`);
  const template = read(templatePath);
  if (!/^# .*$/m.test(template)) {
    fail(`${templatePath} has no "# " heading to fill`);
  }
  const path = posix.join(dir, `${timestamp(new Date())}-${slug}.md`);
  try {
    writeFileSync(
      join(root, path),
      template.replace(/^# .*$/m, () => `# ${title}`),
      { flag: 'wx' },
    );
  } catch {
    fail(`${path} already exists`);
  }
  fix();
  console.log(
    `adr: created ${path}; fill in Context, Decision and Consequences`,
  );
}

function printWarning({ path, line, message }) {
  if (process.env.GITHUB_ACTIONS === 'true') {
    const location = line ? `file=${path},line=${line}` : `file=${path}`;
    console.warn(`::warning ${location}::${message}`);
  } else {
    console.warn(`  ! ${line ? `${path}:${line}` : path}: ${message}`);
  }
}

function main() {
  const args = process.argv.slice(2);
  if (args[0] === 'new') return create(args.slice(1));
  if (args.includes('--fix')) fix();
  const { violations, warnings, stats } = check();
  console.log(
    `adr: ${stats.records} records in ${stats.folders} folder(s), ${stats.links} links, ${stats.citations} citations`,
  );
  const baseAt = args.indexOf('--base');
  if (baseAt > -1) {
    const history = checkHistory(args[baseAt + 1]);
    violations.push(...history.violations);
    warnings.push(...history.warnings);
  }
  for (const warning of warnings) printWarning(warning);
  for (const violation of violations) console.error(`  ✗ ${violation}`);
  if (violations.length) {
    console.error(`adr: ${violations.length} violation(s)`);
    process.exit(1);
  }
}

main();
