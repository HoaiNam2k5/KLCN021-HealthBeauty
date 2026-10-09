export interface AppointmentItem {
  id: number
  serviceId: number
  serviceName: string
  comboId: number | null
  expectedPrice: number
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

export interface AppointmentUpdateRequest {
  appointmentAt: string
  staffId: number | null
  note: string | null
}

export interface AppointmentStatusRequest {
  status: string
}

export interface AvailableSlot {
  [key: string]: unknown
}

export function asArray<T>(value: unknown): T[] {
  return Array.isArray(value) ? value as T[] : []
}

export function asAvailableSlots(value: unknown): AvailableSlot[] {
  return Array.isArray(value) ? value.filter((item): item is AvailableSlot => typeof item === 'object' && item !== null) : []
}
