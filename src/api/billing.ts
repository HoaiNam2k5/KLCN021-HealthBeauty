import api from './client'
import { asInvoices, type Invoice } from '../types/billing'

export async function getInvoices(): Promise<Invoice[]> {
  const { data } = await api.get<unknown>('/invoices')
  return asInvoices(data)
}
