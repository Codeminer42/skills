import { test } from 'node:test'
import assert from 'node:assert/strict'
import { binLabels } from '../src/bin-labels.js'

const layout = {
  bins: { A01: { productId: 'p1' }, A02: { productId: 'p2' } },
  catalog: { p1: { name: 'Oat Milk 1L' }, p2: { name: 'Rye Bread' } },
}

test('labels each scanned bin with its product and count', () => {
  const scan = {
    counts: [
      { bin: 'A01', productId: 'p1', qty: 3 },
      { bin: 'A02', productId: 'p2', qty: 0 },
    ],
    products: [
      { id: 'p1', name: 'Oat Milk 1L' },
      { id: 'p2', name: 'Rye Bread' },
    ],
  }
  assert.deepEqual(binLabels(layout, scan), ['A01 · Oat Milk 1L · 3', 'A02 · Rye Bread · 0'])
})

test('names stock that sits in a bin the layout does not plan', () => {
  const scan = {
    counts: [{ bin: 'B07', productId: 'p9', qty: 5 }],
    products: [{ id: 'p9', name: 'Sparkling Water' }],
  }
  assert.deepEqual(binLabels(layout, scan), ['B07 · Sparkling Water · 5'])
})

test('falls back when nobody knows the product', () => {
  const scan = { counts: [{ bin: 'C01', productId: 'p404', qty: 1 }], products: [] }
  assert.deepEqual(binLabels(layout, scan), ['C01 · Unnamed item · 1'])
})
