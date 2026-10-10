import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createDb, EmptyInsert } from '../src/db.js'

test('insertMany stores rows and refuses an empty list', () => {
  const db = createDb()
  assert.equal(db.insertMany('members', [{ id: 1 }]), 1)
  assert.throws(() => db.insertMany('members', []), EmptyInsert)
})
