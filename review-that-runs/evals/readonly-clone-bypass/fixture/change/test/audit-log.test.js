import { test, beforeEach } from 'node:test'
import assert from 'node:assert/strict'
import { auditQuery, auditTable, entriesFor, record, AuditEntryImmutable } from '../src/audit-log.js'

beforeEach(() => {
  auditTable.rows = []
  record('ana', 'book', 'desk:A1', '2026-03-01T09:00:00Z')
  record('ana', 'cancel', 'desk:A1', '2026-03-01T09:30:00Z')
  record('raj', 'book', 'desk:B4', '2026-03-01T10:00:00Z')
})

test('entriesFor pages one actor, newest first', () => {
  const page = entriesFor('ana', 1, 1)
  assert.equal(page.total, 2)
  assert.equal(page.rows[0].action, 'cancel')
})

test('update is refused', () => {
  assert.throws(() => auditQuery().where('actor', 'ana').update({ actor: 'x' }), AuditEntryImmutable)
  assert.equal(auditTable.rows[0].actor, 'ana')
})

test('del is refused', () => {
  assert.throws(() => auditQuery().del(), AuditEntryImmutable)
  assert.equal(auditTable.rows.length, 3)
})
