#!/usr/bin/env node
// Compares two `claude plugin eval --json` results for the same suite: the skill as it is
// on the base branch, and the skill as the PR changes it. Prints a Markdown report and
// exits 1 when the PR's version regresses.
//
// Usage: compare-evals.mjs <base.json> <head.json> [--max-drop 0.2]
//
// A case regresses when its mean score drops by more than --max-drop, or when a grader
// that passed in most base runs fails in most head runs. Runs that errored before the
// agent started (score 0, 0 turns) make a side incomparable rather than a regression.

import { readFileSync } from 'node:fs'

const args = process.argv.slice(2)
const [basePath, headPath] = args.filter((arg) => !arg.startsWith('--'))
const dropAt = args.indexOf('--max-drop')
const maxDrop = dropAt === -1 ? 0.2 : Number(args[dropAt + 1])

if (!basePath || !headPath) {
  console.error('Usage: compare-evals.mjs <base.json> <head.json> [--max-drop 0.2]')
  process.exit(2)
}

const load = (path) => JSON.parse(readFileSync(path, 'utf8'))
const base = load(basePath)
const head = load(headPath)

const runsOf = (testCase) => testCase?.arms?.with ?? []
const neverStarted = (run) => run.turns === 0 && run.error
const majority = (passes, total) => total > 0 && passes * 2 > total

function graderRates(testCase) {
  const rates = new Map()
  for (const run of runsOf(testCase)) {
    for (const grader of run.graders ?? []) {
      const name = grader.name ?? grader.grader
      const passed = grader.passed ?? grader.pass ?? grader.verdict === 'PASS'
      const rate = rates.get(name) ?? { passes: 0, total: 0 }
      rate.total += 1
      if (passed) rate.passes += 1
      rates.set(name, rate)
    }
  }
  return rates
}

const pct = (n) => `${Math.round(n * 100)}%`
const rows = []
const regressions = []
const incomparable = []

for (const headCase of head.cases) {
  const baseCase = base.cases.find((candidate) => candidate.name === headCase.name)
  const headScore = headCase.aggregates?.score ?? 0
  const baseScore = baseCase?.aggregates?.score

  if (!baseCase) {
    rows.push(`| ${headCase.name} | new | ${pct(headScore)} | |`)
    continue
  }
  if (runsOf(baseCase).some(neverStarted) || runsOf(headCase).some(neverStarted)) {
    incomparable.push(headCase.name)
    rows.push(`| ${headCase.name} | ${pct(baseScore)} | ${pct(headScore)} | runs failed to start |`)
    continue
  }

  const notes = []
  const delta = headScore - baseScore
  if (delta < -maxDrop) notes.push(`score dropped ${pct(-delta)}`)

  const baseRates = graderRates(baseCase)
  for (const [name, headRate] of graderRates(headCase)) {
    const baseRate = baseRates.get(name)
    if (!baseRate) continue
    const wasPassing = majority(baseRate.passes, baseRate.total)
    const nowFailing = !majority(headRate.passes, headRate.total)
    if (wasPassing && nowFailing) {
      notes.push(`\`${name}\` ${baseRate.passes}/${baseRate.total} → ${headRate.passes}/${headRate.total}`)
    }
  }

  if (notes.length > 0) regressions.push(headCase.name)
  const sign = delta > 0 ? '+' : ''
  rows.push(`| ${headCase.name} | ${pct(baseScore)} | ${pct(headScore)} (${sign}${pct(delta)}) | ${notes.join('; ')} |`)
}

const verdict =
  regressions.length > 0
    ? `**Regression** in ${regressions.join(', ')}.`
    : incomparable.length > 0
      ? `No regression found, but ${incomparable.join(', ')} could not be compared.`
      : 'No regression.'

console.log(`### ${verdict}

| Case | Base | PR | Regressions |
|---|---|---|---|
${rows.join('\n')}

Base cost $${(base.costUsd ?? 0).toFixed(2)}, PR cost $${(head.costUsd ?? 0).toFixed(2)}. ${
  base.partial || head.partial ? 'At least one side is **partial** (cost ceiling or auth); treat the result as incomplete.' : ''
}`)

process.exit(regressions.length > 0 ? 1 : 0)
