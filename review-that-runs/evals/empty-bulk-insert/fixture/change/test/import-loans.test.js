import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createDb } from '../src/db.js'
import { importLoans } from '../src/import-loans.js'

test('imports loans and adds a placeholder for each unknown member', () => {
  const db = createDb()
  db.insertMany('members', [{ id: 1, name: 'Ines' }])
  const result = importLoans(db, [
    { id: 101, memberId: 1, isbn: 'a' },
    { id: 102, memberId: 7, isbn: 'b' },
    { id: 103, memberId: 7, isbn: 'c' },
  ])
  assert.deepEqual(result, { loans: 3, placeholders: 1 })
  assert.equal(db.select('members', (m) => m.placeholder).length, 1)
})
