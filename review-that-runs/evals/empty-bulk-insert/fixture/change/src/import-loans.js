import { readFileSync } from 'node:fs'
import { createDb } from './db.js'

// Loads a loans export into the database. Loans can reference members this branch has
// never seen (they joined at another branch); those get a placeholder member row so the
// loan still has someone to point at.
export function importLoans(db, loans) {
  const inserted = db.insertMany('loans', loans)

  const known = new Set(db.select('members').map((member) => member.id))
  const unknownIds = [...new Set(loans.map((loan) => loan.memberId))].filter((id) => !known.has(id))
  db.insertMany(
    'members',
    unknownIds.map((id) => ({ id, name: `Visiting member ${id}`, placeholder: true }))
  )

  return { loans: inserted, placeholders: unknownIds.length }
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const db = createDb()
  db.insertMany('members', JSON.parse(readFileSync(process.argv[2] ?? 'fixtures/members.json', 'utf8')))
  const loans = JSON.parse(readFileSync(process.argv[3] ?? 'fixtures/loans.json', 'utf8'))
  console.log(importLoans(db, loans))
}
