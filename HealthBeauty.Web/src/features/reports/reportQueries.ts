import { useQuery } from '@tanstack/react-query'
import * as reportsApi from '../../api/reports'
import { REPORT_QUERY_KEY, REPORT_STALE_TIME, type ReportFilterParams } from '../../types/reports'

export const reportKeys = {
  summary: (kind: string, params: ReportFilterParams) => [...REPORT_QUERY_KEY, kind, params] as const,
  all: REPORT_QUERY_KEY,
  appointmentReport: (from: string, to: string) => [...REPORT_QUERY_KEY, 'appointments', from, to] as const,
  revenueReport: (from: string, to: string) => [...REPORT_QUERY_KEY, 'revenue', from, to] as const,
  serviceReport: [...REPORT_QUERY_KEY, 'services'] as const,
  customerReport: [...REPORT_QUERY_KEY, 'customers'] as const,
  customerList: [...REPORT_QUERY_KEY, 'customer-list'] as const,
  invoices: [...REPORT_QUERY_KEY, 'invoices'] as const,
  reviews: [...REPORT_QUERY_KEY, 'reviews'] as const,
  appointments: [...REPORT_QUERY_KEY, 'appointment-list'] as const,
  services: [...REPORT_QUERY_KEY, 'service-list'] as const,
}

export function useAppointmentSummary(params: ReportFilterParams, enabled = true) {
  return useQuery({ queryKey: reportKeys.summary('appointment-summary', params), queryFn: () => reportsApi.getAppointmentSummary(params), enabled, staleTime: REPORT_STALE_TIME })
}
export function useOrderSummary(params: ReportFilterParams, enabled = true) {
  return useQuery({ queryKey: reportKeys.summary('order-summary', params), queryFn: () => reportsApi.getOrderSummary(params), enabled, staleTime: REPORT_STALE_TIME })
}
export function useOrderBreakdown(params: ReportFilterParams, enabled = true) {
  return useQuery({ queryKey: reportKeys.summary('order-breakdown', params), queryFn: () => reportsApi.getOrderBreakdown(params), enabled, staleTime: REPORT_STALE_TIME })
}
export function useNewCustomers(params: ReportFilterParams, enabled = true) {
  return useQuery({ queryKey: reportKeys.summary('new-customers', params), queryFn: () => reportsApi.getNewCustomers(params), enabled, staleTime: REPORT_STALE_TIME })
}

export function useAppointmentReport(from: string, to: string) {
  return useQuery({
    queryKey: reportKeys.appointmentReport(from, to),
    queryFn: () => reportsApi.getAppointmentReport(from, to),
    staleTime: REPORT_STALE_TIME,
  })
}

export function useRevenueReport(from: string, to: string) {
  return useQuery({
    queryKey: reportKeys.revenueReport(from, to),
    queryFn: () => reportsApi.getRevenueReport(from, to),
    staleTime: REPORT_STALE_TIME,
  })
}

export function useServiceReport() {
  return useQuery({ queryKey: reportKeys.serviceReport, queryFn: reportsApi.getServiceReport, staleTime: REPORT_STALE_TIME })
}

export function useCustomerReport() {
  return useQuery({ queryKey: reportKeys.customerReport, queryFn: reportsApi.getCustomerReport, staleTime: REPORT_STALE_TIME })
}

export function useReportInvoices(enabled = true) {
  return useQuery({ queryKey: reportKeys.invoices, queryFn: reportsApi.getReportInvoices, enabled, staleTime: REPORT_STALE_TIME })
}

export function useReportCustomers(enabled = true) {
  return useQuery({ queryKey: reportKeys.customerList, queryFn: reportsApi.getReportCustomers, enabled, staleTime: REPORT_STALE_TIME })
}

export function useReportReviews() {
  return useQuery({ queryKey: reportKeys.reviews, queryFn: reportsApi.getReportReviews, staleTime: REPORT_STALE_TIME })
}

export function useReportAppointments(enabled = true) {
  return useQuery({ queryKey: reportKeys.appointments, queryFn: reportsApi.getReportAppointments, enabled, staleTime: REPORT_STALE_TIME })
}

export function useReportServices() {
  return useQuery({ queryKey: reportKeys.services, queryFn: reportsApi.getReportServices, staleTime: REPORT_STALE_TIME })
}
