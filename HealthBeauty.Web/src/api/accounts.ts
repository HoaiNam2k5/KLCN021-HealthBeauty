import api from './client'

export interface AdminAccount {
  taiKhoanId: number
  email: string
  tenTaiKhoan: string | null
  fullName: string | null
  roleId: number
  role: string
  trangThai: boolean
  khoaDen: string | null
  ngayTao: string
  lanDangNhapCuoi: string | null
}
export interface CreateAccountRequest {
  email: string
  password: string
  fullName: string
  phone?: string | null
  roleId: number
  staffId?: number
}
export async function getAccounts(keyword: string): Promise<AdminAccount[]> {
  const { data } = await api.get<AdminAccount[]>('/admin/accounts', { params: { keyword: keyword.trim() || undefined } })
  return data
}
export async function createAccount(body: CreateAccountRequest): Promise<AdminAccount> {
  const { data } = await api.post<AdminAccount>('/admin/accounts', { ...body, email: body.email.trim(), fullName: body.fullName.trim(), phone: body.phone?.trim() || null })
  return data
}
export async function assignAccountRole(id: number, roleId: number, staffId?: number): Promise<AdminAccount> {
  const { data } = await api.patch<AdminAccount>(`/admin/accounts/${id}/role`, { roleId, ...(staffId === undefined ? {} : { staffId }) })
  return data
}
export async function setAccountActive(id: number, active: boolean): Promise<void> {
  await api.patch(`/admin/accounts/${id}/status`, null, { params: { active } })
}
