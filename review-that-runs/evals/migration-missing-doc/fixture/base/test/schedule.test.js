import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createDb } from '../src/db.js'
import { frontDeskList, markNoShows, missedVisits } from '../src/schedule.js'

const db = () =>
  createDb([
    { id: 1, day: '2026-03-02', time: '10:00', status: 'booked' },
    { id: 2, day: '2026-03-02', time: '09:00', status: 'checked_in' },
    { id: 3, day: '2026-03-02', time: '08:00', status: 'no_show' },
    { id: 4, day: '2026-03-02', time: '08:30', status: 'done' },
  ])

test('front desk sees who is still expected, earliest first', () => {
  assert.deepEqual(frontDeskList(db(), '2026-03-02').map((row) => row.id), [2, 1])
})

test('closing the day marks the visits still booked', () => {
  const today = db()
  markNoShows(today, '2026-03-02')
  assert.deepEqual(missedVisits(today).map((row) => row.id), [1, 3])
})
