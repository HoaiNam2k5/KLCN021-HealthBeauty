import api from './client'
import { asArray, asAvailableSlots, type Appointment, type AppointmentStatusRequest, type AppointmentUpdateRequest, type AvailableSlot, type Customer, type Staff } from '../types/appointments'

export async function getAppointments(): Promise<Appointment[]> {
  const { data } = await api.get<unknown>('/appointments')
  return asArray<Appointment>(data)
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
  const { data } = await api.get<unknown>('/appointments/available-slots', { params })
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
