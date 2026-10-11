export interface AppointmentStatusReport { status: string; count: number }
export interface RevenueReport { invoiceCount: number; revenue: number }
export interface ServiceReport { dichVuId: number | null; name: string; quantity: number; revenue: number }
export interface CustomerReport { khachHangId: number; hoTen: string; soDiem: number; appointmentCount: number; invoiceCount: number }
export interface ReportInvoice { id: number; createdAt: string; total: number; status: string }
export interface ReportCustomer { id: number; fullName: string | null; createdAt?: string; ngayTao?: string }
export interface ReportReview { danhGiaId: number; hoaDonId: number; soSao: number; binhLuan: string | null; ngayDanhGia: string }
export function asReportArray<T>(value: unknown): T[] { return Array.isArray(value) ? value as T[] : [] }
export function asReportValueArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (typeof value === 'object' && value !== null && 'value' in value && Array.isArray(value.value)) return value.value as T[]
  return []
}
export function asRevenueReport(value: unknown): RevenueReport {
  if (typeof value !== 'object' || value === null || !('invoiceCount' in value) || !('revenue' in value)) throw new Error('Phản hồi thống kê doanh thu không hợp lệ.')
  const report = value as Record<string, unknown>
  if (typeof report.invoiceCount !== 'number' || typeof report.revenue !== 'number') throw new Error('Phản hồi thống kê doanh thu không hợp lệ.')
  return { invoiceCount: report.invoiceCount, revenue: report.revenue }
}
export const REPORT_STATUS_LABELS: Record<string,string> = { ChoXacNhan:'Chờ xác nhận',DaXacNhan:'Đã xác nhận',KhachDaDen:'Khách đã đến',DangThucHien:'Đang thực hiện',HoanThanh:'Hoàn thành',DaHuy:'Đã hủy' }
export const REPORT_ENDPOINTS = { appointments:'/reports/appointments',revenue:'/reports/revenue',services:'/reports/services',customers:'/reports/customers' } as const
export const REPORT_CALCULATION_NOTE = 'Số liệu tính ở phía giao diện từ dữ liệu hiện có'
export const REPORT_CUSTOMER_DATE_NOTE = 'API không trả ngày tạo khách hàng nên không thể xác định số khách mới trong khoảng đã chọn.'
export const REPORT_DATE_FILTER_NOTE = 'Khoảng ngày lọc lịch hẹn và doanh thu; API dịch vụ/khách hàng không hỗ trợ from/to.'
export const REPORT_CUSTOMER_DATE_FIELDS = ['createdAt','ngayTao'] as const
export const REPORT_QUERY_KEY = ['reports'] as const
export const REPORT_TIME_FORMAT = 'YYYY-MM-DDTHH:mm:ss'
export const PAID_INVOICE_STATUS = 'DaThanhToan'
export const REPORT_STALE_TIME = 60000
export const REPORT_DATE_RANGE_DAYS = 29
export const REPORT_SERVICE_LIMIT = 5
export const REPORT_CHART_HEIGHT = 280
export const REPORT_STATUS_COLORS: Record<string,string> = { ChoXacNhan:'#B7791F',DaXacNhan:'#0007cb',KhachDaDen:'#0007cb',DangThucHien:'#0007cb',HoanThanh:'#2F7D4F',DaHuy:'#C0392B' }
export const REPORT_UNKNOWN_COLOR = '#888888'
export const REPORT_CHART_COLOR = '#111111'
export const REPORT_GRID_COLOR = '#dedbd6'
export const REPORT_TEXT_COLOR = '#585858'
export const REPORT_EMPTY = 'Chưa có dữ liệu trong khoảng ngày đã chọn.'
export const REPORT_LOADING = 'Đang tải số liệu báo cáo…'
export const REPORT_ERROR = 'Không tải được dữ liệu báo cáo. Vui lòng thử lại sau.'
export const REPORT_NO_REVIEWS = 'Chưa có đánh giá'
export const REPORT_DATE_FORMAT = 'DD/MM/YYYY HH:mm'
export const REPORT_DAY_FORMAT = 'DD/MM'
export const REPORT_PICKER_FORMAT = 'DD/MM/YYYY'
export const REPORT_CURRENCY_LOCALE = 'vi-VN'
export const REPORT_ROLE_LIMITED_NOTE = 'Reception và Staff chỉ xem lời chào và lối tắt lịch hẹn.'
export const REPORT_HOME_GREETING = 'Chào mừng đến hệ thống quản lý'
export const REPORT_HOME_DESCRIPTION = 'Truy cập nhanh lịch hẹn để theo dõi công việc.'
export const REPORT_HOME_NOTE = 'Không hiển thị doanh thu trong trang chủ của Reception/Staff.'
export const REPORT_APPOINTMENTS_ROUTE = '/appointments'
export const REPORTS_ROUTE = '/reports'
export const REPORT_ADMIN_ROLES = ['Admin','Manager'] as const
export const REPORT_STATUS_SOURCE_NOTE = 'Số lượng theo trạng thái lấy từ GET /reports/appointments.'
export const REPORT_SERVICE_SOURCE_NOTE = 'Top dịch vụ lấy từ GET /reports/services.'
export const REPORT_REVENUE_API_NOTE = 'Tổng doanh thu lấy trực tiếp từ trường revenue của GET /reports/revenue.'
export const REPORT_REVENUE_CHART_NOTE = 'Biểu đồ doanh thu theo ngày tính từ total của hóa đơn đã thanh toán.'
export const REPORT_CLIENT_REVENUE_NOTE = 'Doanh thu theo ngày tính ở giao diện bằng cách cộng trường total của hóa đơn đã thanh toán.'
export const REPORT_REVIEW_NOTE = 'Điểm trung bình tính từ GET /reviews.'
export const REPORT_TOTAL_CUSTOMERS_NOTE = 'Số khách hàng lấy từ GET /reports/customers.'
export const REPORT_DATE_FILTER_HELP = 'Khoảng ngày áp dụng cho lịch hẹn và doanh thu.'
export const REPORT_CUSTOMER_DATE_DISCLOSURE = 'API không cung cấp ngày tạo khách hàng; không thể xác định khách mới theo khoảng ngày.'
export const REPORT_SERVICES_CUSTOMERS_NOTE = 'Dữ liệu dịch vụ/khách hàng không lọc theo ngày vì endpoint không nhận from/to.'
export const REPORT_FETCH_ERROR = 'Không tải được dữ liệu báo cáo. Vui lòng thử lại sau.'
export const REPORT_RESPONSE_SCHEMA_NOTE = 'Swagger không khai báo schema response; type dựa trên JSON thật đã đọc.'
export const REPORT_HOME_SHORTCUT = 'Mở lịch hẹn'
export const REPORT_MENU_LABEL = 'Báo cáo'
export const REPORT_PAGE_TITLE = 'Báo cáo tổng hợp'
export const REPORT_AVERAGE_RATING_LABEL = 'Điểm đánh giá trung bình'
export const REPORT_NEW_CUSTOMER_LABEL = 'Khách mới'
export const REPORTS_TITLE = 'Báo cáo'
export const REPORT_DATE_FILTER_LABEL = 'Khoảng ngày'
export const REPORT_EMPTY_CHART = 'Không có dữ liệu để hiển thị.'
export const REPORT_UNKNOWN_STATUS = 'Trạng thái khác'
export const REPORT_UNKNOWN_SERVICE = 'Dịch vụ'
export const REPORT_CHART_MARGIN = { top:12,right:20,bottom:8,left:12 }
export const REPORTS_END = true
export const REPORT_ACCESS_DENIED = 'Bạn không có quyền truy cập trang báo cáo.'
export const REPORT_PAGE_DESCRIPTION = 'Báo cáo tổng hợp lịch hẹn, doanh thu, dịch vụ và đánh giá.'
export const REPORT_AVERAGE_RATING_NOTE = 'Điểm trung bình tính từ GET /reviews.'
