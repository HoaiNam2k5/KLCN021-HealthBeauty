import type { QueryClient } from '@tanstack/react-query'
import type { BankTransferResponse, Invoice } from '../../types/billing'

export function matchesPayableInvoice(invoice: Invoice | undefined, transfer: BankTransferResponse | undefined): boolean {
  if (!invoice || !transfer || invoice.status !== 'ChuaThanhToan' || !Number.isSafeInteger(invoice.total) || invoice.total <= 0
    || transfer.invoiceId !== invoice.id || transfer.amount !== invoice.total || transfer.status !== 'ChuaThanhToan'
    || transfer.transferContent !== `HB${invoice.id}`) return false
  try {
    const qr = new URL(transfer.qrImageUrl)
    return qr.origin === 'https://vietqr.app' && qr.pathname === '/img'
      && qr.searchParams.get('acc') === transfer.accountNumber
      && qr.searchParams.get('bank') === transfer.bankCode
      && qr.searchParams.get('amount') === String(invoice.total)
      && qr.searchParams.get('des') === transfer.transferContent
  } catch {
    return false
  }
}

// Stop an older list/detail response from overwriting the verified paid snapshot
// before the receipt opens. Other customer/session data is never seeded here.
export async function cacheVerifiedPaidInvoice(client: QueryClient, invoice: Invoice, isCurrent: () => boolean): Promise<boolean> {
  if (invoice.status !== 'DaThanhToan' || !isCurrent()) return false
  await client.cancelQueries({ queryKey: ['invoices'] })
  if (!isCurrent()) return false
  client.setQueryData<Invoice[]>(['invoices'], rows => rows?.map(row => row.id === invoice.id ? invoice : row))
  client.setQueryData(['invoices', 'detail', invoice.id], invoice)
  return true
}
