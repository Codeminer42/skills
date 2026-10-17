export function createDb(appointments = []) {
  return { appointments: appointments.map((row) => ({ ...row })) }
}
