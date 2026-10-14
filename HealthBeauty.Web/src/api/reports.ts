import { getInvoices } from './billing'
import { getAllAppointments, getCustomers } from './appointments'
import { getServices } from './services'
import type { Service } from '../types/services'
import type { ReportCustomer as CustomerWithDate } from '../types/reports'
import api from './client'
import { getReviews } from './reviews'
import { asReportArray, asRevenueReport, REPORT_ENDPOINTS, type AppointmentStatusReport, type CustomerReport, type RevenueReport, type ServiceReport } from '../types/reports'
import type { Appointment } from '../types/appointments'
import type { Invoice } from '../types/billing'
import type { Review } from '../types/reviews'

export type ReportInvoice = Invoice
export type ReportAppointment = Appointment
export type ReportReview = Review
export type ReportCustomer = CustomerWithDate

export async function getAppointmentReport(from: string, to: string): Promise<AppointmentStatusReport[]> {
  const { data } = await api.get<unknown>(REPORT_ENDPOINTS.appointments, { params: { from, to } })
  return asReportArray<AppointmentStatusReport>(data)
}

export async function getRevenueReport(from: string, to: string): Promise<RevenueReport> {
  const { data } = await api.get<unknown>(REPORT_ENDPOINTS.revenue, { params: { from, to } })
  return asRevenueReport(data)
}

export async function getServiceReport(): Promise<ServiceReport[]> {
  const { data } = await api.get<unknown>(REPORT_ENDPOINTS.services)
  return asReportArray<ServiceReport>(data)
}

export async function getCustomerReport(): Promise<CustomerReport[]> {
  const { data } = await api.get<unknown>(REPORT_ENDPOINTS.customers)
  return asReportArray<CustomerReport>(data)
}

export async function getReportInvoices(): Promise<ReportInvoice[]> { return getInvoices() }
export async function getReportCustomers(): Promise<ReportCustomer[]> { return getCustomers() }
export async function getReportReviews(): Promise<ReportReview[]> { return getReviews() }
export async function getReportAppointments(): Promise<ReportAppointment[]> { return getAllAppointments() }
export async function getReportServices(): Promise<Service[]> { return getServices() }
