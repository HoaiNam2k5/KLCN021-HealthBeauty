import { useQuery } from '@tanstack/react-query'
import * as appointmentsApi from '../../api/appointments'
import type { AppointmentFilters } from '../../types/appointments'

export const appointmentKeys = {
  appointments: ['appointments'] as const,
  appointmentList: (filters: AppointmentFilters) => [...appointmentKeys.appointments, filters] as const,
  staff: ['appointment-staff'] as const,
  customers: (keyword: string) => ['appointment-customers', keyword] as const,
  availableSlots: ['appointment-available-slots'] as const,
}

export function useAppointments(filters: AppointmentFilters = {}) {
  return useQuery({ queryKey: appointmentKeys.appointmentList(filters), queryFn: () => appointmentsApi.getAppointments(filters) })
}

export function useAllAppointments() {
  return useQuery({ queryKey: [...appointmentKeys.appointments, 'all'], queryFn: appointmentsApi.getAllAppointments })
}

export function useAppointmentStaff() {
  return useQuery({ queryKey: appointmentKeys.staff, queryFn: appointmentsApi.getStaff })
}

export function useAppointmentCustomers(keyword = '') {
  return useQuery({ queryKey: appointmentKeys.customers(keyword), queryFn: () => appointmentsApi.getCustomers(keyword) })
}

export function useAvailableSlots(date: string, staffId?: number) {
  return useQuery({ queryKey: [...appointmentKeys.availableSlots, date, staffId], queryFn: () => appointmentsApi.getAvailableSlots(date, staffId), enabled: Boolean(date) })
}
