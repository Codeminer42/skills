import { test } from 'node:test'
import assert from 'node:assert/strict'
import { Table } from '../src/query.js'

const seed = () =>
  new Table([
    { id: 1, desk: 'A1', floor: 2 },
    { id: 2, desk: 'B4', floor: 3 },
    { id: 3, desk: 'C2', floor: 2 },
  ])

test('where filters and paginate counts the full match', () => {
  const page = seed().query().where('floor', 2).orderBy('id', 'desc').paginate(1, 1)
  assert.equal(page.total, 2)
  assert.deepEqual(page.rows.map((row) => row.id), [3])
})

test('clone keeps the steps but not later ones', () => {
  const base = seed().query().where('floor', 2)
  const copy = base.clone()
  base.where('desk', 'A1')
  assert.equal(copy.all().length, 2)
  assert.equal(base.all().length, 1)
})

test('update and del touch only matching rows', () => {
  const table = seed()
  assert.equal(table.query().where('floor', 3).update({ floor: 4 }), 1)
  assert.equal(table.query().where('floor', 2).del(), 2)
  assert.deepEqual(table.rows, [{ id: 2, desk: 'B4', floor: 4 }])
})
