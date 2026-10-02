import { Table } from './query.js'

export const auditTable = new Table()

export function record(actor, action, target, at = new Date().toISOString()) {
  return auditTable.insert({ id: auditTable.rows.length + 1, actor, action, target, at })
}

export class AuditEntryImmutable extends Error {
  constructor(method) {
    super(`Audit entries cannot be changed (${method} refused)`)
    this.name = 'AuditEntryImmutable'
  }
}

const WRITES = ['update', 'del']

// Every read of the audit log goes through here. Writes throw before they touch a row,
// so a forgotten await or a stray call can never alter evidence.
export function auditQuery() {
  const query = auditTable.query()
  for (const method of WRITES) {
    Object.defineProperty(query, method, {
      value: () => {
        throw new AuditEntryImmutable(method)
      },
    })
  }
  return query
}

export function entriesFor(actor, page = 1, perPage = 20) {
  return auditQuery().where('actor', actor).orderBy('id', 'desc').paginate(page, perPage)
}
