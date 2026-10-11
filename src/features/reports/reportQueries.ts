import { useQuery } from '@tanstack/react-query'
import * as reportsApi from '../../api/reports'
import { REPORT_QUERY_KEY, REPORT_STALE_TIME } from '../../types/reports'

export const reportKeys = {
  all: REPORT_QUERY_KEY,
  appointments: (from: string, to: string) => [...REPORT_QUERY_KEY, 'appointments', from, to] as const,
  revenue: (from: string, to: string) => [...REPORT_QUERY_KEY, 'revenue', from, to] as const,
  services: [...REPORT_QUERY_KEY, 'services'] as const,
  customers: [...REPORT_QUERY_KEY, 'customers'] as const,
  customerList: [...REPORT_QUERY_KEY, 'customer-list'] as const,
  invoices: [...REPORT_QUERY_KEY, 'invoices'] as const,
  reviews: [...REPORT_QUERY_KEY, 'reviews'] as const,
  appointmentList: [...REPORT_QUERY_KEY, 'appointment-list'] as const,
  serviceList: [...REPORT_QUERY_KEY, 'service-list'] as const,
}

export function useAppointmentReport(from: string, to: string) {
  return useQuery({ queryKey: reportKeys.appointments(from, to), queryFn: () => reportsApi.getAppointmentReport(from, to), staleTime: REPORT_STALE_TIME })
}
export function useRevenueReport(from: string, to: string) {
  return useQuery({ queryKey: reportKeys.revenue(from, to), queryFn: () => reportsApi.getRevenueReport(from, to), staleTime: REPORT_STALE_TIME })
}
export function useServiceReport() {
  return useQuery({ queryKey: reportKeys.services, queryFn: reportsApi.getServiceReport, staleTime: REPORT_STALE_TIME })
}
export function useCustomerReport() {
  return useQuery({ queryKey: reportKeys.customers, queryFn: reportsApi.getCustomerReport, staleTime: REPORT_STALE_TIME })
}
export function useReportInvoices() {
  return useQuery({ queryKey: reportKeys.invoices, queryFn: reportsApi.getReportInvoices, staleTime: REPORT_STALE_TIME })
}
export function useReportCustomers() {
  return useQuery({ queryKey: reportKeys.customerList, queryFn: reportsApi.getReportCustomers, staleTime: REPORT_STALE_TIME })
}
export function useReportReviews() {
  return useQuery({ queryKey: reportKeys.reviews, queryFn: reportsApi.getReportReviews, staleTime: REPORT_STALE_TIME })
}
export function useReportAppointments() {
  return useQuery({ queryKey: reportKeys.appointmentList, queryFn: reportsApi.getReportAppointments, staleTime: REPORT_STALE_TIME })
}
export function useReportServices() {
  return useQuery({ queryKey: reportKeys.serviceList, queryFn: reportsApi.getReportServices, staleTime: REPORT_STALE_TIME })
}
