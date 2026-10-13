import axios from 'axios'

export function getApiErrorMessage(error: unknown, fallback: string): string {
  if (!axios.isAxiosError(error)) return fallback
  if (error.response?.status === 403) return 'Bạn không có quyền thực hiện thao tác này'
  const data: unknown = error.response?.data
  if (typeof data === 'string' && data.trim()) return data
  if (typeof data === 'object' && data !== null) {
    const body = data as Record<string, unknown>
    for (const key of ['message', 'title', 'detail']) {
      const value = body[key]
      if (typeof value === 'string' && value.trim()) return value
    }
    const errors = body.errors
    if (typeof errors === 'object' && errors !== null) {
      const messages = Object.values(errors as Record<string, unknown>).flatMap((entry) => Array.isArray(entry) ? entry.filter((item): item is string => typeof item === 'string') : [])
      if (messages.length) return messages.join(' ')
    }
  }
  return fallback
}
