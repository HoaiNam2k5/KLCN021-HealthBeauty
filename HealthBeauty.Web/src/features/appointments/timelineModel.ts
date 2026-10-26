import type { Appointment, AppointmentFilters, AppointmentListResponse, Staff } from '../../types/appointments'

export interface TimelineColumn { id: number | null; name: string }
export interface TimelineModel {
  appointments: Appointment[]
  columns: TimelineColumn[]
  hours: number[]
  cells: Map<string, Appointment[]>
  occupied: Set<string>
}

export const timelineCellKey = (staffId: number | null, hour: number) => `${staffId ?? 'null'}_${hour}`

// The API clamps pageSize to 100. Never use a partial page as evidence that a slot is empty.
export async function loadTimelineAppointments(
  range: Pick<AppointmentFilters, 'from' | 'to'>,
  getPage: (filters: AppointmentFilters) => Promise<AppointmentListResponse>,
): Promise<Appointment[]> {
  const all: Appointment[] = []
  const ids = new Set<number>()
  let total: number | undefined
  let size = 100
  for (let page = 1; ; page++) {
    const response = await getPage({ from: range.from, to: range.to, page, pageSize: size })
    if (!Number.isSafeInteger(response.totalCount) || response.totalCount < 0
      || response.page !== page || !Number.isSafeInteger(response.pageSize) || response.pageSize < 1
      || response.pageSize > 100 || !Array.isArray(response.items)
      || (page > 1 && response.pageSize !== size)
      || (total !== undefined && response.totalCount !== total)) {
      throw new Error('Danh sách lịch hẹn đang thay đổi hoặc chưa đầy đủ. Vui lòng tải lại ma trận.')
    }
    total = response.totalCount
    size = response.pageSize
    const expected = Math.min(size, Math.max(0, total - (page - 1) * size))
    if (response.items.length !== expected) throw new Error('Chưa tải đủ lịch hẹn. Vui lòng tải lại ma trận.')
    for (const appointment of response.items) {
      if (!Number.isSafeInteger(appointment.id) || appointment.id <= 0 || ids.has(appointment.id)
        || !Number.isFinite(Date.parse(appointment.appointmentAt)) || !Array.isArray(appointment.items)
        || (appointment.staffId !== null && (!Number.isSafeInteger(appointment.staffId) || appointment.staffId <= 0))) {
        throw new Error('Dữ liệu lịch hẹn chưa nhất quán. Vui lòng tải lại ma trận.')
      }
      ids.add(appointment.id)
      all.push(appointment)
    }
    if (all.length === total) return all
  }
}

export function appointmentDuration(appointment: Appointment): number {
  // API items already contain each service/each repeated combo component separately.
  return appointment.items.length === 0 ? 30 : appointment.items.reduce((minutes, item) =>
    minutes + (Number.isFinite(item.durationMinutes) && item.durationMinutes > 0 ? item.durationMinutes : 30), 0)
}

export function appointmentEnd(appointment: Appointment): number {
  return Date.parse(appointment.appointmentAt) + appointmentDuration(appointment) * 60000
}

export function buildTimelineModel(day: string, appointments: Appointment[], staff: Staff[]): TimelineModel {
  const dayStart = new Date(`${day}T00:00:00`).getTime()
  const nextDay = new Date(dayStart)
  nextDay.setDate(nextDay.getDate() + 1)
  const dayEnd = nextDay.getTime()
  const visible = appointments.filter(appointment => {
    const start = Date.parse(appointment.appointmentAt)
    return start < dayEnd && (appointment.status === 'DaHuy' ? start >= dayStart : appointmentEnd(appointment) > dayStart)
  }).sort((a, b) => Date.parse(a.appointmentAt) - Date.parse(b.appointmentAt) || a.id - b.id)
  const byStaff = new Map<number | null, TimelineColumn>(staff.map(person => [person.nhanVienId, { id: person.nhanVienId, name: person.hoTen }]))
  for (const appointment of visible) {
    if (!byStaff.has(appointment.staffId)) byStaff.set(appointment.staffId, {
      id: appointment.staffId,
      name: appointment.staffId === null ? 'Chưa phân công' : appointment.staffName || `Nhân viên #${appointment.staffId}`,
    })
  }
  if (byStaff.size === 0) byStaff.set(null, { id: null, name: 'Chưa phân công' })
  const cells = new Map<string, Appointment[]>()
  const occupied = new Set<string>()
  let firstHour = 8
  let lastHour = 20
  for (let hour = 0; hour < 24; hour++) {
    const slotStart = new Date(`${day}T${String(hour).padStart(2, '0')}:00:00`).getTime()
    const slotEnd = hour === 23 ? dayEnd : new Date(`${day}T${String(hour + 1).padStart(2, '0')}:00:00`).getTime()
    for (const appointment of visible) {
      const start = Date.parse(appointment.appointmentAt)
      const cancelled = appointment.status === 'DaHuy'
      const overlaps = cancelled ? start >= slotStart && start < slotEnd : start < slotEnd && appointmentEnd(appointment) > slotStart
      if (!overlaps) continue
      const key = timelineCellKey(appointment.staffId, hour)
      cells.set(key, [...(cells.get(key) ?? []), appointment])
      if (!cancelled) occupied.add(key)
      firstHour = Math.min(firstHour, hour)
      lastHour = Math.max(lastHour, hour)
    }
  }
  return { appointments: visible, columns: [...byStaff.values()], cells, occupied,
    hours: Array.from({ length: lastHour - firstHour + 1 }, (_, index) => firstHour + index) }
}

export function canQuickBookTimeline(day: string, hour: number, staffId: number | null, model: TimelineModel, ready: boolean, now: number): boolean {
  const start = Date.parse(`${day}T${String(hour).padStart(2, '0')}:00:00`)
  return ready && Number.isFinite(start) && start > now && !model.occupied.has(timelineCellKey(staffId, hour))
}
