export interface QuickActionAccess {
  canVisit: (route: string) => boolean
  has: (permission: string) => boolean
}

export function quickActions(access: QuickActionAccess) {
  return [
    { key: 'appointment', title: 'Đặt lịch hẹn mới', description: 'Tiếp nhận & tạo lịch hẹn', route: '/appointments', permissions: ['APPOINTMENT.WRITE', 'CUSTOMER.READ'], background: '#fff0f3', color: '#8c4559' },
    { key: 'invoice', title: 'Lập hóa đơn', description: 'Lập hóa đơn từ lịch đã hoàn thành', route: '/billing', permissions: ['INVOICE.WRITE', 'APPOINTMENT.READ'], background: '#e6f7ed', color: '#2F7D4F' },
    { key: 'customer', title: 'Thêm khách hàng', description: 'Tạo hồ sơ khách hàng', route: '/customers', permissions: ['CUSTOMER.WRITE'], background: '#e6f4ff', color: '#1677ff' },
    { key: 'schedule', title: 'Lịch làm việc KTV', description: 'Xem lịch làm việc kỹ thuật viên', route: '/staff-schedules', permissions: [], background: '#fff7e6', color: '#fa8c16' },
  ].filter(action => access.canVisit(action.route) && action.permissions.every(access.has))
    .map(action => ({ ...action, destination: action.key === 'schedule' ? action.route : `${action.route}?action=create` }))
}
