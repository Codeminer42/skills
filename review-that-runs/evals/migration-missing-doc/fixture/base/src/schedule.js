/**
 * Appointment statuses, in the order a visit moves through them. `no_show` is only ever
 * written by `markNoShows` below; front desk never sets it by hand.
 */
export const STATUSES = ['booked', 'checked_in', 'done', 'no_show']

/**
 * The day's list for the front desk: everything still actionable, earliest first.
 * Finished and missed visits are left out so the list only shows who is still expected.
 */
export function frontDeskList(db, day) {
  return db.appointments
    .filter((row) => row.day === day)
    .filter((row) => row.status === 'booked' || row.status === 'checked_in')
    .sort((a, b) => a.time.localeCompare(b.time))
}

/**
 * Closes out a day: every visit still `booked` once the day is over becomes `no_show`.
 * Runs from the end-of-day button, after the last slot.
 */
export function markNoShows(db, day) {
  for (const row of db.appointments) {
    if (row.day === day && row.status === 'booked') row.status = 'no_show'
  }
}

/**
 * Visits nobody showed up for, for the weekly follow-up calls.
 * Uses the status, never the clock, so a late check-in counts as a visit.
 */
export function missedVisits(db) {
  return db.appointments.filter((row) => row.status === 'no_show')
}
