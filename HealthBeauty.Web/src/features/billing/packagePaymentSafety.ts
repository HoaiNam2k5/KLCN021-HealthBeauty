export function parsePackagePurchaseId(value: string | null): number | undefined {
  if (!value || !/^\d+$/.test(value)) return undefined
  const id = Number(value)
  return Number.isSafeInteger(id) && id > 0 ? id : undefined
}

interface PaymentSnapshot { id: number; price: number; status: string }

export function canCollectPackagePayment(expected: PaymentSnapshot, latest: PaymentSnapshot | undefined): boolean {
  return !!latest && expected.id === latest.id && latest.status === 'Pending'
    && expected.status === 'Pending' && Number.isFinite(latest.price) && latest.price >= 0 && latest.price === expected.price
}

export function packagePaymentStatusLabel(status: string): string {
  return ({ Paid: 'Đã thanh toán', Pending: 'Chờ thanh toán', Cancelled: 'Đã hủy' } as Record<string, string>)[status] ?? 'Chưa xác định'
}
