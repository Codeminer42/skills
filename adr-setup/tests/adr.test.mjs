// Runs every case against both checkers the skill installs, adr.mjs and
// adr.sh, so the two keep reporting the same thing in the same words.
//
//   node --test adr-setup/tests/adr.test.mjs
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const assets = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets');
const asset = (name) => readFileSync(join(assets, name), 'utf8');

const CHECKERS = [
  {
    name: 'adr.mjs',
    file: 'scripts/adr.mjs',
    run: (root, args) =>
      spawnSync('node', ['scripts/adr.mjs', ...args], {
        cwd: root,
        encoding: 'utf8',
        env: environment(),
      }),
    dirs: (source, dirs) =>
      source.replace(
        /^const ADR_DIRS = .*$/m,
        `const ADR_DIRS = [${dirs.map((dir) => `'${dir}'`).join(', ')}];`,
      ),
  },
  {
    name: 'adr.sh',
    file: 'scripts/adr.sh',
    run: (root, args) =>
      spawnSync(
        process.env.ADR_TEST_BASH ?? 'bash',
        ['scripts/adr.sh', ...args],
        { cwd: root, encoding: 'utf8', env: environment() },
      ),
    dirs: (source, dirs) =>
      source.replace(/^ADR_DIRS=.*$/m, `ADR_DIRS=(${dirs.join(' ')})`),
  },
];

function environment() {
  const env = { ...process.env };
  delete env.GITHUB_ACTIONS;
  return env;
}

const FIRST =
  'docs/adr/202610161200-record-architecture-decisions-with-adrs.md';

const record = (title, status = 'Accepted', extra = '') =>
  `# ${title}\n\n## Status\n\n${status}\n\n## Context\n\nWhy.${extra}\n\n## Decision\n\nWhat.\n\n## Consequences\n\nThen.\n`;

const installed =
  (adrDir = 'docs/adr') =>
  (text) =>
    text
      .replaceAll('<adr-dir>', adrDir)
      .replaceAll('<check>', '`npm run adr:check`')
      .replaceAll('<new>', '`npm run adr:new -- "<decision title>"`')
      .replaceAll('<index>', '`npm run adr:index`');

// What the skill writes on a fresh repository, before the index is filled.
const baseline = () => ({
  'docs/adr/README.md': asset('README.md'),
  'docs/adr/template.md': asset('template.md'),
  [FIRST]: installed()(asset('first-adr.md')),
  'AGENTS.md': `# Agents\n\n${installed()(asset('agent-instructions.md'))}${installed()(asset('agent-instructions-check.md'))}`,
  'README.md': '# Project\n\nSee [the decisions](docs/adr/README.md).\n',
});

const roots = [];
after(() =>
  roots.forEach((root) => rmSync(root, { recursive: true, force: true })),
);

function write(root, files) {
  for (const [path, content] of Object.entries(files)) {
    if (content === null) {
      rmSync(join(root, path), { force: true });
      continue;
    }
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), content);
  }
}

function repository(checker, files = {}, { dirs, fix = true } = {}) {
  const root = mkdtempSync(join(tmpdir(), 'adr-'));
  roots.push(root);
  write(root, { ...baseline(), ...files });
  const source = readFileSync(
    join(assets, checker.file.replace('scripts/', '')),
    'utf8',
  );
  write(root, { [checker.file]: dirs ? checker.dirs(source, dirs) : source });
  if (fix) checker.run(root, ['--fix']);
  return root;
}

function git(root, ...args) {
  return execFileSync(
    'git',
    ['-C', root, '-c', 'user.name=t', '-c', 'user.email=t@t', ...args],
    { encoding: 'utf8' },
  );
}

function commit(root) {
  if (!existsSync(join(root, '.git'))) git(root, 'init', '-q');
  git(root, 'add', '-A');
  git(root, 'commit', '-q', '-m', 'commit', '--allow-empty');
  return git(root, 'rev-parse', 'HEAD').trim();
}

const normalize = (line) =>
  line.replace(
    /node scripts\/adr\.mjs|scripts\/adr\.mjs|scripts\/adr\.sh/g,
    '<script>',
  );

function run(checker, root, ...args) {
  const result = checker.run(root, args);
  const lines = result.stderr.split('\n');
  return {
    status: result.status,
    stdout: result.stdout,
    stderr: result.stderr,
    violations: lines
      .filter((line) => line.startsWith('  ✗ '))
      .map((line) => normalize(line.slice(4))),
    warnings: lines
      .filter((line) => line.startsWith('  ! '))
      .map((line) => normalize(line.slice(4))),
  };
}

function passes(result) {
  assert.deepEqual(result.violations, [], result.stderr);
  assert.equal(result.status, 0, result.stderr);
}

function fails(result, ...expected) {
  for (const violation of expected) {
    assert.ok(
      result.violations.includes(violation),
      `expected\n  ${violation}\ngot\n  ${result.violations.join('\n  ') || '(nothing)'}`,
    );
  }
  assert.equal(result.status, 1);
}

for (const checker of CHECKERS) {
  describe(checker.name, () => {
    describe('records', () => {
      it('passes the files the skill installs, once the index is generated', () => {
        const root = repository(checker);
        const result = run(checker, root);
        passes(result);
        assert.deepEqual(result.warnings, []);
        assert.match(
          result.stdout,
          /^adr: 1 records in 1 folder\(s\), 2 links, 1 citations$/m,
        );
      });

      it('fails a file not named YYYYMMDDHHMM-<decision-slug>.md, or with a date that is not one', () => {
        const root = repository(checker, {
          'docs/adr/0001-use-postgres.md': record('Use Postgres'),
          'docs/adr/202613011200-use-redis.md': record('Use Redis'),
          'docs/adr/202610161200-Use-Kafka.md': record('Use Kafka'),
        });
        fails(
          run(checker, root),
          'docs/adr/0001-use-postgres.md: a record is named YYYYMMDDHHMM-<decision-slug>.md',
          'docs/adr/202613011200-use-redis.md: a record is named YYYYMMDDHHMM-<decision-slug>.md',
          'docs/adr/202610161200-Use-Kafka.md: a record is named YYYYMMDDHHMM-<decision-slug>.md',
        );
      });

      it('fails a record without a heading, or with the template placeholder left in it', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
          ).replace('# Use Postgres\n', 'Use Postgres\n'),
          'docs/adr/202610161301-use-redis.md': record('{{Decision title}}'),
        });
        fails(
          run(checker, root),
          'docs/adr/202610161300-use-postgres.md: has no "# <decision title>" heading',
          "docs/adr/202610161301-use-redis.md: the heading is still the template's placeholder",
        );
      });

      it('fails a record missing one of the template sections', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
          ).replace('## Consequences', '## Outcome'),
        });
        fails(
          run(checker, root),
          'docs/adr/202610161300-use-postgres.md: has no "## Consequences" section',
        );
      });

      it('fails an empty status and one outside the list', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            '<!-- Proposed | Accepted -->',
          ),
          'docs/adr/202610161301-use-redis.md': record('Use Redis', 'Approved'),
          'docs/adr/202610161302-use-kafka.md': record('Use Kafka', 'accepted'),
        });
        fails(
          run(checker, root),
          'docs/adr/202610161300-use-postgres.md: the Status section is empty',
          'docs/adr/202610161301-use-redis.md: status "Approved" is not Proposed, Accepted, Rejected, Deprecated, or Superseded by [title](./file.md)',
          'docs/adr/202610161302-use-kafka.md: status "accepted" is not Proposed, Accepted, Rejected, Deprecated, or Superseded by [title](./file.md)',
        );
      });

      it('reads the status past the template comment, across lines', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            '<!--\nProposed | Accepted\n-->\n\nSuperseded by\n[Use CockroachDB](./202610161400-use-cockroachdb.md)',
          ),
          'docs/adr/202610161400-use-cockroachdb.md': record('Use CockroachDB'),
        });
        passes(run(checker, root));
      });

      it('passes a superseded record and indexes it with a link to the record that replaced it', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            'Superseded by [Use CockroachDB](./202610161400-use-cockroachdb.md)',
          ),
          'docs/adr/202610161400-use-cockroachdb.md': record('Use CockroachDB'),
        });
        passes(run(checker, root));
        assert.ok(
          readFileSync(join(root, 'docs/adr/README.md'), 'utf8').includes(
            '| 2026-10-16 | [Use Postgres](./202610161300-use-postgres.md) | Superseded by [Use CockroachDB](./202610161400-use-cockroachdb.md) |',
          ),
        );
      });

      it('fails a supersession by a record that is missing, itself, older, or not in effect', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            'Superseded by [Use X](./202610161900-use-x.md)',
          ),
          'docs/adr/202610161301-use-redis.md': record(
            'Use Redis',
            'Superseded by [Use Redis](./202610161301-use-redis.md)',
          ),
          'docs/adr/202610161302-use-kafka.md': record(
            'Use Kafka',
            'Superseded by [Use Postgres](./202610161300-use-postgres.md)',
          ),
          'docs/adr/202610161303-use-mysql.md': record(
            'Use MySQL',
            'Superseded by [Use SQLite](./202610161304-use-sqlite.md)',
          ),
          'docs/adr/202610161304-use-sqlite.md': record(
            'Use SQLite',
            'Proposed',
          ),
        });
        fails(
          run(checker, root),
          'docs/adr/202610161300-use-postgres.md: superseded by 202610161900-use-x.md, which is not a record in this folder',
          'docs/adr/202610161301-use-redis.md: superseded by itself',
          'docs/adr/202610161302-use-kafka.md: superseded by 202610161300-use-postgres.md, which is older',
          'docs/adr/202610161303-use-mysql.md: superseded by 202610161304-use-sqlite.md, which is proposed; only a decision in effect replaces one',
        );
      });
    });

    describe('folders', () => {
      it('fails a folder that is missing, and one with no records rather than passing on nothing', () => {
        const root = repository(
          checker,
          { 'apps/web/docs/adr/README.md': asset('README.md') },
          { dirs: ['docs/adr', 'apps/web/docs/adr', 'apps/api/docs/adr'] },
        );
        fails(
          run(checker, root),
          'apps/web/docs/adr: holds no records; the check would pass on nothing',
          'apps/api/docs/adr: is in ADR_DIRS but does not exist',
        );
      });

      it('fails a folder of records the check does not read', () => {
        const root = repository(checker, {
          'packages/api/docs/decisions/202610161300-use-postgres.md':
            record('Use Postgres'),
        });
        fails(
          run(checker, root),
          'packages/api/docs/decisions: holds records the check does not read; add it to ADR_DIRS in <script>',
        );
      });

      it('reads every folder in ADR_DIRS', () => {
        const root = repository(
          checker,
          {
            'apps/web/docs/adr/README.md': asset('README.md'),
            'apps/web/docs/adr/202610161300-use-react.md': record('Use React'),
          },
          { dirs: ['docs/adr', 'apps/web/docs/adr'] },
        );
        const result = run(checker, root);
        passes(result);
        assert.match(result.stdout, /^adr: 2 records in 2 folder\(s\)/m);
      });
    });

    describe('index', () => {
      it('generates the index from the files, oldest first, and leaves the rest of the README alone', () => {
        const root = repository(checker, {
          'docs/adr/202610151200-use-postgres.md': record(
            'Use Postgres | 16',
            'Proposed',
          ),
        });
        const readme = readFileSync(join(root, 'docs/adr/README.md'), 'utf8');
        assert.ok(
          readme.endsWith(
            '| Date | Decision | Status |\n| --- | --- | --- |\n| 2026-10-15 | [Use Postgres \\| 16](./202610151200-use-postgres.md) | Proposed |\n| 2026-10-16 | [Record architecture decisions with ADRs](./202610161200-record-architecture-decisions-with-adrs.md) | Accepted |\n',
          ),
          readme,
        );
        assert.equal(
          readme.split('## Index')[0],
          asset('README.md').split('## Index')[0],
        );
      });

      it('is idempotent', () => {
        const root = repository(checker);
        const before = readFileSync(join(root, 'docs/adr/README.md'), 'utf8');
        checker.run(root, ['--fix']);
        assert.equal(
          readFileSync(join(root, 'docs/adr/README.md'), 'utf8'),
          before,
        );
      });

      it('accepts a hand-aligned table that says the same thing', () => {
        const root = repository(checker);
        const path = join(root, 'docs/adr/README.md');
        write(root, {
          'docs/adr/README.md': readFileSync(path, 'utf8').replace(
            '| Date | Decision | Status |\n| --- | --- | --- |\n| 2026-10-16 | [Record architecture decisions with ADRs](./202610161200-record-architecture-decisions-with-adrs.md) | Accepted |',
            '| Date       | Decision                                                                                             | Status   |\n|:-----------|:-----------------------------------------------------------------------------------------------------|:---------|\n|  2026-10-16  |   [Record architecture decisions with ADRs](./202610161200-record-architecture-decisions-with-adrs.md)   |  Accepted  |',
          ),
        });
        passes(run(checker, root));
      });

      it('fails a stale row, a missing row, a row for no record, and rows out of order', () => {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record('Use Postgres'),
          'docs/adr/202610161400-use-redis.md': record('Use Redis'),
        });
        const readme = readFileSync(join(root, 'docs/adr/README.md'), 'utf8');
        write(root, {
          'docs/adr/README.md': readme
            .replace(
              '[Use Postgres](./202610161300-use-postgres.md) | Accepted',
              '[Use Postgres](./202610161300-use-postgres.md) | Proposed',
            )
            .replace(
              /^\| 2026-10-16 \| \[Use Redis\].*\n/m,
              '| 2026-10-16 | [Use Kafka](./202610161350-use-kafka.md) | Accepted |\n',
            ),
        });
        fails(
          run(checker, root),
          'docs/adr/README.md: the index row for 202610161300-use-postgres.md reads "2026-10-16 | [Use Postgres](./202610161300-use-postgres.md) | Proposed", the record says "2026-10-16 | [Use Postgres](./202610161300-use-postgres.md) | Accepted"; run <script> --fix',
          'docs/adr/README.md: the index has no row for 202610161400-use-redis.md; run <script> --fix',
          'docs/adr/README.md: the index lists 202610161350-use-kafka.md, which is not a record; run <script> --fix',
        );

        checker.run(root, ['--fix']);
        const rows = readFileSync(
          join(root, 'docs/adr/README.md'),
          'utf8',
        ).split('\n');
        const at = rows.findIndex(
          (line) => line.startsWith('| 2026') && line.includes('use-postgres'),
        );
        [rows[at], rows[at + 1]] = [rows[at + 1], rows[at]];
        write(root, { 'docs/adr/README.md': rows.join('\n') });
        fails(
          run(checker, root),
          'docs/adr/README.md: the index rows are out of order, oldest first; run <script> --fix',
        );
      });

      it('fails a README with no index, and writes one under the Index heading or at the end', () => {
        const root = repository(
          checker,
          {
            'docs/adr/README.md':
              '# Decisions\n\n## Index\n\nEvery record.\n\n## Elsewhere\n\nMore.\n',
          },
          { fix: false },
        );
        fails(
          run(checker, root),
          'docs/adr/README.md: the Index section has no table; run <script> --fix',
        );
        checker.run(root, ['--fix']);
        assert.equal(
          readFileSync(join(root, 'docs/adr/README.md'), 'utf8'),
          '# Decisions\n\n## Index\n\nEvery record.\n\n| Date | Decision | Status |\n| --- | --- | --- |\n| 2026-10-16 | [Record architecture decisions with ADRs](./202610161200-record-architecture-decisions-with-adrs.md) | Accepted |\n\n## Elsewhere\n\nMore.\n',
        );

        write(root, {
          'docs/adr/README.md': '# Decisions\n\nEvery record.\n\n',
        });
        fails(
          run(checker, root),
          'docs/adr/README.md: has no "## Index" section; run <script> --fix',
        );
        checker.run(root, ['--fix']);
        assert.equal(
          readFileSync(join(root, 'docs/adr/README.md'), 'utf8'),
          '# Decisions\n\nEvery record.\n\n## Index\n\n| Date | Decision | Status |\n| --- | --- | --- |\n| 2026-10-16 | [Record architecture decisions with ADRs](./202610161200-record-architecture-decisions-with-adrs.md) | Accepted |\n',
        );
        passes(run(checker, root));
      });

      it('fails a missing README', () => {
        const root = repository(checker, {
          'docs/adr/README.md': null,
          'README.md': '# Project\n',
        });
        fails(
          run(checker, root),
          'docs/adr/README.md: is missing; it holds the index',
        );
      });
    });

    describe('links', () => {
      it('fails a relative link that does not resolve, in every file agents read', () => {
        const root = repository(checker, {
          'AGENTS.md': '# Agents\n\nRead [the guide](docs/guide.md).\n',
          'apps/web/CLAUDE.md':
            '# Web\n\nSee [testing](./docs/testing.md#mocks).\n',
          '.claude/skills/deploy/SKILL.md':
            '# Deploy\n\n[Runbook](../../../docs/runbook.md)\n',
          '.github/copilot-instructions.md':
            'Read [this](../docs/missing.md).\n',
          'CONTRIBUTING.md': '[style]: docs/style.md\n',
          [FIRST]: installed()(asset('first-adr.md')).replace(
            '## Consequences',
            'See [the old way](./202601010000-nope.md).\n\n## Consequences',
          ),
        });
        fails(
          run(checker, root),
          'AGENTS.md: links to docs/guide.md, which does not exist',
          'apps/web/CLAUDE.md: links to ./docs/testing.md#mocks, which does not exist',
          '.claude/skills/deploy/SKILL.md: links to ../../../docs/runbook.md, which does not exist',
          '.github/copilot-instructions.md: links to ../docs/missing.md, which does not exist',
          'CONTRIBUTING.md: links to docs/style.md, which does not exist',
          `${FIRST}: links to ./202601010000-nope.md, which does not exist`,
        );
      });

      it('passes links that resolve, from the root too, and ignores URLs, anchors, footnotes, comments and code', () => {
        const root = repository(checker, {
          'docs/guide.md': '# Guide\n',
          'AGENTS.md': [
            '# Agents',
            '',
            'Read [the guide](docs/guide.md#top), [the index](/docs/adr/README.md) and [the folder](docs/adr/).',
            'Also [the site](https://example.com/missing.md), [mail](mailto:a@b.c), [here](#agents) and [spaced](<docs/guide.md>).',
            '[^1]: a footnote, not a link',
            '<!-- [old](docs/old.md) -->',
            '<!--',
            '[older](docs/older.md)',
            '-->',
            'Write `[title](./file.md)` for a link.',
            '```md',
            '[example](./example.md)',
            '```',
            '',
          ].join('\n'),
        });
        const result = run(checker, root);
        passes(result);
        assert.match(result.stdout, /, 6 links,/);
      });

      it('does not read links in files agents are not pointed at', () => {
        const root = repository(checker, {
          'docs/notes.md': '[gone](./gone.md)\n',
        });
        passes(run(checker, root));
      });
    });

    describe('citations', () => {
      const superseded = {
        'docs/adr/202610161300-use-postgres.md': record(
          'Use Postgres',
          'Superseded by [Use CockroachDB](./202610161400-use-cockroachdb.md)',
          '\n\nSee 202610161400-use-cockroachdb.',
        ),
        'docs/adr/202610161400-use-cockroachdb.md': record(
          'Use CockroachDB',
          'Accepted',
          '\n\nReplaces 202610161300-use-postgres.',
        ),
        'docs/adr/202610161500-use-memcached.md': record(
          'Use Memcached',
          'Deprecated',
        ),
      };

      it('passes a citation of a record that stands, in code or docs', () => {
        const root = repository(checker, {
          ...superseded,
          'src/db.ts':
            '// Kept on CockroachDB: docs/adr/202610161400-use-cockroachdb.md\nexport const db = 1;\n',
          'docs/ops.md': 'We run `202610161400-use-cockroachdb`.\n',
        });
        const result = run(checker, root);
        passes(result);
        assert.deepEqual(result.warnings, []);
        assert.match(result.stdout, /, 10 citations$/m);
      });

      it('fails a citation that names no record, and one by number', () => {
        const root = repository(checker, {
          'src/db.rb': '# see 202610161300-use-postgresql\nDB = 1\n',
          'lib/cache.go':
            'package cache\n\n// ADR-3 says so, and so does ADR 0012.\n',
          'docs/ops.md': 'Per ADR#7.\n',
        });
        fails(
          run(checker, root),
          'src/db.rb:1: cites 202610161300-use-postgresql, which is not a record',
          "lib/cache.go:3: cites ADR-3, but records are named by timestamp, not number; cite the record's file name",
          "lib/cache.go:3: cites ADR 0012, but records are named by timestamp, not number; cite the record's file name",
          "docs/ops.md:1: cites ADR#7, but records are named by timestamp, not number; cite the record's file name",
        );
      });

      it('warns on a citation of a superseded or deprecated record outside the records, and does not fail it', () => {
        const root = repository(checker, {
          ...superseded,
          'src/db.py': 'import os\n# 202610161300-use-postgres\n',
          'src/cache.py': '# 202610161500-use-memcached.md\n',
        });
        const result = run(checker, root);
        passes(result);
        assert.deepEqual(result.warnings.sort(), [
          'src/cache.py:1: cites 202610161500-use-memcached, which is deprecated; drop the reference, or cite what replaced it',
          'src/db.py:2: cites 202610161300-use-postgres, which is superseded by 202610161400-use-cockroachdb; cite the record that stands, or drop the reference',
        ]);
      });

      it('ignores names inside longer tokens', () => {
        const root = repository(checker, {
          'db/migrate/20261016120000_create_users.rb':
            'class CreateUsers; end\n',
          'src/ids.ts':
            'const a = "x202610161300-use-thing";\nconst b = "202610161300-use-thing_v2";\nconst c = "NOTADR-3";\n',
        });
        passes(run(checker, root));
      });

      it('skips dependencies and lockfiles', () => {
        const root = repository(checker, {
          'node_modules/pkg/index.js': '// 202610161300-use-nothing\n',
          'vendor/lib/a.rb': '# ADR-1\n',
          'yarn.lock': 'ADR-1\n',
        });
        passes(run(checker, root));
      });

      it('skips files git ignores', () => {
        const root = repository(checker, {
          '.gitignore': 'tmp/\n',
          'tmp/notes.txt': 'ADR-1\n',
        });
        commit(root);
        write(root, { 'scratch.txt': 'ADR-2\n' });
        fails(
          run(checker, root),
          "scratch.txt:1: cites ADR-2, but records are named by timestamp, not number; cite the record's file name",
        );
        assert.ok(
          !run(checker, root).violations.some((violation) =>
            violation.startsWith('tmp/'),
          ),
        );
      });
    });

    describe('new', () => {
      it('creates a record from the template, named by timestamp and slug, and indexes it', () => {
        const root = repository(checker);
        const result = checker.run(root, ['new', "Don't", 'use', 'Café ORM']);
        assert.equal(result.status, 0, result.stderr);
        const file = readdirSync(join(root, 'docs/adr')).find((name) =>
          name.endsWith('-dont-use-cafe-orm.md'),
        );
        assert.match(file, /^\d{12}-dont-use-cafe-orm\.md$/);
        const created = readFileSync(join(root, 'docs/adr', file), 'utf8');
        assert.equal(
          created,
          asset('template.md').replace(
            '# {{Decision title}}',
            "# Don't use Café ORM",
          ),
        );
        assert.match(result.stdout, new RegExp(`created docs/adr/${file}`));
        assert.ok(
          readFileSync(join(root, 'docs/adr/README.md'), 'utf8').includes(
            `| [Don't use Café ORM](./${file}) | Proposed |`,
          ),
        );
        passes(run(checker, root));
      });

      it('prints usage without a title, and refuses a title with nothing to slug', () => {
        const root = repository(checker);
        const usage = checker.run(root, ['new']);
        assert.equal(usage.status, 0);
        assert.match(usage.stdout, /^usage: /);
        const empty = checker.run(root, ['new', '???']);
        assert.equal(empty.status, 1);
        assert.match(empty.stderr, /the title has no letters or digits/);
      });
    });

    describe('history', () => {
      function merged(files = {}) {
        const root = repository(checker, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            'Proposed',
          ),
          'docs/adr/202610161400-use-redis.md': record('Use Redis'),
          'docs/adr/202610161350-use-kafka.md': record(
            'Use Kafka',
            'Superseded by [Use Redis](./202610161400-use-redis.md)',
          ),
          ...files,
        });
        const base = commit(root);
        return { root, base };
      }

      it('passes a branch that changes no merged record', () => {
        const { root, base } = merged();
        write(root, {
          'docs/adr/202610161600-use-nats.md': record('Use NATS', 'Proposed'),
        });
        checker.run(root, ['--fix']);
        passes(run(checker, root, '--base', base));
      });

      it('allows a status to move forward, and the index with it', () => {
        const { root, base } = merged();
        write(root, {
          'docs/adr/202610161300-use-postgres.md': record(
            'Use Postgres',
            '<!-- agreed on 2026-10-17 -->\nAccepted',
          ),
        });
        checker.run(root, ['--fix']);
        passes(run(checker, root, '--base', base));
      });

      it('fails an edit outside the Status section', () => {
        const { root, base } = merged();
        write(root, {
          'docs/adr/202610161400-use-redis.md': record(
            'Use Redis',
            'Accepted',
            ' And more.',
          ),
        });
        fails(
          run(checker, root, '--base', base),
          'docs/adr/202610161400-use-redis.md: a merged record changes only in its Status section; write a new record that supersedes it',
        );
      });

      it('fails a status that moves back, or off a final one', () => {
        const { root, base } = merged();
        write(root, {
          'docs/adr/202610161400-use-redis.md': record('Use Redis', 'Proposed'),
          'docs/adr/202610161350-use-kafka.md': record('Use Kafka', 'Accepted'),
        });
        checker.run(root, ['--fix']);
        fails(
          run(checker, root, '--base', base),
          'docs/adr/202610161400-use-redis.md: a merged record does not go from Accepted to Proposed; from Accepted it goes to Deprecated or Superseded',
          'docs/adr/202610161350-use-kafka.md: a merged record does not go from Superseded to Accepted; Superseded is final',
        );
      });

      it('fails a superseded record that changes which record superseded it', () => {
        const { root, base } = merged({
          'docs/adr/202610161600-use-nats.md': record('Use NATS'),
        });
        write(root, {
          'docs/adr/202610161350-use-kafka.md': record(
            'Use Kafka',
            'Superseded by [Use NATS](./202610161600-use-nats.md)',
          ),
        });
        checker.run(root, ['--fix']);
        fails(
          run(checker, root, '--base', base),
          'docs/adr/202610161350-use-kafka.md: a merged record keeps the record that superseded it (202610161400-use-redis.md)',
        );
      });

      it('fails a merged record that was deleted or renamed', () => {
        const { root, base } = merged();
        write(root, {
          'docs/adr/202610161300-use-postgres.md': null,
          'docs/adr/202610161401-use-redis-for-caching.md': readFileSync(
            join(root, 'docs/adr/202610161400-use-redis.md'),
            'utf8',
          ),
          'docs/adr/202610161400-use-redis.md': null,
          'docs/adr/202610161350-use-kafka.md': record(
            'Use Kafka',
            'Superseded by [Use Redis](./202610161401-use-redis-for-caching.md)',
          ),
        });
        checker.run(root, ['--fix']);
        const result = run(checker, root, '--base', base);
        fails(
          result,
          'docs/adr/202610161300-use-postgres.md: a merged record is never deleted or renamed; supersede it with a new record',
          'docs/adr/202610161400-use-redis.md: a merged record is never deleted or renamed; supersede it with a new record',
        );
      });

      it('fails with a readable message when the base is not in the clone', () => {
        const { root } = merged();
        fails(
          run(checker, root, '--base', 'no-such-ref'),
          '--base no-such-ref: not a commit in this clone; fetch it, or run without --base',
        );
      });

      it('warns on a new record over the word limit, not counting comments or the status, and not on a merged one', () => {
        const long = ` ${'word '.repeat(790)}`;
        const { root, base } = merged({
          'docs/adr/202610161600-use-nats.md': record(
            'Use NATS',
            'Accepted',
            long,
          ),
        });
        write(root, {
          'docs/adr/202610161700-use-zeromq.md': record(
            'Use ZeroMQ',
            'Accepted',
            long,
          ),
          'docs/adr/202610161800-use-mqtt.md': record(
            'Use MQTT',
            `<!-- ${'note '.repeat(50)} -->\nAccepted`,
            ` ${'word '.repeat(780)}`,
          ),
        });
        checker.run(root, ['--fix']);
        const result = run(checker, root, '--base', base);
        passes(result);
        assert.deepEqual(result.warnings, [
          'docs/adr/202610161700-use-zeromq.md: 802 words, over 800; one decision per record, and what the change did goes in the pull request',
        ]);
      });
    });

    it('prints warnings as GitHub annotations in Actions', () => {
      const root = repository(checker, {
        'docs/adr/202610161300-use-postgres.md': record(
          'Use Postgres',
          'Superseded by [Use CockroachDB](./202610161400-use-cockroachdb.md)',
        ),
        'docs/adr/202610161400-use-cockroachdb.md': record('Use CockroachDB'),
        'src/db.ts': '// 202610161300-use-postgres\n',
      });
      const result = spawnSync(
        checker.name === 'adr.mjs'
          ? 'node'
          : (process.env.ADR_TEST_BASH ?? 'bash'),
        [checker.file],
        {
          cwd: root,
          encoding: 'utf8',
          env: { ...environment(), GITHUB_ACTIONS: 'true' },
        },
      );
      assert.equal(result.status, 0, result.stderr);
      assert.match(
        result.stderr,
        /^::warning file=src\/db\.ts,line=1::cites 202610161300-use-postgres, which is superseded by 202610161400-use-cockroachdb; cite the record that stands, or drop the reference$/m,
      );
    });
  });
}

describe('both checkers', () => {
  it('report the same thing, in the same words, on a repository that breaks every rule', () => {
    const files = {
      'docs/adr/0001-use-postgres.md': record('Use Postgres'),
      'docs/adr/202610161300-use-redis.md': record(
        'Use Redis',
        'Approved',
      ).replace('## Decision', '## Choice'),
      'docs/adr/202610161301-use-kafka.md': record(
        '{{Decision title}}',
        'Superseded by [Use Redis](./202610161300-use-redis.md)',
      ),
      'docs/adr/202610161302-use-nats.md': record(
        'Use NATS',
        'Superseded by [Use Zero](./202610161500-use-zero.md)',
        '\n\n[Gone](./gone.md)',
      ),
      'docs/adr/202610161303-use-mqtt.md': record('Use MQTT', 'Deprecated'),
      'AGENTS.md':
        '# Agents\n\n[Gone](docs/gone.md) and [fine](README.md). See ADR-4.\n',
      'src/a.ts':
        '// 202610161303-use-mqtt\n// 202610161301-use-kafka\n// 202610169999-use-nothing\n',
      'pkg/docs/adr/202610161300-x.md': record('X'),
    };
    const outputs = CHECKERS.map((checker) => {
      const root = repository(checker, files);
      const base = commit(root);
      write(root, {
        'docs/adr/202610161303-use-mqtt.md': record(
          'Use MQTT',
          'Accepted',
          ' Edited.',
        ),
        'docs/adr/202610161300-use-redis.md': null,
      });
      const result = run(checker, root, '--base', base);
      return {
        status: result.status,
        stdout: result.stdout,
        violations: [...result.violations].sort(),
        warnings: [...result.warnings].sort(),
      };
    });
    assert.ok(
      outputs[0].violations.length > 10,
      outputs[0].violations.join('\n'),
    );
    assert.deepEqual(outputs[1], outputs[0]);
  });
});
