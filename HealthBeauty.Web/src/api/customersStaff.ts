import api from './client'
import { asArray, mapStaff, mapStaffList, type Customer, type CreateStaffRequest, type Staff, type StaffRequest, type StaffResponse, type UpdateCustomerRequest } from '../types/customersStaff'

export async function getCustomers(keyword = ''): Promise<Customer[]> {
  const { data } = await api.get<unknown>('/customers', { params: { keyword: keyword.trim() } })
  return asArray<Customer>(data)
}

export async function updateCustomer(id: number, body: UpdateCustomerRequest): Promise<void> {
  await api.put(`/customers/${id}`, { ...body, fullName: body.fullName.trim(), phone: body.phone?.trim() || null, gender: body.gender?.trim() || null })
}

export async function getStaff(): Promise<Staff[]> {
  const { data } = await api.get<unknown>('/staff')
  return mapStaffList(data)
}

export async function getStaffById(id: number): Promise<Staff> {
  const { data } = await api.get<unknown>(`/staff/${id}`)
  if (typeof data !== 'object' || data === null || !('nhanVienId' in data)) {
    throw new Error('Phản hồi chi tiết nhân viên không hợp lệ.')
  }
  return mapStaff(data as StaffResponse)
}

export async function createStaff(body: CreateStaffRequest): Promise<void> {
  await api.post('/staff', body)
}

export async function updateStaff(id: number, body: StaffRequest): Promise<void> {
  await api.put(`/staff/${id}`, body)
}

export async function deleteStaff(id: number): Promise<void> {
  await api.delete(`/staff/${id}`)
}

export async function saveStaff(input: { id?: number; body: StaffRequest }): Promise<void> {
  if (input.id === undefined) {
    if (!('email' in input.body) || !('password' in input.body) || typeof input.body.email !== 'string' || typeof input.body.password !== 'string') {
      throw new Error('Nhập email và mật khẩu để tạo tài khoản nhân viên.')
    }
    await createStaff(input.body as CreateStaffRequest)
  }
  else await updateStaff(input.id, input.body)
}
