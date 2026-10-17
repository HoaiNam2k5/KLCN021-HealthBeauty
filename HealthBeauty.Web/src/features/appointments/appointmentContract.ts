import type { AppointmentItemRequest } from '../../types/appointments'
import type { Combo, Service } from '../../types/services'

export function localAppointmentDateTime(date: { format: (pattern: string) => string }, time: { format: (pattern: string) => string }): string {
  return `${date.format('YYYY-MM-DD')}T${time.format('HH:mm:ss')}`
}

export function bookingItems(keys: string[], services: Service[], combos: Combo[]): AppointmentItemRequest[] {
  const serviceMap = new Map(services.map((service) => [service.id, service]))
  return keys.flatMap<AppointmentItemRequest>((key) => {
    const [kind, rawId] = key.split(':')
    const id = Number(rawId)
    if (kind === 'service') {
      const service = serviceMap.get(id)
      if (!service) throw new Error('Dịch vụ đã chọn không còn khả dụng.')
      return [{ serviceId: id, comboId: null, expectedPrice: service.price }]
    }
    const combo = combos.find((item) => item.id === id)
    if (kind !== 'combo' || !combo?.items?.length) throw new Error('Combo đã chọn không còn khả dụng.')
    return combo.items.flatMap((component) => {
      if (!serviceMap.has(component.serviceId) || !Number.isInteger(component.quantity) || component.quantity < 1)
        throw new Error('Combo có dịch vụ không còn khả dụng.')
      return Array.from({ length: component.quantity }, () => ({ serviceId: component.serviceId, comboId: combo.id, expectedPrice: 0 }))
    })
  })
}

export function bookingDuration(keys: string[], services: Service[], combos: Combo[]): number {
  const serviceMap = new Map(services.map((service) => [service.id, service]))
  return bookingItems(keys, services, combos).reduce((sum, item) => sum + (serviceMap.get(item.serviceId)?.durationMinutes || 30), 0)
}

export function canReschedule(status: string): boolean {
  return status === 'ChoXacNhan' || status === 'DaXacNhan'
}

export function canCancel(status: string): boolean {
  return canReschedule(status) || status === 'DaDen'
}
