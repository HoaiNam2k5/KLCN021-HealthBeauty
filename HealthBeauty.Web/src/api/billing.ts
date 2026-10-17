import api from './client'
import { asInvoices, type CreateInvoiceRequest, type Invoice, type PaymentRequest } from '../types/billing'

export async function getInvoices(): Promise<Invoice[]> {
  const { data } = await api.get<unknown>('/invoices')
  return asInvoices(data)
}

export async function createInvoice(body: CreateInvoiceRequest): Promise<void> {
  await api.post('/invoices', body)
}

export async function recordInvoicePayment(id: number, body: PaymentRequest): Promise<void> {
  await api.post(`/invoices/${id}/payments`, body)
}
