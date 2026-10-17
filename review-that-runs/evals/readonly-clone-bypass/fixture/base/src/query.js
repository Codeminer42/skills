// A tiny query builder over an in-memory table, shaped like the SQL builders it stands in for.
export class Query {
  constructor(table, steps = []) {
    this.table = table
    this.steps = steps
  }

  where(field, value) {
    this.steps.push((rows) => rows.filter((row) => row[field] === value))
    return this
  }

  orderBy(field, direction = 'asc') {
    const sign = direction === 'desc' ? -1 : 1
    this.steps.push((rows) => [...rows].sort((a, b) => (a[field] > b[field] ? sign : -sign)))
    return this
  }

  clone() {
    return new Query(this.table, [...this.steps])
  }

  all() {
    return this.steps.reduce((rows, step) => step(rows), this.table.rows)
  }

  paginate(page, perPage) {
    const total = this.clone().all().length
    const start = (page - 1) * perPage
    return { total, rows: this.all().slice(start, start + perPage) }
  }

  update(changes) {
    const hit = new Set(this.all())
    this.table.rows = this.table.rows.map((row) => (hit.has(row) ? { ...row, ...changes } : row))
    return hit.size
  }

  del() {
    const hit = new Set(this.all())
    this.table.rows = this.table.rows.filter((row) => !hit.has(row))
    return hit.size
  }
}

export class Table {
  constructor(rows = []) {
    this.rows = rows
  }

  insert(row) {
    this.rows.push(row)
    return row
  }

  query() {
    return new Query(this)
  }
}
