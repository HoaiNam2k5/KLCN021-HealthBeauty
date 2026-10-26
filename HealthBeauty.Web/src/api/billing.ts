import api from './client'
import { asInvoices, type ApplyInvoiceDiscountRequest, type BankTransferResponse, type CreateInvoiceRequest, type Invoice, type PaymentRequest } from '../types/billing'

export async function getInvoices(): Promise<Invoice[]> {
  const { data } = await api.get<unknown>('/invoices')
  return asInvoices(data)
}

export async function getInvoice(id: number, signal?: AbortSignal): Promise<Invoice> {
  const { data } = await api.get<Invoice>(`/invoices/${id}`, { signal })
  return data
}

export async function getBankTransferInstructions(invoiceId: number, signal?: AbortSignal): Promise<BankTransferResponse> {
  const { data } = await api.post<BankTransferResponse>(`/invoices/${invoiceId}/bank-transfer`, undefined, { signal })
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

export const getInvoiceBankTransfer = getBankTransferInstructions
