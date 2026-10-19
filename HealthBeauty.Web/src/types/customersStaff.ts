export interface Customer {
  id: number
  fullName: string | null
  phone: string | null
  gender: string | null
  rewardPoints: number
}

export interface UpdateCustomerRequest {
  fullName: string
  phone: string | null
  gender: string | null
}

export interface StaffResponse {
  nhanVienId: number
  taiKhoanId?: number | null
  hoTen: string | null
  chucVu: string | null
  chuyenMon: string | null
  soDienThoai: string | null
  ngayVaoLam: string
}

export interface Staff {
  id: number
  nhanVienId: number
  taiKhoanId?: number | null
  hoTen: string | null
  chucVu: string | null
  chuyenMon: string | null
  soDienThoai: string | null
  ngayVaoLam: string
}

export interface StaffRequest {
  fullName: string
  position: string
  specialty: string
  phone: string
  hireDate: string
}

export interface CreateStaffRequest extends StaffRequest {
  email: string
  password: string
}

export function mapCreateStaffRequest(values: CreateStaffRequest): CreateStaffRequest {
  return { ...mapStaffRequest(values), email: values.email.trim(), password: values.password }
}

export function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (typeof value === 'object' && value !== null && 'items' in value) {
    const items: unknown = value.items
    if (Array.isArray(items)) return items as T[]
  }
  return []
}

export function mapStaff(response: StaffResponse): Staff {
  return { ...response, id: response.nhanVienId }
}

export function mapStaffList(value: unknown): Staff[] {
  return asArray<StaffResponse>(value).map(mapStaff)
}

export function mapStaffRequest(values: StaffRequest): StaffRequest {
  return {
    fullName: values.fullName.trim(),
    position: values.position.trim(),
    specialty: values.specialty.trim(),
    phone: values.phone.trim(),
    hireDate: values.hireDate,
  }
}

export function isValidPhone(value: string): boolean {
  return /^\+?[0-9][0-9\s().-]{7,17}$/.test(value.trim())
}
