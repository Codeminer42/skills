/**
 * Splits `patient` ("Ana Souza") into `firstName` and `lastName` so reminders can greet
 * people by first name. Everything after the first space is the last name.
 *
 * down() joins them back with one space, so a name that had double spaces comes back
 * with one.
 */
export function up(db) {
  for (const row of db.appointments) {
    const [firstName, ...rest] = row.patient.split(' ')
    row.firstName = firstName
    row.lastName = rest.join(' ')
    delete row.patient
  }
}

export function down(db) {
  for (const row of db.appointments) {
    row.patient = [row.firstName, row.lastName].filter(Boolean).join(' ')
    delete row.firstName
    delete row.lastName
  }
}
