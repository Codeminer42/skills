import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createDb } from '../src/db.js'
import { up, down } from '../migrations/002_rename_no_show_to_missed.js'

test('002 renames no_show to missed and back', () => {
  const db = createDb([
    { id: 1, status: 'no_show' },
    { id: 2, status: 'done' },
  ])
  up(db)
  assert.deepEqual(db.appointments.map((row) => row.status), ['missed', 'done'])
  down(db)
  assert.deepEqual(db.appointments.map((row) => row.status), ['no_show', 'done'])
})
