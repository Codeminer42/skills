import { plannedProducts } from './layout.js'

// scan: { counts: [{ bin, productId, qty }], products: [{ id, name }] }
// Returns one label per scanned bin, e.g. "A01 · Oat Milk 1L · 3".
export function binLabels(layout, scan) {
  const products = new Map()
  for (const product of plannedProducts(layout)) {
    products.set(product.id, product)
  }
  for (const product of scan.products) {
    products.set(product.id, product)
  }

  return scan.counts.map(({ bin, productId, qty }) => {
    const name = products.get(productId)?.name ?? 'Unnamed item'
    return `${bin} · ${name} · ${qty}`
  })
}
