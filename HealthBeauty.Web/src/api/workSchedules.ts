import api from './client'
import { asScheduleStaffList, asWorkSchedules, mapWorkScheduleRequest, type WorkSchedule, type WorkScheduleRequest } from '../types/workSchedules'

export async function getWorkSchedules(filters: { staffId?: number; from: string; to: string }): Promise<WorkSchedule[]> {
  const { data } = await api.get<unknown>('/staff/schedules', { params: filters })
  return asWorkSchedules(data)
}

export async function getScheduleStaff(): Promise<{ nhanVienId: number; hoTen: string }[]> {
  const { data } = await api.get<unknown>('/staff')
  return asScheduleStaffList(data)
}

export async function createWorkSchedule(body: WorkScheduleRequest): Promise<void> {
  await api.post('/staff/schedules', mapWorkScheduleRequest(body))
}

export async function updateWorkSchedule(id: number, body: WorkScheduleRequest): Promise<void> {
  await api.put(`/staff/schedules/${id}`, mapWorkScheduleRequest(body))
}

export async function deleteWorkSchedule(id: number): Promise<void> {
  await api.delete(`/staff/schedules/${id}`)
}

export async function getMyWorkSchedules(filters: { from: string; to: string }): Promise<WorkSchedule[]> {
  const { data } = await api.get<unknown>('/staff/me/schedules', { params: { from: filters.from, to: filters.to } })
  return asWorkSchedules(data)
}
