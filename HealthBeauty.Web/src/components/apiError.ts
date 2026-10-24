import axios from 'axios'
import { translateApiMessage } from '../utils/apiMessages'

export function getApiErrorMessage(error: unknown, fallback: string): string {
  if (!axios.isAxiosError(error)) return fallback
  if (!error.response) return 'Không thể kết nối máy chủ. Vui lòng kiểm tra đường truyền và thử lại.'
  if (error.response.status === 401) return 'Phiên đăng nhập không hợp lệ hoặc đã hết hạn. Vui lòng đăng nhập lại.'
  if (error.response?.status === 403) return 'Bạn không có quyền thực hiện thao tác này'
  if (error.response.status === 429) return 'Bạn thao tác quá nhanh. Vui lòng đợi một lát rồi thử lại.'
  const data: unknown = error.response?.data
  if (typeof data === 'string' && data.trim()) return translateApiMessage(data, fallback)
  if (typeof data === 'object' && data !== null) {
    const body = data as Record<string, unknown>
    const errors = body.errors
    if (typeof errors === 'object' && errors !== null) {
      const messages = Object.values(errors as Record<string, unknown>).flatMap((entry) => Array.isArray(entry) ? entry.filter((item): item is string => typeof item === 'string') : [])
      if (messages.length) return [...new Set(messages.map((message) => translateApiMessage(message, fallback)))].join(' ')
    }
    for (const key of ['message', 'detail', 'title']) {
      const value = body[key]
      if (typeof value === 'string' && value.trim()) {
        const translated = translateApiMessage(value, '')
        if (translated) return translated
      }
    }
  }
  return fallback
}
