const roleLabels: Record<string, string> = {
  Admin: 'Quản trị viên', Manager: 'Quản lý', Reception: 'Lễ tân',
  Staff: 'Nhân viên', Customer: 'Khách hàng',
}

const permissionGroupLabels: Record<string, string> = {
  ACCOUNT: 'Tài khoản', AUTHORIZATION: 'Phân quyền', CUSTOMER: 'Khách hàng',
  STAFF: 'Nhân viên', SERVICE: 'Dịch vụ', APPOINTMENT: 'Lịch hẹn',
  BILLING: 'Hóa đơn và thanh toán', PROMOTION: 'Khuyến mãi', REVIEW: 'Đánh giá', REPORT: 'Báo cáo',
}

const auditActionLabels: Record<string, string> = {
  AccountCreated: 'Tạo tài khoản', AccountRoleChanged: 'Đổi vai trò tài khoản',
  AccountActivated: 'Mở khóa tài khoản', AccountDeactivated: 'Khóa tài khoản',
  PermissionGranted: 'Cấp quyền', PermissionRevoked: 'Thu hồi quyền',
  StaffAccountCreated: 'Tạo tài khoản nhân viên', PasswordReset: 'Đặt lại mật khẩu',
}

const auditEntityLabels: Record<string, string> = {
  TAIKHOAN: 'Tài khoản', VAITRO_QUYEN: 'Quyền của vai trò', NHANVIEN: 'Nhân viên',
}

const packageStatusLabels: Record<string, string> = {
  Pending: 'Chờ thu tiền', Paid: 'Đã thanh toán', Cancelled: 'Đã hủy',
}

const pointTransactionLabels: Record<string, string> = {
  TichLuy: 'Tích điểm', SuDung: 'Sử dụng điểm', DoiVoucher: 'Đổi điểm lấy phiếu giảm giá',
}

const labelFor = (labels: Record<string, string>, code: string, fallback: string) => Object.hasOwn(labels, code) ? labels[code] : fallback

export const getRoleLabel = (role?: string | null) => labelFor(roleLabels, role ?? '', 'Vai trò chưa xác định')
export const getPermissionGroupLabel = (group: string) => labelFor(permissionGroupLabels, group, 'Khác')
export const getAuditActionLabel = (action: string) => labelFor(auditActionLabels, action, 'Hoạt động khác')
export const getAuditEntityLabel = (entity: string | null) => entity ? labelFor(auditEntityLabels, entity, 'Đối tượng khác') : '—'
export const getPackageStatusLabel = (status: string) => labelFor(packageStatusLabels, status, 'Trạng thái chưa xác định')
export const getPointTransactionLabel = (type: string) => labelFor(pointTransactionLabels, type, 'Giao dịch điểm khác')
