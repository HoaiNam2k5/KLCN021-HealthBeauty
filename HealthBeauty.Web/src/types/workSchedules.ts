export interface WorkScheduleResponse {
  lichLamViecId: number
  nhanVienId: number
  staffName?: string
  ngayLam: string
  gioBatDau: string
  gioKetThuc: string
  trangThai: string
}

export interface WorkSchedule {
  id: number
  lichLamViecId: number
  nhanVienId: number
  staffName: string
  ngayLam: string
  gioBatDau: string
  gioKetThuc: string
  trangThai: string
}

export interface WorkScheduleRequest {
  staffId: number
  workDate: string
  startAt: string
  endAt: string
  status: string
}

export function mapWorkSchedule(response: WorkScheduleResponse): WorkSchedule {
  return { ...response, staffName: response.staffName ?? 'Lịch của tôi', id: response.lichLamViecId }
}

export function asWorkSchedules(value: unknown): WorkSchedule[] {
  if (!Array.isArray(value)) return []
  return value.filter((item): item is WorkScheduleResponse => {
    return typeof item === 'object' && item !== null &&
      'lichLamViecId' in item && typeof item.lichLamViecId === 'number' &&
      'nhanVienId' in item && typeof item.nhanVienId === 'number' &&
      'ngayLam' in item && typeof item.ngayLam === 'string' &&
      'gioBatDau' in item && typeof item.gioBatDau === 'string' &&
      'gioKetThuc' in item && typeof item.gioKetThuc === 'string'
  }).map(mapWorkSchedule)
}

export function mapWorkScheduleRequest(values: WorkScheduleRequest): WorkScheduleRequest {
  return {
    staffId: values.staffId,
    workDate: values.workDate,
    startAt: values.startAt.length === 5 ? `${values.startAt}:00` : values.startAt,
    endAt: values.endAt.length === 5 ? `${values.endAt}:00` : values.endAt,
    status: values.status,
  }
}

export function hasScheduleConflict(schedules: WorkSchedule[], candidate: WorkScheduleRequest, excludedId?: number): boolean {
  const start = candidate.startAt.slice(0, 5)
  const end = candidate.endAt.slice(0, 5)
  return schedules.some((schedule) => schedule.id !== excludedId && schedule.nhanVienId === candidate.staffId && schedule.ngayLam === candidate.workDate && start < schedule.gioKetThuc.slice(0, 5) && end > schedule.gioBatDau.slice(0, 5))
}

export function asScheduleStaffList(value: unknown): { nhanVienId: number; hoTen: string }[] {
  if (!Array.isArray(value)) return []
  return value.filter((item): item is { nhanVienId: number; hoTen: string } => typeof item === 'object' && item !== null && 'nhanVienId' in item && typeof item.nhanVienId === 'number' && 'hoTen' in item && typeof item.hoTen === 'string')
}
