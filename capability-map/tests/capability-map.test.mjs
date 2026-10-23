// Installs capability-map.sh into throwaway repositories and runs it, the way
// the skill and CI do. Node is only the test runner; the check needs bash and
// awk.
//
//   node --test capability-map/tests/capability-map.test.mjs
//   CAPABILITY_MAP_TEST_BASH=/bin/bash node --test capability-map/tests/capability-map.test.mjs
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, describe, it } from 'node:test';
import { fileURLToPath } from 'node:url';

const assets = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets');
const asset = (name) => readFileSync(join(assets, name), 'utf8');

const BASH = process.env.CAPABILITY_MAP_TEST_BASH ?? 'bash';

const roots = [];
after(() => roots.forEach((root) => rmSync(root, { recursive: true, force: true })));

const entry = (id, one = `what ${id} is`, overrides = {}) => {
  const fields = {
    'One line': one,
    Language: `${id}, thing`,
    Owns: 'the things table',
    Contracts: '/api/things',
    'Who acts': 'any member',
    'Is not': 'billing (billing)',
    'Lives in': 'app/things',
    Decisions: 'BE-0001 keep things',
    State: 'built',
    ...overrides,
  };
  const body = Object.entries(fields)
    .filter(([, value]) => value !== null)
    .map(([field, value]) => `**${field}:** ${value}`)
    .join('\n');
  return `## ${id}\n\n${body}\n`;
};

const map = (...entries) =>
  `# Capability Map\n\n> Intro.\n\n# Sales\n\nSelling.\n\n${entries.join('\n')}\n# Declared, not built\n\n- **refunds** — declared, nothing checks it.\n\n# Where the words still disagree\n\n## not-a-capability\n\n---\n\n> **How to keep this page true.** Update it.\n`;

const agent = (glossary = '') =>
  `# Project\n\n${asset('agent-instructions.md')
    .replaceAll('<map>', 'docs/capability-map.md')
    .replaceAll('<the glossary>', 'the Glossary')}${glossary}\n## Other\n\nText.\n`;

function repository({ mapText, agentText = agent(), glossaryFile = '' }) {
  const root = mkdtempSync(join(tmpdir(), 'capability-map-'));
  roots.push(root);
  execFileSync('git', ['init', '-q'], { cwd: root });
  mkdirSync(join(root, 'docs'));
  mkdirSync(join(root, 'scripts'));
  const script = asset('capability-map.sh').replace(
    "GLOSSARY_FILE=''",
    `GLOSSARY_FILE='${glossaryFile}'`,
  );
  writeFileSync(join(root, 'scripts', 'capability-map.sh'), script);
  writeFileSync(join(root, 'docs', 'capability-map.md'), mapText);
  writeFileSync(join(root, 'CLAUDE.md'), agentText);
  return root;
}

const run = (root, args = []) =>
  spawnSync(BASH, ['scripts/capability-map.sh', ...args], {
    cwd: root,
    encoding: 'utf8',
  });

describe('capability-map.sh', () => {
  it('fills the table with --fix, then passes', () => {
    const root = repository({ mapText: map(entry('orders'), entry('payments')) });
    assert.equal(run(root).status, 1);
    const fixed = run(root, ['--fix']);
    assert.equal(fixed.status, 0, fixed.stderr);
    const text = readFileSync(join(root, 'CLAUDE.md'), 'utf8');
    assert.match(text, /\| \[orders\]\(docs\/capability-map\.md#orders\) \| Sales \| what orders is \|/);
    assert.match(text, /\| \[payments\]\(docs\/capability-map\.md#payments\) \| Sales \|/);
    assert.match(text, /## Other\n\nText\./, 'keeps what follows the table');
    assert.equal(run(root).status, 0);
  });

  it('fails on a stale table', () => {
    const root = repository({ mapText: map(entry('orders')) });
    run(root, ['--fix']);
    const path = join(root, 'docs', 'capability-map.md');
    writeFileSync(path, readFileSync(path, 'utf8').replace('what orders is', 'what orders became'));
    const result = run(root);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /capability table is stale/);
  });

  it('escapes a pipe in a one line', () => {
    const root = repository({ mapText: map(entry('orders', 'buy | sell')) });
    assert.equal(run(root, ['--fix']).status, 0);
    assert.match(readFileSync(join(root, 'CLAUDE.md'), 'utf8'), /buy \\\| sell/);
  });

  it('fails on a missing, unknown, repeated or out-of-order field', () => {
    const missing = entry('orders', undefined, { 'Is not': null });
    const unknown = `${entry('payments')}**Owner:** someone\n`;
    const repeated = `${entry('refunds')}**State:** again\n`;
    const swapped = entry('returns').replace(
      /(\*\*Owns:\*\*.*)\n(\*\*Contracts:\*\*.*)/,
      '$2\n$1',
    );
    const root = repository({ mapText: map(missing, unknown, repeated, swapped) });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /orders: no \*\*Is not:\*\* line/);
    assert.match(result.stderr, /payments: \*\*Owner:\*\* is not a field/);
    assert.match(result.stderr, /refunds: \*\*State:\*\* appears twice/);
    assert.match(result.stderr, /returns: \*\*Contracts:\*\* is out of order|returns: \*\*Owns:\*\* is out of order/);
  });

  it('fails on a heading that is not a capability id, or has no context', () => {
    const root = repository({
      mapText: `## orphan\n\n${entry('x').split('\n').slice(2).join('\n')}\n${map(entry('Orders'))}`,
    });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /"## Orders" is not a capability id/);
    assert.match(result.stderr, /orphan: no context/);
  });

  it('ignores headings in closing sections and code fences', () => {
    const fenced = '```markdown\n## Not-An-Id\n```\n';
    const root = repository({ mapText: map(entry('orders'), fenced) });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 0, result.stderr);
    assert.doesNotMatch(readFileSync(join(root, 'CLAUDE.md'), 'utf8'), /not-a-capability/);
  });

  it('fails when the markers are missing', () => {
    const root = repository({ mapText: map(entry('orders')), agentText: '# Project\n' });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /markers are missing/);
  });

  it('checks every glossary term is spoken or declared', () => {
    const glossary =
      '\n## Glossary\n\n- **Order** — a purchase.\n- **Refunds** — money back.\n- **Pod** — a vending unit.\n';
    const root = repository({
      mapText: map(entry('orders')),
      agentText: agent(glossary),
      glossaryFile: 'CLAUDE.md',
    });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /"Pod" is spoken by no capability/);
    assert.doesNotMatch(result.stderr, /"Order"/, 'spoken in a Language line');
    assert.doesNotMatch(result.stderr, /"Refunds"/, 'listed under Declared, not built');
  });

  it('fails when the glossary has no entries', () => {
    const root = repository({
      mapText: map(entry('orders')),
      agentText: agent('\n## Glossary\n\nNothing yet.\n'),
      glossaryFile: 'CLAUDE.md',
    });
    const result = run(root, ['--fix']);
    assert.equal(result.status, 1);
    assert.match(result.stderr, /no "- \*\*Term\*\*" entries/);
  });
});
