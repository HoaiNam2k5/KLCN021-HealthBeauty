export const APPOINTMENT_STATUS = {
  WAITING: 'ChoXacNhan',
  CONFIRMED: 'DaXacNhan',
  ARRIVED: 'KhachDaDen',
  IN_PROGRESS: 'DangThucHien',
  COMPLETED: 'HoanThanh',
  CANCELLED: 'DaHuy',
} as const

const statusPresentation: Record<string, { label: string; color: string; background: string }> = {
  [APPOINTMENT_STATUS.WAITING]: { label: 'Chờ xác nhận', color: '#B7791F', background: '#FAF1E3' },
  [APPOINTMENT_STATUS.CONFIRMED]: { label: 'Đã xác nhận', color: '#0007cb', background: '#eeeeff' },
  [APPOINTMENT_STATUS.ARRIVED]: { label: 'Khách đã đến', color: '#0007cb', background: '#eeeeff' },
  [APPOINTMENT_STATUS.IN_PROGRESS]: { label: 'Đang thực hiện', color: '#0007cb', background: '#eeeeff' },
  [APPOINTMENT_STATUS.COMPLETED]: { label: 'Hoàn thành', color: '#2F7D4F', background: '#eaf4ed' },
  [APPOINTMENT_STATUS.CANCELLED]: { label: 'Đã hủy', color: '#C0392B', background: '#fae9e7' },
}

export function getAppointmentStatusPresentation(status: string) {
  return statusPresentation[status] ?? { label: status, color: '#585858', background: '#f0efed' }
}

export function getAllowedNextAppointmentStatuses(status: string): string[] {
  const flow: Record<string, string[]> = {
    [APPOINTMENT_STATUS.WAITING]: [APPOINTMENT_STATUS.CONFIRMED],
    [APPOINTMENT_STATUS.CONFIRMED]: [APPOINTMENT_STATUS.ARRIVED],
    [APPOINTMENT_STATUS.ARRIVED]: [APPOINTMENT_STATUS.IN_PROGRESS],
    [APPOINTMENT_STATUS.IN_PROGRESS]: [APPOINTMENT_STATUS.COMPLETED],
  }
  if (status === APPOINTMENT_STATUS.COMPLETED || status === APPOINTMENT_STATUS.CANCELLED || !statusPresentation[status]) return []
  return [...(flow[status] ?? []), APPOINTMENT_STATUS.CANCELLED]
}
