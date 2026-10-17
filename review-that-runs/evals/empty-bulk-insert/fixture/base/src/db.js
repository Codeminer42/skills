// In-memory stand-in for the SQL client. Mirrors its API and its errors.
export class EmptyInsert extends Error {
  constructor() {
    super('the query is empty')
    this.name = 'EmptyInsert'
  }
}

export function createDb() {
  const tables = { members: [], loans: [] }
  return {
    tables,
    insertMany(table, rows) {
      if (rows.length === 0) throw new EmptyInsert()
      tables[table].push(...rows)
      return rows.length
    },
    select(table, predicate = () => true) {
      return tables[table].filter(predicate)
    },
  }
}
