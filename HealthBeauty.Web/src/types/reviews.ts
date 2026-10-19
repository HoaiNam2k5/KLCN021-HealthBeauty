export interface Review {
  trangThai?: 'HienThi' | 'ChoDuyet' | 'An'
  danhGiaId: number
  hoaDonId: number
  soSao: number
  binhLuan: string | null
  ngayDanhGia: string
  reply?: string | null
  repliedAt?: string | null
  tenKhachHang?: string | null
}

export interface ReviewServiceItem {
  serviceId: number | null
  serviceName: string | null
  comboId: number | null
  comboName: string | null
}

export interface ReviewManagementItem extends Review {
  trangThai: 'HienThi' | 'ChoDuyet' | 'An'
  replyAccountId: number | null
  version: string
  customerId: number
  tenKhachHang: string | null
  services: ReviewServiceItem[]
}

export interface ReviewManagementResponse {
  items: ReviewManagementItem[]
  totalCount: number
  averageRating: number
  page: number
  pageSize: number
}

export interface ReviewFilterParams {
  serviceId?: number
  from?: string
  to?: string
  stars?: number
  status?: 'HienThi' | 'ChoDuyet' | 'An'
  page?: number
  pageSize?: number
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
  if (typeof value === 'object' && value !== null) {
    if ('items' in value && Array.isArray((value as { items: unknown }).items)) {
      return (value as { items: Review[] }).items
    }
    if ('value' in value && Array.isArray((value as { value: unknown }).value)) {
      return (value as { value: Review[] }).value
    }
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
