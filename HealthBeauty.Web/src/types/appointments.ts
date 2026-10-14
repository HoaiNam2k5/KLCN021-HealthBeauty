export interface AppointmentListResponse {
  items: Appointment[]
  totalCount: number
  page: number
  pageSize: number
}

export interface AppointmentFilters {
  from?: string
  to?: string
  status?: string
  staffId?: number
  keyword?: string
  page?: number
  pageSize?: number
}

export interface AppointmentItem {
  id: number
  serviceId: number
  serviceName: string
  comboId: number | null
  expectedPrice: number
  durationMinutes: number
}

export interface Appointment {
  id: number
  customerId: number
  staffId: number | null
  appointmentAt: string
  status: string
  note: string | null
  items: AppointmentItem[]
}

export interface Staff {
  nhanVienId: number
  hoTen: string
  chucVu: string | null
  chuyenMon: string | null
  soDienThoai: string | null
  ngayVaoLam: string | null
}

export interface Customer {
  id: number
  fullName: string
  phone: string | null
  gender: string | null
  rewardPoints: number
}

export interface AppointmentItemRequest {
  serviceId: number
  comboId: number | null
  expectedPrice: number
}

export interface CreateAppointmentRequest {
  appointmentAt: string
  items: AppointmentItemRequest[]
  note: string | null
  customerId: number
  staffId: number | null
}

export interface AppointmentUpdateRequest {
  appointmentAt: string
  staffId: number | null
  note: string | null
}

export interface AppointmentStatusRequest {
  status: string
}

export interface AvailableSlot {
  nhanVienId: number
  gioBatDau: string
  gioKetThuc: string
}

export function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? value as T[] : []
}

export function asAvailableSlots(value: unknown): AvailableSlot[] {
  if (Array.isArray(value)) return value.filter(isAvailableSlot)
  if (typeof value === 'object' && value !== null && 'value' in value && Array.isArray(value.value)) {
    return value.value.filter(isAvailableSlot)
  }
  return []
}

export interface AppointmentDetail {
  lichHenId: number
  khachHang: { khachHangId: number; hoTen: string; soDienThoai: string | null } | null
  nhanVien: { nhanVienId: number; hoTen: string; chuyenMon: string | null } | null
}

function isAvailableSlot(value: unknown): value is AvailableSlot {
  return typeof value === 'object' && value !== null && 'nhanVienId' in value && typeof value.nhanVienId === 'number'
    && 'gioBatDau' in value && typeof value.gioBatDau === 'string'
    && 'gioKetThuc' in value && typeof value.gioKetThuc === 'string'
}
