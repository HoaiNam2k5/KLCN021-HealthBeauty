import { useQuery } from '@tanstack/react-query'
import * as appointmentsApi from '../../api/appointments'

export const appointmentKeys = {
  appointments: ['appointments'] as const,
  staff: ['appointment-staff'] as const,
  customers: ['appointment-customers'] as const,
  availableSlots: ['appointment-available-slots'] as const,
}

export function useAppointments() {
  return useQuery({ queryKey: appointmentKeys.appointments, queryFn: appointmentsApi.getAppointments })
}

export function useAppointmentStaff() {
  return useQuery({ queryKey: appointmentKeys.staff, queryFn: appointmentsApi.getStaff })
}

export function useAppointmentCustomers() {
  return useQuery({ queryKey: appointmentKeys.customers, queryFn: appointmentsApi.getCustomers })
}

export function useAvailableSlots(date: string, staffId?: number) {
  return useQuery({ queryKey: [...appointmentKeys.availableSlots, date, staffId], queryFn: () => appointmentsApi.getAvailableSlots(date, staffId), enabled: Boolean(date) })
}
