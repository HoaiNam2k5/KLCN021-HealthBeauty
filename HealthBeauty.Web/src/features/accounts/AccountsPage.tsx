import { useState } from 'react'
import { Alert, App, Button, Form, Input, Modal, Popconfirm, Select, Space, Table, Tag, Typography } from 'antd'
import type { TableColumnsType } from 'antd'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import * as accountsApi from '../../api/accounts'
import { getStaff } from '../../api/customersStaff'
import { staffAccountOptions } from '../customers-staff/staffAccountOptions'
import type { AdminAccount, CreateAccountRequest } from '../../api/accounts'
import { getApiErrorMessage } from '../../components/apiError'
import { useAdminRoles } from '../permissions/permissionQueries'
import { usePermissions } from '../../hooks/usePermissions'
import { useAuth } from '../../hooks/useAuth'
import { getRoleLabel } from '../../utils/displayLabels'

export default function AccountsPage() {
  const { message } = App.useApp()
  const auth = useAuth()
  const actorId = auth?.account?.id
  const { has } = usePermissions()
  const canWrite = has('ACCOUNT.WRITE')
  const roles = useAdminRoles()
  const [keyword, setKeyword] = useState('')
  const [search, setSearch] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [creating, setCreating] = useState(false)
  const [editing, setEditing] = useState<AdminAccount | null>(null)
  const [saving, setSaving] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)
  const [createForm] = Form.useForm<CreateAccountRequest>()
  const [roleForm] = Form.useForm<{ roleId: number; staffId?: number }>()
  const createRoleId = Form.useWatch('roleId', createForm)
  const editRoleId = Form.useWatch('roleId', roleForm)
  const isStaffRole = (roleId: number | undefined) => roles.data?.some((role) => role.roleId === roleId && role.tenVaiTro === 'Staff') ?? false
  const creatingStaff = creating && isStaffRole(createRoleId)
  const editingStaff = Boolean(editing) && isStaffRole(editRoleId)
  const canReadStaff = has('STAFF.READ')
  const staffQuery = useQuery({ queryKey: ['staff', 'account-link', actorId], queryFn: getStaff, enabled: canWrite && canReadStaff && (creatingStaff || editingStaff) })
  const queryClient = useQueryClient()
  const query = useQuery({ queryKey: ['admin-accounts', actorId, search], queryFn: () => accountsApi.getAccounts(search) })
  const roleOptions = (roles.data ?? []).map((role) => ({ value: role.roleId, label: getRoleLabel(role.tenVaiTro) }))
  const refresh = () => Promise.all([queryClient.invalidateQueries({ queryKey: ['admin-accounts', actorId] }), queryClient.invalidateQueries({ queryKey: ['staff'] })])

  async function submitCreate(body: CreateAccountRequest) {
    if (!canWrite || saving) return
    setSaving(true); setFormError(null)
    try {
      await accountsApi.createAccount({ ...body, staffId: isStaffRole(body.roleId) ? body.staffId : undefined })
      message.success('Đã tạo tài khoản và hồ sơ theo vai trò.')
      setCreating(false); createForm.resetFields(); await refresh()
    } catch (error) { setFormError(getApiErrorMessage(error, 'Không thể tạo tài khoản.')) }
    finally { setSaving(false) }
  }
  async function submitRole(body: { roleId: number; staffId?: number }) {
    if (!editing || !canWrite || saving) return
    setSaving(true); setFormError(null)
    try {
      await accountsApi.assignAccountRole(editing.taiKhoanId, body.roleId, isStaffRole(body.roleId) ? body.staffId : undefined)
      message.success('Đã gán vai trò. Tài khoản cần đăng nhập lại để dùng vai trò mới.')
      setEditing(null); await refresh()
    } catch (error) { setFormError(getApiErrorMessage(error, 'Không thể gán vai trò.')) }
    finally { setSaving(false) }
  }
  async function toggleActive(account: AdminAccount) {
    if (!canWrite) return
    try { await accountsApi.setAccountActive(account.taiKhoanId, !account.trangThai); await refresh(); message.success('Đã cập nhật trạng thái tài khoản.') }
    catch (error) { message.error(getApiErrorMessage(error, 'Không thể cập nhật tài khoản.')) }
  }
  const columns: TableColumnsType<AdminAccount> = [
    { title: 'STT', key: 'stt', width: 64, align: 'center', render: (_value, _account, index) => (page - 1) * pageSize + index + 1 },
    { title: 'Email', dataIndex: 'email' },
    { title: 'Họ tên', render: (_, account) => account.fullName || account.tenTaiKhoan || '—' },
    { title: 'Vai trò', dataIndex: 'role', render: (role: string) => <Tag>{getRoleLabel(role)}</Tag> },
    { title: 'Trạng thái', render: (_, account) => <Tag color={account.trangThai ? 'green' : 'default'}>{account.trangThai ? 'Hoạt động' : 'Đã khóa'}</Tag> },
    ...(canWrite ? [{ title: 'Thao tác', key: 'actions', render: (_: unknown, account: AdminAccount) => <Space wrap>
      <Button size="small" disabled={roles.isError || roles.isLoading || account.taiKhoanId === actorId} onClick={() => { setFormError(null); roleForm.resetFields(); roleForm.setFieldsValue({ roleId: account.roleId, staffId: undefined }); setEditing(account) }}>Gán vai trò</Button>
      <Popconfirm title={account.trangThai ? 'Khóa tài khoản này?' : 'Mở khóa tài khoản này?'} description={account.trangThai ? 'Tài khoản sẽ không thể tiếp tục truy cập.' : undefined} onConfirm={() => toggleActive(account)} okText="Xác nhận" cancelText="Hủy">
        <Button size="small" danger={account.trangThai} disabled={account.taiKhoanId === actorId}>{account.trangThai ? 'Khóa' : 'Mở khóa'}</Button>
      </Popconfirm>
    </Space> }] : []),
  ]
  return <section>
    <Space className="page-heading" wrap>
      <Typography.Title level={4} style={{ margin: 0 }}>Tài khoản người dùng</Typography.Title>
      {canWrite && <Button type="primary" disabled={roles.isError || roles.isLoading} onClick={() => { createForm.resetFields(); setFormError(null); setCreating(true) }}>Tạo tài khoản</Button>}
    </Space>

    {roles.isError && <Alert type="error" showIcon message="Không tải được vai trò. Cần quyền xem vai trò và quyền để chọn vai trò khi tạo hoặc sửa tài khoản." action={<Button onClick={() => void roles.refetch()}>Thử lại</Button>} style={{ marginBottom: 12 }} />}
    <Input.Search className="filter-search" aria-label="Tìm tài khoản" placeholder="Tìm email hoặc tên tài khoản" value={keyword} onChange={(event) => setKeyword(event.target.value)} onSearch={() => { setSearch(keyword.trim()); setPage(1) }} allowClear enterButton style={{ width: '100%', maxWidth: 420, marginBottom: 16 }} />
    {query.isError && <Alert type="error" showIcon message={getApiErrorMessage(query.error, 'Không tải được tài khoản.')} action={<Button onClick={() => void query.refetch()}>Thử lại</Button>} style={{ marginBottom: 12 }} />}
    <Table<AdminAccount> className="responsive-table" rowKey="taiKhoanId" columns={columns} dataSource={query.data ?? []} loading={query.isLoading} pagination={{ responsive: true, current: page, pageSize, showSizeChanger: true, onChange: (nextPage, size) => { setPage(size !== pageSize ? 1 : nextPage); setPageSize(size) } }} scroll={{ x: 814 }} />

    <Modal className="responsive-modal" title="Tạo tài khoản người dùng" open={creating && canWrite} onCancel={() => { if (!saving) { setCreating(false); createForm.resetFields() } }} onOk={() => createForm.submit()} confirmLoading={saving} okText="Tạo tài khoản" cancelText="Hủy" maskClosable={!saving}>
      {formError && <Alert type="error" showIcon message={formError} style={{ marginBottom: 12 }} />}
      <Form name="create-account" className="responsive-form" form={createForm} layout="vertical" onFinish={(body) => void submitCreate(body)}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Nhập họ tên.' }, { max: 100 }]}><Input maxLength={100} /></Form.Item>
        <Form.Item name="email" label="Email" rules={[{ required: true, message: 'Nhập email.' }, { type: 'email', message: 'Email không hợp lệ.' }, { max: 255 }]}><Input autoComplete="off" maxLength={255} /></Form.Item>
        <Form.Item name="password" label="Mật khẩu ban đầu" rules={[{ required: true, message: 'Nhập mật khẩu.' }, { min: 8, message: 'Mật khẩu tối thiểu 8 ký tự.' }, { max: 128 }]}><Input.Password autoComplete="new-password" maxLength={128} /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ max: 15 }, { pattern: /^\+?[0-9][0-9\s().-]*$/, message: 'Số điện thoại không hợp lệ.' }]}><Input maxLength={15} /></Form.Item>
        <Form.Item name="roleId" label="Vai trò" rules={[{ required: true, message: 'Chọn vai trò.' }]}><Select options={roleOptions} loading={roles.isLoading} onChange={() => createForm.setFieldValue('staffId', undefined)} /></Form.Item>
        {creatingStaff && canReadStaff && <Form.Item name="staffId" label="Liên kết nhân viên hiện có">
          <Select allowClear showSearch optionFilterProp="label" placeholder="Để trống để tạo hồ sơ nhân viên mới" options={staffAccountOptions(staffQuery.data ?? [])} loading={staffQuery.isFetching} disabled={staffQuery.isError} />
        </Form.Item>}
        {creatingStaff && canReadStaff && staffQuery.isError && <Alert type="error" showIcon message={getApiErrorMessage(staffQuery.error, 'Không tải được danh sách nhân viên.')} action={<Button onClick={() => void staffQuery.refetch()}>Thử lại</Button>} />}
      </Form>
    </Modal>
    <Modal className="responsive-modal" title={`Gán vai trò: ${editing?.email ?? ''}`} open={Boolean(editing) && canWrite} onCancel={() => { if (!saving) setEditing(null) }} onOk={() => roleForm.submit()} confirmLoading={saving} okText="Lưu vai trò" cancelText="Hủy" maskClosable={!saving}>
      {formError && <Alert type="error" showIcon message={formError} style={{ marginBottom: 12 }} />}
      <Alert type="warning" showIcon message="Phiên đăng nhập cũ sẽ không còn dùng được sau khi đổi vai trò." style={{ marginBottom: 12 }} />
      <Form name="assign-account-role" className="responsive-form" form={roleForm} layout="vertical" onFinish={(body) => void submitRole(body)}><Form.Item name="roleId" label="Vai trò" rules={[{ required: true, message: 'Chọn vai trò.' }]}><Select options={roleOptions} onChange={() => roleForm.setFieldValue('staffId', undefined)} /></Form.Item>
        {editingStaff && canReadStaff && <Form.Item name="staffId" label="Liên kết nhân viên hiện có">
          <Select allowClear showSearch optionFilterProp="label" placeholder="Giữ hồ sơ hiện tại hoặc tạo mới nếu chưa có" options={staffAccountOptions(staffQuery.data ?? [], editing?.taiKhoanId)} loading={staffQuery.isFetching} disabled={staffQuery.isError} />
        </Form.Item>}
        {editingStaff && canReadStaff && staffQuery.isError && <Alert type="error" showIcon message={getApiErrorMessage(staffQuery.error, 'Không tải được danh sách nhân viên.')} action={<Button onClick={() => void staffQuery.refetch()}>Thử lại</Button>} />}
      </Form>
    </Modal>
  </section>
}
