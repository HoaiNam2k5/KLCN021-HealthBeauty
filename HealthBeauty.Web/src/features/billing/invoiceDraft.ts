import type { Appointment } from '../../types/appointments'
import type { Invoice, InvoiceLineRequest } from '../../types/billing'
import type { Combo, Service } from '../../types/services'

export interface InvoiceDraft {
  items: InvoiceLineRequest[]
  subtotal: number
  lines: { key: string; name: string; quantity: number; unitPrice: number }[]
}

export function eligibleInvoiceAppointments(appointments: Appointment[], invoices: Invoice[]): Appointment[] {
  const invoicedIds = new Set(invoices.map((invoice) => invoice.appointmentId))
  return appointments.filter((appointment) => appointment.status === 'HoanThanh' && !invoicedIds.has(appointment.id))
}

export function buildInvoiceDraft(appointment: Appointment, services: Service[], combos: Combo[]): InvoiceDraft {
  if (appointment.status !== 'HoanThanh') throw new Error('Chỉ tạo hóa đơn cho lịch hẹn đã hoàn thành.')
  if (!appointment.items.length) throw new Error('Lịch hẹn chưa có dịch vụ để xuất hóa đơn.')
  const serviceCounts = new Map<number, number>()
  const comboCounts = new Map<number, Map<number, number>>()
  for (const item of appointment.items) {
    if (item.comboId === null) serviceCounts.set(item.serviceId, (serviceCounts.get(item.serviceId) ?? 0) + 1)
    else {
      const counts = comboCounts.get(item.comboId) ?? new Map<number, number>()
      counts.set(item.serviceId, (counts.get(item.serviceId) ?? 0) + 1)
      comboCounts.set(item.comboId, counts)
    }
  }
  const draft: InvoiceDraft = { items: [], subtotal: 0, lines: [] }
  function addLine(serviceId: number | null, comboId: number | null, name: string, quantity: number, unitPrice: number) {
    draft.lines.push({ key: `${serviceId ?? 'combo'}:${comboId ?? 'service'}`, name, quantity, unitPrice })
    draft.subtotal += quantity * unitPrice
    for (let remaining = quantity; remaining > 0; remaining -= 100) {
      draft.items.push({ serviceId, comboId, quantity: Math.min(100, remaining) })
    }
  }
  for (const [id, quantity] of serviceCounts) {
    const service = services.find((item) => item.id === id)
    if (!service) throw new Error(`Không tìm thấy dịch vụ #${id} trong danh mục hiện tại.`)
    addLine(id, null, service.name ?? `Dịch vụ #${id}`, quantity, service.price)
  }
  for (const [id, counts] of comboCounts) {
    const combo = combos.find((item) => item.id === id)
    if (!combo?.items?.length) throw new Error(`Không tìm thấy thành phần combo #${id} trong danh mục hiện tại.`)
    if (counts.size !== combo.items.length) throw new Error(`Lịch hẹn có thành phần không khớp combo #${id}.`)
    let quantity: number | undefined
    for (const component of combo.items) {
      const count = counts.get(component.serviceId) ?? 0
      const copies = count / component.quantity
      if (component.quantity <= 0 || !Number.isInteger(copies) || copies <= 0 || (quantity !== undefined && copies !== quantity)) {
        throw new Error(`Lịch hẹn chưa đủ thành phần của combo #${id}.`)
      }
      quantity = copies
    }
    addLine(null, id, combo.name ?? `Combo #${id}`, quantity!, combo.price)
  }
  return draft
}
