// layout: { bins: { [binCode]: { productId } }, catalog: { [productId]: { name } } }
export function plannedProducts(layout) {
  return Object.entries(layout.bins).map(([bin, { productId }]) => ({
    bin,
    id: productId,
    name: layout.catalog[productId].name,
  }))
}
