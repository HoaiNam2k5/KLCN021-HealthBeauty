import { useQuery } from '@tanstack/react-query'
import * as appointmentsApi from '../../api/appointments'
import type { AppointmentFilters } from '../../types/appointments'
import { useAuth } from '../../hooks/useAuth'
import { loadTimelineAppointments } from './timelineModel'

export const appointmentKeys = {
  appointments: ['appointments'] as const,
  appointmentList: (filters: AppointmentFilters) => [...appointmentKeys.appointments, filters] as const,
  staff: ['appointment-staff'] as const,
  customers: (keyword: string) => ['appointment-customers', keyword] as const,
  availableSlots: ['appointment-available-slots'] as const,
}

export function useAppointments(filters: AppointmentFilters = {}, enabled = true) {
  return useQuery({ queryKey: appointmentKeys.appointmentList(filters), queryFn: () => appointmentsApi.getAppointments(filters), enabled, refetchInterval: 15000, refetchIntervalInBackground: false })
}

export function useTimelineAppointments(from: string, to: string, enabled: boolean) {
  const accountId = useAuth()?.account?.id
  return useQuery({
    queryKey: [...appointmentKeys.appointments, 'timeline', accountId, from, to],
    queryFn: ({ signal }) => loadTimelineAppointments({ from, to }, filters => appointmentsApi.getAppointments(filters, signal)),
    enabled: enabled && accountId !== undefined,
    refetchInterval: 30000, refetchIntervalInBackground: false,
    refetchOnWindowFocus: 'always', refetchOnMount: 'always', retry: 1,
  })
}

export function useAllAppointments(enabled = true) {
  return useQuery({ queryKey: [...appointmentKeys.appointments, 'all'], queryFn: appointmentsApi.getAllAppointments, enabled })
}

export function useAppointmentStaff(enabled = true) {
  return useQuery({ queryKey: appointmentKeys.staff, queryFn: appointmentsApi.getStaff, enabled })
}

export function useAppointmentCustomers(keyword = '', enabled = true) {
  return useQuery({ queryKey: appointmentKeys.customers(keyword), queryFn: () => appointmentsApi.getCustomers(keyword), enabled })
}

export function useAvailableSlots(date: string, staffId?: number, durationMinutes = 30) {
  return useQuery({ queryKey: [...appointmentKeys.availableSlots, date, staffId, durationMinutes], queryFn: () => appointmentsApi.getAvailableSlots(date, staffId, durationMinutes), enabled: Boolean(date) && durationMinutes > 0 })
}

export function useAppointmentDetail(id: number | undefined) {
  return useQuery({ queryKey: [...appointmentKeys.appointments, 'detail', id], queryFn: () => appointmentsApi.getAppointmentDetail(id!), enabled: id !== undefined })
}
