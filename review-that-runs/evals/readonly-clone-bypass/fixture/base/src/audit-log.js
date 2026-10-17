import { Table } from './query.js'

export const auditTable = new Table()

export function record(actor, action, target, at = new Date().toISOString()) {
  return auditTable.insert({ id: auditTable.rows.length + 1, actor, action, target, at })
}
