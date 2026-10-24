import { useEffect, useState } from 'react'
import { App as AntApp, Alert, Button, Checkbox, Empty, Modal, Spin, Table, Tag, Tooltip, Typography } from 'antd'
import type { TableColumnsType } from 'antd'
import axios from 'axios'
import { useQueries, useQueryClient } from '@tanstack/react-query'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import * as permissionsApi from '../../api/permissions'
import type { AdminPermission, RolePermission } from '../../types/permissions'
import { permissionKeys, useAdminPermissions, useAdminRoles, useReloadRolePermissions } from './permissionQueries'
import { currentPermissionKeys, usePermissions } from '../../hooks/usePermissions'
import { supportsPermission } from '../../utils/permissionPolicy'
import { getPermissionGroupLabel, getRoleLabel } from '../../utils/displayLabels'

interface MatrixRow extends AdminPermission { key: number }
type Draft = Record<number, boolean>

export default function PermissionsPage() {
  const { message } = AntApp.useApp()
  const access = usePermissions()
  const canEdit = access.role === ACCOUNT_ROLES.ADMIN && access.has('ROLE.WRITE')
  const queryClient = useQueryClient()
  const rolesQuery = useAdminRoles()
  const permissionsQuery = useAdminPermissions()
  const reloadPermissions = useReloadRolePermissions()
  const roles = rolesQuery.data ?? []
  const permissionRows = permissionsQuery.data ?? []
  const findRole = (name: string) => roles.find((role) => role.tenVaiTro.trim().toLocaleLowerCase() === name.toLocaleLowerCase())
  const adminRole = findRole(ACCOUNT_ROLES.ADMIN)
  const editableRoles = roles.filter((role) => role.roleId !== adminRole?.roleId)
  const roleIds = editableRoles.map((role) => role.roleId)
  const roleQueries = useQueries({ queries: roles.map((role) => ({
    queryKey: permissionKeys.rolePermissions(role.roleId),
    queryFn: () => permissionsApi.getRolePermissions(role.roleId),
  })) })
  const [drafts, setDrafts] = useState<Record<number, Draft>>({})
  const [saving, setSaving] = useState(false)
  const [confirmOpen, setConfirmOpen] = useState(false)
  const currentPermissions: Record<number, RolePermission[] | undefined> = Object.fromEntries(
    roles.map((role, index) => [role.roleId, roleQueries[index]?.data]),
  )
  const invalidateAll = async () => Promise.all([
    rolesQuery.refetch(),
    permissionsQuery.refetch(),
    ...roleIds.map((roleId) => reloadPermissions(roleId)),
    ...(adminRole ? [reloadPermissions(adminRole.roleId)] : []),
    queryClient.invalidateQueries({ queryKey: currentPermissionKeys.all }),
  ])
  const queries = [rolesQuery, permissionsQuery, ...roleQueries]
  const loading = queries.some((query) => query.isLoading)
  const error = queries.find((query) => query.isError)?.error

  useEffect(() => {
    if (error) message.error(getApiErrorMessage(error, 'Không tải được dữ liệu phân quyền.'))
  }, [error, message])

  const changedCells = roleIds.flatMap((roleId) => {
    const original = currentPermissions[roleId] ?? []
    const draft = drafts[roleId] ?? {}
    return permissionRows.flatMap((permission) => {
      const role = editableRoles.find((item) => item.roleId === roleId)
      if (!role || !permission.active || !supportsPermission(role.tenVaiTro, permission.maQuyen)) return []
      const granted = original.find((item) => item.permissionId === permission.permissionId)?.granted ?? false
      return draft[permission.permissionId] !== undefined && draft[permission.permissionId] !== granted
        ? [{ roleId, permissionId: permission.permissionId, granted: draft[permission.permissionId], permissionName: permission.tenQuyen, roleName: getRoleLabel(roles.find((role) => role.roleId === roleId)?.tenVaiTro) }]
        : []
    })
  })

  const columns: TableColumnsType<MatrixRow> = [
    { title: 'Quyền', dataIndex: 'tenQuyen', key: 'permission', width: '48%', render: (_value, record) => <Tooltip title={record.moTa || 'Không có mô tả'}><div><Typography.Text>{record.tenQuyen}</Typography.Text></div></Tooltip> },
    ...(adminRole ? [{ title: 'Quản trị viên', key: 'admin', align: 'center' as const, width: 100, render: (_value: unknown, record: MatrixRow) => <Checkbox checked={record.active && (currentPermissions[adminRole.roleId]?.find((item) => item.permissionId === record.permissionId)?.granted ?? false)} disabled aria-label={`Quản trị viên: ${record.tenQuyen}`} /> }] : []),
    ...editableRoles.map((role) => ({
      title: getRoleLabel(role.tenVaiTro), key: role.roleId, align: 'center' as const, width: 130,
      render: (_value: unknown, record: MatrixRow) => {
        const granted = currentPermissions[role.roleId]?.find((item) => item.permissionId === record.permissionId)?.granted ?? false
        const checked = drafts[role.roleId]?.[record.permissionId] ?? granted
        const changed = checked !== granted
        const supported = supportsPermission(role.tenVaiTro, record.maQuyen)
        const reason = !supported ? 'Quyền này không áp dụng cho vai trò này. Tài khoản và phân quyền chỉ dành cho quản trị viên; nhân viên chỉ xem dữ liệu được phân công.'
          : !record.active ? 'Quyền hệ thống đã ngừng hoạt động.' : !canEdit ? 'Cần quyền quản lý phân quyền để thay đổi.' : undefined
        return <Tooltip title={reason}><Checkbox checked={checked} disabled={!record.active || !supported || !canEdit || saving} onChange={(event) => setDrafts((current) => ({ ...current, [role.roleId]: { ...current[role.roleId], [record.permissionId]: event.target.checked } }))} style={changed ? { outline: '2px solid #B7791F', outlineOffset: 3, borderRadius: 2 } : undefined} aria-label={`${getRoleLabel(role.tenVaiTro)}: ${record.tenQuyen}`} /></Tooltip>
      },
    })),
  ]

  async function saveChanges() {
    if (!canEdit) return
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
        const exactError = getApiErrorMessage(saveError, 'Không thể lưu quyền. Vui lòng thử lại.')
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
  if (permissionRows.length === 0) return <Empty description="Chưa có quyền nào được cấu hình." />

  const groupedRows = permissionRows.reduce<Record<string, MatrixRow[]>>((groups, permission) => {
    const groupName = getPermissionGroupLabel(permission.nhomQuyen)
    groups[groupName] = [...(groups[groupName] ?? []), { ...permission, key: permission.permissionId }]
    return groups
  }, {})

  return <section>
    <div className="page-heading">
      <Typography.Title level={4} style={{ margin: 0 }}>Phân quyền</Typography.Title>
      <div className="page-toolbar">
        <Button disabled={changedCells.length === 0 || saving} onClick={() => setDrafts({})}>Hoàn tác</Button>
        <Button type="primary" disabled={!canEdit || changedCells.length === 0 || saving} loading={saving} onClick={() => setConfirmOpen(true)}>Lưu thay đổi ({changedCells.length})</Button>
      </div>
    </div>

    {Object.entries(groupedRows).map(([groupName, groupItems]) => <div className="permission-group" key={groupName} style={{ marginBottom: 20 }}>
      <Typography.Title level={5}>{groupName}</Typography.Title>
      <Table<MatrixRow> className="responsive-table" rowKey="key" columns={columns} dataSource={groupItems} pagination={false} size="middle" scroll={{ x: 600 }} expandable={{
        expandedRowRender: (record) => <span style={{ color: '#585858' }}>{record.moTa || 'Không có mô tả'}</span>,
        rowExpandable: () => true,
        expandIcon: ({ expanded, onExpand, record }) => <Tooltip title={record.moTa || 'Không có mô tả'}><Button type="link" size="small" onClick={(event) => onExpand(record, event)} aria-label={`Mô tả ${record.tenQuyen}`}>{expanded ? 'Ẩn mô tả' : 'Mô tả'}</Button></Tooltip>,
      }} />
    </div>)}
    <Modal className="responsive-modal" title="Xác nhận lưu thay đổi" open={confirmOpen} onOk={() => { void saveChanges() }} onCancel={() => setConfirmOpen(false)} okText={`Lưu ${changedCells.length} thay đổi`} cancelText="Hủy" confirmLoading={saving}>
      <Typography.Paragraph>Bạn sắp cập nhật {changedCells.length} ô phân quyền.</Typography.Paragraph>
      {changedCells.map((change) => <Tag key={`${change.roleId}-${change.permissionId}`} style={{ marginBottom: 6 }}>{change.roleName}: {change.permissionName}</Tag>)}
    </Modal>
  </section>
}
