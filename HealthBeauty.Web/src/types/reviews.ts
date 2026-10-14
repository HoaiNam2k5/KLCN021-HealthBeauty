export interface Review {
  trangThai: 'HienThi' | 'ChoDuyet'
  danhGiaId: number
  hoaDonId: number
  soSao: number
  binhLuan: string | null
  ngayDanhGia: string
}

export interface ReviewInvoice {
  id: number
  customerId: number
  appointmentId: number
}

export interface ReviewAppointment {
  id: number
  customerId: number
  staffId: number | null
}

export interface ReviewCustomer {
  id: number
  fullName: string | null
}

export interface ReviewStaff {
  id: number
  nhanVienId: number
  hoTen: string | null
}

export function asReviewArray(value: unknown): Review[] {
  if (Array.isArray(value)) return value as Review[]
  if (typeof value === 'object' && value !== null && 'value' in value) {
    const items: unknown = value.value
    return Array.isArray(items) ? items as Review[] : []
  }
  return []
}

export function asReviewRelatedArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (typeof value === 'object' && value !== null && 'value' in value) {
    const items: unknown = value.value
    return Array.isArray(items) ? items as T[] : []
  }
  return []
}
