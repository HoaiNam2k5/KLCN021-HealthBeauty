import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'
import dayjs from 'dayjs'

// Helpers contain type-only imports; compile with the project's TypeScript without a second test toolchain.
async function loadModule(path) {
  const source = await readFile(new URL(path, import.meta.url), 'utf8')
  const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
  return import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
}
const booking = await loadModule('../src/features/appointments/appointmentContract.ts')
const { asAvailableSlots } = await loadModule('../src/types/appointments.ts')
const { asWorkSchedules } = await loadModule('../src/types/workSchedules.ts')
const { buildInvoiceDraft, eligibleInvoiceAppointments } = await loadModule('../src/features/billing/invoiceDraft.ts')
const services = [{ id: 1, name: 'Facial', price: 100000, durationMinutes: 45 }, { id: 2, name: 'Massage', price: 200000, durationMinutes: 60 }]
const combos = [{ id: 7, name: 'Care', price: 350000, items: [{ serviceId: 1, quantity: 2 }, { serviceId: 2, quantity: 1 }] }]
const component = (serviceId, comboId = 7) => ({ serviceId, comboId })
const appointment = (items, status = 'HoanThanh') => ({ items, status })

test('combo contains every service at its configured quantity', () => {
  assert.deepEqual(booking.bookingItems(['combo:7'], services, combos).map(x => x.serviceId), [1, 1, 2])
})
test('availability duration includes all combo components and standalone services', () => {
  assert.equal(booking.bookingDuration(['combo:7', 'service:2'], services, combos), 210)
})
test('a missing component blocks partial combo booking', () => {
  assert.throws(() => booking.bookingItems(['combo:7'], services.slice(0, 1), combos))
})
test('invalid combo quantities cannot produce booking items', () => {
  assert.throws(() => booking.bookingItems(['combo:7'], services, [{ ...combos[0], items: [{ serviceId: 1, quantity: 0 }] }]))
})
test('local wall-clock appointment time is preserved', () => {
  assert.equal(booking.localAppointmentDateTime(dayjs('2026-10-20'), dayjs('2000-01-01T14:30:00')), '2026-10-20T14:30:00')
})
test('arrived and in-progress appointments cannot be rescheduled', () => {
  assert.equal(booking.canReschedule('DaDen'), false)
  assert.equal(booking.canReschedule('DangThucHien'), false)
  assert.equal(booking.canReschedule('DaXacNhan'), true)
})
test('in-progress and finished appointments cannot be cancelled', () => {
  assert.equal(booking.canCancel('DangThucHien'), false)
  assert.equal(booking.canCancel('HoanThanh'), false)
  assert.equal(booking.canCancel('DaDen'), true)
})
test('actual API time-only slot shape is accepted', () => {
  const slot = { nhanVienId: 3, gioBatDau: '14:00:00', gioKetThuc: '16:30:00' }
  assert.deepEqual(asAvailableSlots([slot, null, { time: '14:00' }]), [slot])
})
test('Staff self schedule without staffName is mapped', () => {
  const [schedule] = asWorkSchedules([{ lichLamViecId: 8, nhanVienId: 3, ngayLam: '2026-10-20', gioBatDau: '09:00:00', gioKetThuc: '18:00:00', trangThai: 'HoatDong' }])
  assert.equal(schedule.id, 8)
  assert.equal(schedule.staffName, 'Lịch của tôi')
})
test('repeated complete combos become multiple invoice copies with combo price', () => {
  const draft = buildInvoiceDraft(appointment([component(1), component(1), component(2), component(1), component(1), component(2)]), services, combos)
  assert.deepEqual(draft.items, [{ serviceId: null, comboId: 7, quantity: 2 }])
  assert.equal(draft.subtotal, 700000)
})
test('standalone and combo components produce separate invoice lines', () => {
  const draft = buildInvoiceDraft(appointment([component(1), component(1), component(2), component(2, null), component(2, null)]), services, combos)
  assert.equal(draft.subtotal, 750000)
  assert.deepEqual(draft.items, [{ serviceId: 2, comboId: null, quantity: 2 }, { serviceId: null, comboId: 7, quantity: 1 }])
})
test('incomplete combo quantities block invoice creation', () => {
  assert.throws(() => buildInvoiceDraft(appointment([component(1), component(2)]), services, combos))
})
test('unfinished appointment blocks invoice creation', () => {
  assert.throws(() => buildInvoiceDraft(appointment([component(1)], 'DangThucHien'), services, combos))
})
test('empty appointment blocks invoice creation', () => {
  assert.throws(() => buildInvoiceDraft(appointment([]), services, combos))
})
test('large standalone quantities respect backend per-line limit', () => {
  const draft = buildInvoiceDraft(appointment(Array.from({ length: 101 }, () => component(1, null))), services, combos)
  assert.deepEqual(draft.items.map(x => x.quantity), [100, 1])
  assert.equal(draft.subtotal, 10100000)
})

test('only completed uninvoiced appointments are eligible, regardless of invoice payment status', () => {
  const rows = [1, 2, 3, 4, 5].map(id => ({ id, ...appointment([component(1)], id < 4 ? 'HoanThanh' : id === 4 ? 'DangThucHien' : 'DaHuy') }))
  assert.deepEqual(eligibleInvoiceAppointments(rows, [{ appointmentId: 1, status: 'DaThanhToan' }, { appointmentId: 2, status: 'ChuaThanhToan' }]).map(x => x.id), [3])
})
test('unequal combo copy ratios cannot become a valid invoice', () => {
  assert.throws(() => buildInvoiceDraft(appointment([component(1), component(1), component(1), component(1), component(2)]), services, combos))
})
test('unknown catalog items block invoice creation', () => {
  assert.throws(() => buildInvoiceDraft(appointment([component(99, null)]), services, combos))
  assert.throws(() => buildInvoiceDraft(appointment([component(1, 99)]), services, combos))
})
test('extra services cannot be charged as part of a combo', () => {
  assert.throws(() => buildInvoiceDraft(appointment([component(1), component(1), component(2), component(99)]), services, combos))
})

const staffContract = await loadModule('../src/types/customersStaff.ts')
const staffLinks = await loadModule('../src/features/customers-staff/staffAccountOptions.ts')
const staffProfile = { fullName: ' Nhân viên ', position: ' Staff ', specialty: ' Massage ', phone: ' 0901234567 ', hireDate: '2026-10-20' }

test('creating a staff account trims profile and email but preserves password exactly', () => {
  const body = staffContract.mapCreateStaffRequest({ ...staffProfile, email: ' staff@example.com ', password: ' password123 ' })
  assert.equal(body.fullName, 'Nhân viên')
  assert.equal(body.email, 'staff@example.com')
  assert.equal(body.password, ' password123 ')
})

test('editing a staff profile never includes retained credentials', () => {
  const body = staffContract.mapStaffRequest({ ...staffProfile, email: 'staff@example.com', password: 'password123' })
  assert.equal('email' in body, false)
  assert.equal('password' in body, false)
})

test('employee selection permits unlinked and current account profiles but blocks other accounts', () => {
  const staff = [
    { nhanVienId: 4, hoTen: 'Nam', taiKhoanId: null },
    { nhanVienId: 5, hoTen: 'Staff', taiKhoanId: 4 },
    { nhanVienId: 6, hoTen: 'Other', taiKhoanId: 8 },
  ]
  assert.deepEqual(staffLinks.staffAccountOptions(staff, 4).map((item) => item.disabled), [false, false, true])
  assert.deepEqual(staffLinks.staffAccountOptions(staff).map((item) => item.disabled), [false, true, true])
})
