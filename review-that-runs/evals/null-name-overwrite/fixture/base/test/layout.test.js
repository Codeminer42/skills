import { test } from 'node:test'
import assert from 'node:assert/strict'
import { plannedProducts } from '../src/layout.js'

test('names planned products from the store catalog', () => {
  const layout = { bins: { A01: { productId: 'p1' } }, catalog: { p1: { name: 'Oat Milk 1L' } } }
  assert.deepEqual(plannedProducts(layout), [{ bin: 'A01', id: 'p1', name: 'Oat Milk 1L' }])
})
