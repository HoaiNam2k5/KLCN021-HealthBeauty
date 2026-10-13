import { useEffect, useState } from 'react'
import { App as AntApp, Alert, Button, Checkbox, Empty, Modal, Spin, Table, Tag, Tooltip, Typography } from 'antd'
import type { TableColumnsType } from 'antd'
import axios from 'axios'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import * as permissionsApi from '../../api/permissions'
import type { AdminRole, AdminPermission, RolePermission } from '../../types/permissions'
import { useAdminPermissions, useAdminRoles, useReloadRolePermissions, useRolePermissions } from './permissionQueries'

interface MatrixRow extends AdminPermission { key: number }
type Draft = Record<number, boolean>

export default function PermissionsPage() {
  const { message } = AntApp.useApp()
  const rolesQuery = useAdminRoles()
  const permissionsQuery = useAdminPermissions()
  const reloadPermissions = useReloadRolePermissions()
  const roles = rolesQuery.data ?? []
  const permissionRows = permissionsQuery.data ?? []
  const findRole = (name: string) => roles.find((role) => role.tenVaiTro.trim().toLocaleLowerCase() === name.toLocaleLowerCase())
  const adminRole = findRole(ACCOUNT_ROLES.ADMIN)
  const receptionRole = findRole(ACCOUNT_ROLES.RECEPTION)
  const staffRole = findRole(ACCOUNT_ROLES.STAFF)
  const roleIds = [receptionRole?.roleId, staffRole?.roleId].filter((id): id is number => id !== undefined)
  const receptionQuery = useRolePermissions(receptionRole?.roleId)
  const staffQuery = useRolePermissions(staffRole?.roleId)
  const [drafts, setDrafts] = useState<Record<number, Draft>>({})
  const [saving, setSaving] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const currentPermissions: Record<number, RolePermission[] | undefined> = {
    [receptionRole?.roleId ?? -1]: receptionQuery.data,
    [staffRole?.roleId ?? -1]: staffQuery.data,
  }
  const invalidateAll = async () => Promise.all([
    rolesQuery.refetch(),
    permissionsQuery.refetch(),
    ...roleIds.map((roleId) => reloadPermissions(roleId)),
  ])
  const queries = [rolesQuery, permissionsQuery, receptionQuery, staffQuery]
  const loading = queries.some((query) => query.isLoading)
  const error = queries.find((query) => query.isError)?.error

  useEffect(() => {
    if (error) message.error(getApiErrorMessage(error, 'Không tải được dữ liệu phân quyền.'))
  }, [error, message])

  const changedCells = roleIds.flatMap((roleId) => {
    const original = currentPermissions[roleId] ?? []
    const draft = drafts[roleId] ?? {}
    return permissionRows.flatMap((permission) => {
      const granted = original.find((item) => item.permissionId === permission.permissionId)?.granted ?? false
      return draft[permission.permissionId] !== undefined && draft[permission.permissionId] !== granted
        ? [{ roleId, permissionId: permission.permissionId, granted: draft[permission.permissionId], permissionName: permission.tenQuyen, roleName: roles.find((role) => role.roleId === roleId)?.tenVaiTro ?? '' }]
        : []
    })
  })

  const columns: TableColumnsType<MatrixRow> = [
    { title: 'Quyền', dataIndex: 'tenQuyen', key: 'permission', width: '48%', render: (_value, record) => <Tooltip title={record.moTa || 'Không có mô tả'}><div><Typography.Text>{record.tenQuyen}</Typography.Text><br /><Typography.Text type="secondary" style={{ fontSize: 12 }}>{record.maQuyen}</Typography.Text></div></Tooltip> },
    { title: 'Admin', key: 'admin', align: 'center', width: 100, render: () => <Checkbox checked disabled aria-label="Admin luôn có quyền" /> },
    ...[receptionRole, staffRole].filter((role): role is AdminRole => role !== undefined).map((role) => ({
      title: role.tenVaiTro, key: role.roleId, align: 'center' as const, width: 130,
      render: (_value: unknown, record: MatrixRow) => {
        const granted = currentPermissions[role.roleId]?.find((item) => item.permissionId === record.permissionId)?.granted ?? false
        const checked = drafts[role.roleId]?.[record.permissionId] ?? granted
        const changed = checked !== granted
        return <Checkbox checked={checked} onChange={(event) => setDrafts((current) => ({ ...current, [role.roleId]: { ...current[role.roleId], [record.permissionId]: event.target.checked } }))} style={changed ? { outline: '2px solid #B7791F', outlineOffset: 3, borderRadius: 2 } : undefined} aria-label={`${role.tenVaiTro}: ${record.tenQuyen}`} />
      },
    })),
  ]

  async function saveChanges() {
    setConfirmOpen(false)
    setSaving(true)
    let succeeded = 0
    let failed = 0
    for (const change of changedCells) {
      try {
        await permissionsApi.updateRolePermission(change.roleId, { permissionId: change.permissionId, granted: change.granted })
        succeeded += 1
        message.success(`${change.roleName} · ${change.permissionName}: đã lưu.`)
      } catch (saveError: unknown) {
        failed += 1
        const exactError = axios.isAxiosError(saveError)
          ? `${saveError.response?.status ?? 'Network error'}: ${typeof saveError.response?.data === 'string' ? saveError.response.data : JSON.stringify(saveError.response?.data ?? saveError.message)}`
          : saveError instanceof Error ? saveError.message : String(saveError)
        message.error(`${change.roleName} · ${change.permissionName}: ${exactError}`)
      }
    }
    if (succeeded > 0) {
      setDrafts({})
      await invalidateAll()
    }
    if (succeeded === 0 && failed === 0) message.info('Không có thay đổi cần lưu.')
    setSaving(false)
  }

  if (loading) return <div className="route-loading"><Spin size="large" /></div>
  if (error) {
    const forbidden = axios.isAxiosError(error) && error.response?.status === 403
    return <Alert type="error" showIcon message={forbidden ? 'Bạn không có quyền thực hiện thao tác này' : 'Không tải được dữ liệu phân quyền'} description={forbidden ? undefined : getApiErrorMessage(error, 'Vui lòng thử tải lại trang.')} action={<Button onClick={() => { void invalidateAll() }}>Thử lại</Button>} />
  }
  const missingRoles = [!adminRole ? ACCOUNT_ROLES.ADMIN : null, !receptionRole ? ACCOUNT_ROLES.RECEPTION : null, !staffRole ? ACCOUNT_ROLES.STAFF : null].filter((role): role is typeof ACCOUNT_ROLES.ADMIN | typeof ACCOUNT_ROLES.RECEPTION | typeof ACCOUNT_ROLES.STAFF => role !== null)
  if (missingRoles.length > 0) return <Alert type="error" showIcon message={`Không tìm thấy vai trò: ${missingRoles.join(', ')}. Vui lòng kiểm tra danh sách vai trò từ máy chủ.`} />
  if (permissionRows.length === 0) return <Empty description="Chưa có quyền nào được cấu hình." />

  const groupedRows = permissionRows.reduce<Record<string, MatrixRow[]>>((groups, permission) => {
    const groupName = permission.nhomQuyen || 'Khác'
    groups[groupName] = [...(groups[groupName] ?? []), { ...permission, key: permission.permissionId }]
    return groups
  }, {})

  return <section>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16, marginBottom: 16, flexWrap: 'wrap' }}>
      <Typography.Title level={4} style={{ margin: 0 }}>Phân quyền</Typography.Title>
      <div style={{ display: 'flex', gap: 8 }}>
        <Button disabled={changedCells.length === 0 || saving} onClick={() => setDrafts({})}>Hoàn tác</Button>
        <Button type="primary" disabled={changedCells.length === 0 || saving} loading={saving} onClick={() => setConfirmOpen(true)}>Lưu thay đổi ({changedCells.length})</Button>
      </div>
    </div>
    <Alert type="info" showIcon message="Việc gán quyền có hiệu lực với giao diện và máy chủ khi backend áp dụng kiểm tra theo quyền (TODO chờ Nam)." style={{ marginBottom: 16 }} />
    {Object.entries(groupedRows).map(([groupName, groupItems]) => <div key={groupName} style={{ marginBottom: 20 }}>
      <Typography.Title level={5}>{groupName}</Typography.Title>
      <Table<MatrixRow> rowKey="key" columns={columns} dataSource={groupItems} pagination={false} size="middle" scroll={{ x: 600 }} expandable={{
        expandedRowRender: (record) => <span style={{ color: '#585858' }}>{record.moTa || 'Không có mô tả'}</span>,
        rowExpandable: () => true,
        expandIcon: ({ expanded, onExpand, record }) => <Tooltip title={record.moTa || 'Không có mô tả'}><Button type="link" size="small" onClick={(event) => onExpand(record, event)} aria-label={`Mô tả ${record.tenQuyen}`}>{expanded ? 'Ẩn mô tả' : 'Mô tả'}</Button></Tooltip>,
      }} />
    </div>)}
    <Modal title="Xác nhận lưu thay đổi" open={confirmOpen} onOk={() => { void saveChanges() }} onCancel={() => setConfirmOpen(false)} okText={`Lưu ${changedCells.length} thay đổi`} cancelText="Hủy" confirmLoading={saving}>
      <Typography.Paragraph>Bạn sắp cập nhật {changedCells.length} ô phân quyền. Mỗi ô sẽ được lưu riêng; kết quả thành công hoặc thất bại sẽ được thông báo.</Typography.Paragraph>
      {changedCells.map((change) => <Tag key={`${change.roleId}-${change.permissionId}`} style={{ marginBottom: 6 }}>{change.roleName}: {change.permissionName}</Tag>)}
    </Modal>
  </section>
}
