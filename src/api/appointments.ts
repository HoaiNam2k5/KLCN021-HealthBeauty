import api from './client'
import { asArray, asAvailableSlots, type Appointment, type AppointmentFilters, type AppointmentListResponse, type AppointmentStatusRequest, type AppointmentUpdateRequest, type AvailableSlot, type Customer, type Staff } from '../types/appointments'

export async function getAppointments(filters: AppointmentFilters = {}): Promise<AppointmentListResponse> {
  const { data } = await api.get<unknown>('/appointments', { params: filters })
  if (typeof data !== 'object' || data === null || !('items' in data) || !Array.isArray(data.items)) {
    throw new Error('Phản hồi danh sách lịch hẹn không hợp lệ.')
  }
  const response = data as Record<string, unknown>
  return {
    items: response.items as Appointment[],
    totalCount: typeof response.totalCount === 'number' ? response.totalCount : 0,
    page: typeof response.page === 'number' ? response.page : filters.page ?? 1,
    pageSize: typeof response.pageSize === 'number' ? response.pageSize : filters.pageSize ?? 20,
  }
}

export async function getAllAppointments(): Promise<Appointment[]> {
  const pageSize = 100
  const firstPage = await getAppointments({ page: 1, pageSize })
  const pages = Math.ceil(firstPage.totalCount / pageSize)
  if (pages <= 1) return firstPage.items
  const remaining = await Promise.all(Array.from({ length: pages - 1 }, (_, index) => getAppointments({ page: index + 2, pageSize })))
  return [firstPage, ...remaining].flatMap((page) => page.items)
}

export async function getStaff(): Promise<Staff[]> {
  const { data } = await api.get<unknown>('/staff')
  return asArray<Staff>(data)
}

export async function getCustomers(): Promise<Customer[]> {
  const { data } = await api.get<unknown>('/customers')
  return asArray<Customer>(data)
}

export async function getAvailableSlots(date: string, staffId?: number): Promise<AvailableSlot[]> {
  const params: Record<string, string | number> = { date }
  if (staffId !== undefined) params.staffId = staffId
  const { data } = await api.get<unknown>('/appointments/availability', { params })
  return asAvailableSlots(data)
}

export async function updateAppointment(id: number, body: AppointmentUpdateRequest): Promise<void> {
  await api.put(`/appointments/${id}`, body)
}

export async function updateAppointmentStatus(id: number, body: AppointmentStatusRequest): Promise<void> {
  await api.patch(`/appointments/${id}/status`, body)
}

export async function rescheduleAppointment(id: number, body: AppointmentUpdateRequest): Promise<void> {
  await api.post(`/appointments/${id}/reschedule`, body)
}

export async function deleteAppointment(id: number): Promise<void> {
  await api.delete(`/appointments/${id}`)
}
