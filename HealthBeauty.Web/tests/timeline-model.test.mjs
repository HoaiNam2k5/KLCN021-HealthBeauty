import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const source = await readFile(new URL('../src/features/appointments/timelineModel.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
const { loadTimelineAppointments, appointmentDuration, buildTimelineModel, canQuickBookTimeline, timelineCellKey } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
const day = '2026-10-27'
const range = { from: '2026-10-26T00:00:00', to: '2026-10-28T00:00:00' }
const appointment = (id = 1, changes = {}) => ({ id, customerId: 2, staffId: 4, staffName: 'KTV được phân công', appointmentAt: `${day}T09:30:00`, status: 'DaXacNhan', items: [{ durationMinutes: 90 }], ...changes })
const staff = [{ nhanVienId: 4, hoTen: 'KTV A' }]

test('timeline loads every API-clamped page and never sends table filters', async () => {
  const rows = Array.from({ length: 101 }, (_, index) => appointment(index + 1))
  const calls = []
  const result = await loadTimelineAppointments({ ...range, keyword: 'hidden customer filter', status: 'ChoXacNhan', staffId: 99 }, async filters => {
    calls.push(filters)
    const pageSize = Math.min(filters.pageSize, 100)
    return { items: rows.slice((filters.page - 1) * pageSize, filters.page * pageSize), totalCount: rows.length, page: filters.page, pageSize }
  })
  assert.equal(result.length, 101)
  assert.deepEqual(calls.map(call => call.page), [1, 2])
  assert.deepEqual(calls[0], { ...range, page: 1, pageSize: 100 })
})

test('timeline honors a smaller actual API page size and includes the last page', async () => {
  const rows = Array.from({ length: 101 }, (_, index) => appointment(index + 1))
  const pages = []
  const result = await loadTimelineAppointments(range, async filters => {
    pages.push(filters.page)
    return { items: rows.slice((filters.page - 1) * 50, filters.page * 50), totalCount: rows.length, page: filters.page, pageSize: 50 }
  })
  assert.equal(result.length, 101)
  assert.deepEqual(pages, [1, 2, 3])
})

test('incomplete pages, repeated IDs, metadata drift and malformed rows fail closed', async () => {
  const rows = Array.from({ length: 101 }, (_, index) => appointment(index + 1))
  const first = { items: rows.slice(0, 100), totalCount: 101, page: 1, pageSize: 100 }
  const second = { items: rows.slice(100), totalCount: 101, page: 2, pageSize: 100 }
  for (const bad of [
    { ...second, items: [] },
    { ...second, items: [rows[0]] },
    { ...second, totalCount: 102 },
    { ...second, pageSize: 50 },
    { ...second, page: 1 },
    { ...second, items: [appointment(101, { appointmentAt: 'invalid' })] },
    { ...second, items: [appointment(101, { staffId: undefined })] },
  ]) {
    await assert.rejects(loadTimelineAppointments(range, async filters => filters.page === 1 ? first : bad))
  }
})

test('a failed later page rejects the complete timeline rather than exposing empty slots', async () => {
  await assert.rejects(loadTimelineAppointments(range, async filters => {
    if (filters.page === 2) throw new Error('network error')
    return { items: Array.from({ length: 100 }, (_, index) => appointment(index + 1)), totalCount: 101, page: 1, pageSize: 100 }
  }), /network error/)
  assert.deepEqual(await loadTimelineAppointments(range, async () => ({ items: [], totalCount: 0, page: 1, pageSize: 100 })), [])
})

test('90 minute appointment covers continuation cells and releases its exact end boundary', () => {
  const model = buildTimelineModel(day, [appointment()], staff)
  assert.deepEqual(model.cells.get(timelineCellKey(4, 10)).map(row => row.id), [1])
  assert.equal(model.occupied.has(timelineCellKey(4, 9)), true)
  assert.equal(model.occupied.has(timelineCellKey(4, 10)), true)
  assert.equal(model.occupied.has(timelineCellKey(4, 11)), false)
  assert.equal(canQuickBookTimeline(day, 10, 4, model, true, Date.parse(`${day}T08:00:00`)), false)
  assert.equal(canQuickBookTimeline(day, 11, 4, model, true, Date.parse(`${day}T08:00:00`)), true)
})

test('overnight continuation and out-of-hours appointments remain visible and busy', () => {
  const previous = appointment(1, { appointmentAt: '2026-10-26T23:30:00', items: [{ durationMinutes: 90 }] })
  const late = appointment(2, { appointmentAt: `${day}T22:30:00` })
  const model = buildTimelineModel(day, [previous, late], staff)
  assert.equal(model.hours[0], 0)
  assert.equal(model.hours.at(-1), 23)
  assert.deepEqual(model.appointments.map(row => row.id), [1, 2])
  assert.equal(model.occupied.has(timelineCellKey(4, 0)), true)
  assert.equal(model.occupied.has(timelineCellKey(4, 1)), false)
  assert.equal(model.occupied.has(timelineCellKey(4, 23)), true)
})

test('Staff without a directory still sees assigned resource columns using scoped names', () => {
  const model = buildTimelineModel(day, [appointment(), appointment(2, { staffId: 9, staffName: undefined }), appointment(3, { staffId: null })], [])
  assert.deepEqual(model.columns, [
    { id: 4, name: 'KTV được phân công' }, { id: 9, name: 'Nhân viên #9' }, { id: null, name: 'Chưa phân công' },
  ])
  assert.equal(model.cells.get(timelineCellKey(4, 9))[0].id, 1)
})

test('cancelled cards remain visible but do not occupy continuation cells', () => {
  const model = buildTimelineModel(day, [appointment(1, { status: 'DaHuy' })], staff)
  assert.equal(model.cells.get(timelineCellKey(4, 9))[0].id, 1)
  assert.equal(model.cells.has(timelineCellKey(4, 10)), false)
  assert.equal(model.occupied.size, 0)
  assert.equal(canQuickBookTimeline(day, 9, 4, model, true, Date.parse(`${day}T08:00:00`)), true)
})

test('duration sums repeated combo components with the same fallback as the API', () => {
  assert.equal(appointmentDuration(appointment(1, { items: [{ durationMinutes: 45 }, { durationMinutes: 45 }, { durationMinutes: 60 }] })), 150)
  assert.equal(appointmentDuration(appointment(1, { items: [] })), 30)
  assert.equal(appointmentDuration(appointment(1, { items: [{ durationMinutes: 0 }, { durationMinutes: -1 }] })), 60)
})

test('loading, refreshing, failures, current and past times never offer quick booking', () => {
  const model = buildTimelineModel(day, [], staff)
  assert.equal(canQuickBookTimeline(day, 10, 4, model, false, Date.parse(`${day}T08:00:00`)), false)
  assert.equal(canQuickBookTimeline(day, 10, 4, model, true, Date.parse(`${day}T10:00:00`)), false)
  assert.equal(canQuickBookTimeline(day, 9, 4, model, true, Date.parse(`${day}T10:00:00`)), false)
  assert.equal(canQuickBookTimeline(day, 11, 4, model, true, Date.parse(`${day}T10:00:00`)), true)
})
