import type { Invoice, InvoiceBankTransfer } from '../../types/billing'

export function matchesPayableInvoice(invoice: Invoice | undefined, transfer: InvoiceBankTransfer | undefined): boolean {
  return invoice !== undefined && transfer !== undefined && invoice.status === 'ChuaThanhToan'
    && invoice.total > 0 && Number.isInteger(invoice.total)
    && transfer.invoiceId === invoice.id && transfer.amount === invoice.total
    && transfer.status === 'ChuaThanhToan' && transfer.transferContent === `HB${invoice.id}`
    && transfer.qrImageUrl.startsWith('https://vietqr.app/')
}
