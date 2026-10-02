export function up(db) {
  for (const row of db.appointments) {
    if (row.status === 'no_show') row.status = 'missed'
  }
}

export function down(db) {
  for (const row of db.appointments) {
    if (row.status === 'missed') row.status = 'no_show'
  }
}
