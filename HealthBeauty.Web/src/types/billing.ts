export interface InvoiceItem {
  id: number
  serviceId: number | null
  serviceName: string | null
  comboId: number | null
  comboName: string | null
  quantity: number
  unitPrice: number
}

export interface InvoicePayment {
  id: number
  method: string
  amount: number
  paidAt: string
  status: string
}

export interface Invoice {
  id: number
  appointmentId: number
  customerId: number
  createdAt: string
  subtotal: number
  total: number
  status: string
  items: InvoiceItem[]
  payments: InvoicePayment[]
}

export interface InvoiceListResponse {
  value: Invoice[]
  Count: number
}

export interface InvoiceLineRequest {
  serviceId: number | null
  comboId: number | null
  quantity: number
}

export interface CreateInvoiceRequest {
  appointmentId: number
  items: InvoiceLineRequest[]
  voucherCode: string | null
  pointsToRedeem: number
}

export interface PaymentRequest {
  method: string
  status: string
}

export interface ApplyInvoiceDiscountRequest {
  voucherCode: string | null
  pointsToRedeem: number
}

export function asInvoices(value: unknown): Invoice[] {
  if (Array.isArray(value)) return value as Invoice[]
  if (typeof value === 'object' && value !== null && 'value' in value) {
    const items = value.value
    return Array.isArray(items) ? items as Invoice[] : []
  }
  return []
}
