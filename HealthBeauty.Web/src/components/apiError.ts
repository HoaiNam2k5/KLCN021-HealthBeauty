import axios from 'axios'

const errorTranslations: Record<string, string> = {
  "The entire appointment must be within the selected staff member's working shift.": 'Toàn bộ thời gian lịch hẹn phải nằm trọn trong ca làm việc của nhân viên được chọn.',
  'Only completed appointments can be invoiced.': 'Chỉ có thể tạo hóa đơn cho lịch hẹn đã hoàn thành.',
  'Invoice items and nonnegative points are required.': 'Hóa đơn cần có ít nhất một dịch vụ/combo và số điểm hợp lệ.',
  'Invoice items must match the booked services and complete combos, including quantities.': 'Các dòng hóa đơn phải tương ứng với dịch vụ hoặc combo đã đặt trong lịch hẹn.',
  'Voucher is not valid for this customer or date.': 'Voucher không hợp lệ cho khách hàng này hoặc đã hết hạn.',
  'One or more combos are missing, inactive or outside their validity period.': 'Một hoặc nhiều combo không tồn tại, đã ngưng hoạt động hoặc hết hạn.',
  'Booking must include every combo component with its configured quantity.': 'Lịch hẹn phải bao gồm đầy đủ các dịch vụ thành phần trong combo.',
  'Email already exists.': 'Email này đã được sử dụng trong hệ thống.',
  'Staff with appointment history or work schedules cannot be deleted.': 'Không thể xóa nhân viên đã có lịch sử hẹn hoặc ca làm việc.',
  'Work schedules overlap.': 'Lịch làm việc của nhân viên bị trùng ca.',
  'Network Error': 'Lỗi kết nối mạng, vui lòng kiểm tra lại đường truyền.',
}

function translateApiMessage(message: string): string {
  return errorTranslations[message.trim()] ?? message
}

export function getApiErrorMessage(error: unknown, fallback: string): string {
  if (!axios.isAxiosError(error)) return fallback
  if (error.response?.status === 403) return 'Bạn không có quyền thực hiện thao tác này'
  const data: unknown = error.response?.data
  if (typeof data === 'string' && data.trim()) return translateApiMessage(data)
  if (typeof data === 'object' && data !== null) {
    const body = data as Record<string, unknown>
    for (const key of ['message', 'title', 'detail']) {
      const value = body[key]
      if (typeof value === 'string' && value.trim()) return translateApiMessage(value)
    }
    const errors = body.errors
    if (typeof errors === 'object' && errors !== null) {
      const messages = Object.values(errors as Record<string, unknown>).flatMap((entry) => Array.isArray(entry) ? entry.filter((item): item is string => typeof item === 'string') : [])
      if (messages.length) return translateApiMessage(messages.join(' '))
    }
  }
  return fallback
}
