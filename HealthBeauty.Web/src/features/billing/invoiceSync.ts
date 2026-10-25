import type { Invoice, PaymentRequest } from '../../types/billing'

export const INVOICE_REFRESH_INTERVAL = 5000

export function currentInvoice(id: number | null, invoices: Invoice[], detail?: Invoice): Invoice | null {
  if (id === null) return null
  return invoices.find((invoice) => invoice.id === id) ?? (detail?.id === id ? detail : null)
}

export function canApplyInvoiceDiscount(invoice: Invoice): boolean {
  return invoice.status === 'ChuaThanhToan' && invoice.total > 0 && invoice.total === invoice.subtotal
    && !invoice.payments.some((payment) => payment.status === 'ThanhCong')
}

// A fresh read prevents an already received bank transfer from being recorded
// manually again while the cashier's previously opened drawer is stale.
export async function recordPendingPayment(
  id: number,
  body: PaymentRequest,
  api: { getInvoice: (id: number) => Promise<Invoice>; recordInvoicePayment: (id: number, body: PaymentRequest) => Promise<void> },
  expectedTotal: number,
): Promise<boolean> {
  const latest = await api.getInvoice(id)
  if (latest.id !== id || latest.status !== 'ChuaThanhToan' || latest.total !== expectedTotal) return false
  await api.recordInvoicePayment(id, body)
  return true
}
