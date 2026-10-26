import api from './client'
import { asInvoices, type ApplyInvoiceDiscountRequest, type CreateInvoiceRequest, type Invoice, type InvoiceBankTransfer, type PaymentRequest } from '../types/billing'

export async function getInvoices(): Promise<Invoice[]> {
  const { data } = await api.get<unknown>('/invoices')
  return asInvoices(data)
}

export async function getInvoice(id: number): Promise<Invoice> {
  const { data } = await api.get<Invoice>(`/invoices/${id}`)
  return data
}

export async function getInvoiceBankTransfer(id: number): Promise<InvoiceBankTransfer> {
  const { data } = await api.post<InvoiceBankTransfer>(`/invoices/${id}/bank-transfer`)
  return data
}

export async function createInvoice(body: CreateInvoiceRequest): Promise<void> {
  await api.post('/invoices', body)
}

export async function recordInvoicePayment(id: number, body: PaymentRequest): Promise<void> {
  await api.post(`/invoices/${id}/payments`, body)
}

export async function applyInvoiceDiscount(id: number, body: ApplyInvoiceDiscountRequest): Promise<Invoice> {
  const { data } = await api.post<Invoice>(`/invoices/${id}/discounts`, body)
  return data
}
