export const INVOICE_STATUS = {
  PAID: 'DaThanhToan',
  UNPAID: 'ChuaThanhToan',
} as const

export const INVOICE_STATUS_LABELS: Record<string, string> = {
  [INVOICE_STATUS.PAID]: 'Đã thanh toán',
  [INVOICE_STATUS.UNPAID]: 'Chưa thanh toán',
}

export const PAYMENT_METHOD = {
  CASH: 'TienMat',
} as const

export const PAYMENT_METHOD_LABELS: Record<string, string> = {
  [PAYMENT_METHOD.CASH]: 'Tiền mặt',
}

// TODO: Confirm additional payment methods with backend; only TienMat is confirmed.
export const PAYMENT_STATUS = {
  SUCCESS: 'ThanhCong',
} as const

export const PAYMENT_STATUS_LABELS: Record<string, string> = {
  [PAYMENT_STATUS.SUCCESS]: 'Thành công',
}

// TODO: Confirm additional payment statuses with backend; only ThanhCong is confirmed.
export const PAYMENT_METHOD_OPTIONS = [{ value: PAYMENT_METHOD.CASH, label: PAYMENT_METHOD_LABELS[PAYMENT_METHOD.CASH] }]
export const PAYMENT_STATUS_OPTIONS = [{ value: PAYMENT_STATUS.SUCCESS, label: PAYMENT_STATUS_LABELS[PAYMENT_STATUS.SUCCESS] }]
