export const INVOICE_STATUS = {
  PAID: 'DaThanhToan',
  UNPAID: 'ChuaThanhToan',
} as const

export const INVOICE_STATUS_LABELS: Record<string, string> = {
  [INVOICE_STATUS.PAID]: 'Đã thanh toán',
  [INVOICE_STATUS.UNPAID]: 'Chờ thanh toán',
}

export const PAYMENT_METHOD = {
  CASH: 'TienMat',
  BANK_TRANSFER: 'ChuyenKhoan',
  CARD: 'The',
} as const

export const PAYMENT_METHOD_LABELS: Record<string, string> = {
  [PAYMENT_METHOD.CASH]: 'Tiền mặt',
  [PAYMENT_METHOD.BANK_TRANSFER]: 'Chuyển khoản (Ngân hàng / QR)',
  [PAYMENT_METHOD.CARD]: 'Thẻ ngân hàng (POS)',
}

export const PAYMENT_STATUS = {
  SUCCESS: 'ThanhCong',
} as const

export const PAYMENT_STATUS_LABELS: Record<string, string> = {
  [PAYMENT_STATUS.SUCCESS]: 'Thành công',
}

// TODO: Confirm additional payment statuses with backend; only ThanhCong is confirmed.
export const PAYMENT_METHOD_OPTIONS = [
  { value: PAYMENT_METHOD.CASH, label: PAYMENT_METHOD_LABELS[PAYMENT_METHOD.CASH] },
  { value: PAYMENT_METHOD.BANK_TRANSFER, label: PAYMENT_METHOD_LABELS[PAYMENT_METHOD.BANK_TRANSFER] },
  { value: PAYMENT_METHOD.CARD, label: PAYMENT_METHOD_LABELS[PAYMENT_METHOD.CARD] },
]
export const PAYMENT_STATUS_OPTIONS = [{ value: PAYMENT_STATUS.SUCCESS, label: PAYMENT_STATUS_LABELS[PAYMENT_STATUS.SUCCESS] }]
