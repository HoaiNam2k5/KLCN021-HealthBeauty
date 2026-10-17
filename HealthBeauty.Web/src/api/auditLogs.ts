import api from './client'

export interface AuditLog {
  auditLogId: number
  taiKhoanId: number | null
  actionName: string
  entityName: string | null
  entityId: string | null
  createdAt: string
  ipAddress: string | null
}
export async function getAuditLogs(take: number, signal?: AbortSignal): Promise<AuditLog[]> {
  const { data } = await api.get<AuditLog[]>('/admin/audit-logs', { params: { take }, signal })
  if (!Array.isArray(data)) throw new Error('Dữ liệu nhật ký không hợp lệ.')
  return data
}
