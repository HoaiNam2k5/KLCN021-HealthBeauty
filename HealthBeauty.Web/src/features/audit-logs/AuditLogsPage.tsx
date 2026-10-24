import { useMemo, useState } from 'react'
import { Alert, Button, Input, Select, Space, Table, Tag, Typography } from 'antd'
import type { TableColumnsType } from 'antd'
import { ReloadOutlined } from '@ant-design/icons'
import { useQuery } from '@tanstack/react-query'
import { getAuditLogs, type AuditLog } from '../../api/auditLogs'
import { getAccounts } from '../../api/accounts'
import { getApiErrorMessage } from '../../components/apiError'
import { useAuth } from '../../hooks/useAuth'
import { getAuditActionLabel, getAuditEntityLabel } from '../../utils/displayLabels'

function displayDate(value: string) {
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString('vi-VN')
}
export default function AuditLogsPage() {
  const accountId = useAuth()?.account?.id
  const [take, setTake] = useState(100)
  const [keyword, setKeyword] = useState('')
  const [action, setAction] = useState<string | undefined>()
  const query = useQuery({ queryKey: ['audit-logs', accountId, take], queryFn: ({ signal }) => getAuditLogs(take, signal) })
  const accounts = useQuery({ queryKey: ['admin-accounts', accountId, ''], queryFn: () => getAccounts('') })
  const names = useMemo(() => new Map((accounts.data ?? []).map((account) => [account.taiKhoanId, account.email])), [accounts.data])
  const data = query.data ?? []
  const actions = [...new Set(data.map((row) => row.actionName))].map((value) => ({ value, label: getAuditActionLabel(value) })).sort((a, b) => a.label.localeCompare(b.label, 'vi'))
  const search = keyword.trim().toLocaleLowerCase()
  const rows = data.filter((row) => (!action || row.actionName === action) && (!search || [row.auditLogId, row.taiKhoanId, row.taiKhoanId == null ? '' : names.get(row.taiKhoanId), row.actionName, getAuditActionLabel(row.actionName), row.entityName, getAuditEntityLabel(row.entityName), row.entityId, row.ipAddress].some((value) => value != null && String(value).toLocaleLowerCase().includes(search))))
  const columns: TableColumnsType<AuditLog> = [
    { title: 'STT', key: 'stt', width: 60, align: 'center', render: (_value, _record, index) => index + 1 },
    { title: 'Thời gian', dataIndex: 'createdAt', width: 180, render: displayDate },
    { title: 'Người thực hiện', width: 220, render: (_, row) => row.taiKhoanId == null ? 'Hệ thống' : <><div>{names.get(row.taiKhoanId) ?? 'Tài khoản'}</div><Typography.Text type="secondary">#{row.taiKhoanId}</Typography.Text></> },
    { title: 'Hoạt động', dataIndex: 'actionName', width: 200, render: (value: string) => <Tag>{getAuditActionLabel(value)}</Tag> },
    { title: 'Đối tượng', dataIndex: 'entityName', render: getAuditEntityLabel },
    { title: 'Mã đối tượng', dataIndex: 'entityId', render: (value: string | null) => value || '—' },
    { title: 'Địa chỉ IP', dataIndex: 'ipAddress', render: (value: string | null) => value || '—' },
  ]
  return <section>
    <Space className="page-heading" wrap>
      <Typography.Title level={4} style={{ margin: 0 }}>Nhật ký hoạt động</Typography.Title>
      <Button icon={<ReloadOutlined />} loading={query.isFetching} onClick={() => { void query.refetch(); void accounts.refetch() }}>Làm mới</Button>
    </Space>

    <Space className="filter-bar" wrap style={{ marginBottom: 16 }}>
      <Input aria-label="Tìm nhật ký" placeholder="Tìm tài khoản, hoạt động, đối tượng hoặc IP" value={keyword} onChange={(event) => setKeyword(event.target.value)} allowClear style={{ width: 360, maxWidth: '100%' }} />
      <Select aria-label="Lọc hoạt động" placeholder="Tất cả hoạt động" value={action} onChange={setAction} options={actions} allowClear style={{ width: 200, maxWidth: '100%' }} />
      <Select aria-label="Số bản ghi mới nhất" value={take} onChange={(value) => { setTake(value); setAction(undefined) }} options={[100, 200, 500].map((value) => ({ value, label: `${value} bản ghi mới nhất` }))} style={{ width: 200, maxWidth: '100%' }} />
    </Space>
    {query.isError && <Alert type="error" showIcon message={getApiErrorMessage(query.error, 'Không tải được nhật ký hoạt động.')} action={<Button onClick={() => void query.refetch()}>Thử lại</Button>} style={{ marginBottom: 12 }} />}
    {accounts.isError && <Alert type="warning" showIcon message="Không tải được tên tài khoản. Nhật ký vẫn hiển thị mã người thực hiện." style={{ marginBottom: 12 }} />}
    <Table<AuditLog> className="responsive-table" rowKey="auditLogId" columns={columns} dataSource={rows} loading={query.isLoading} pagination={{ responsive: true, pageSize: 20, showSizeChanger: true }} scroll={{ x: 1000 }} locale={{ emptyText: query.isError ? 'Chưa tải được nhật ký' : 'Không có nhật ký phù hợp' }} />
  </section>
}
