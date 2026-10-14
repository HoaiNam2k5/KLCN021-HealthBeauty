import { useState } from 'react'
import { App as AntApp, Button, DatePicker, Form, Input, Modal, Select, Space } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Staff, StaffRequest } from '../../types/customersStaff'
import { isValidPhone, mapCreateStaffRequest, mapStaffRequest } from '../../types/customersStaff'
import { useDeleteStaff, useSaveStaff, useStaff } from './customerStaffQueries'

interface StaffFormValues { fullName: string; position: string; specialty: string; phone: string; hireDate: Dayjs; email: string; password: string }

export default function StaffPage() {
  const [form] = Form.useForm<StaffFormValues>()
  const [editing, setEditing] = useState<Staff | null>(null)
  const [open, setOpen] = useState(false)
  const [keyword, setKeyword] = useState('')
  const [position, setPosition] = useState<string>()
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const { message } = AntApp.useApp()
  const { has } = usePermissions()
  const canManage = has('STAFF.WRITE')
  const query = useStaff()
  const save = useSaveStaff()
  const remove = useDeleteStaff()
  const staff = query.data ?? []
  const filtered = staff.filter((item) => (!keyword || (item.hoTen ?? '').toLocaleLowerCase().includes(keyword.toLocaleLowerCase())) && (!position || item.chucVu === position))
  const positions = [...new Set(staff.map((item) => item.chucVu).filter((value): value is string => Boolean(value)))].map((value) => ({ value, label: value }))

  function openForm(record?: Staff) {
    if (!canManage) return
    setEditing(record ?? null)
    form.resetFields()
    form.setFieldsValue({ fullName: record?.hoTen ?? '', position: record?.chucVu ?? '', specialty: record?.chuyenMon ?? '', phone: record?.soDienThoai ?? '', hireDate: record ? dayjs(record.ngayVaoLam) : dayjs() })
    setOpen(true)
  }

  async function submit(values: StaffFormValues) {
    if (!canManage || save.isPending) return
    const body: StaffRequest = mapStaffRequest({ fullName: values.fullName, position: values.position, specialty: values.specialty, phone: values.phone, hireDate: values.hireDate.format('YYYY-MM-DD') })
    const request = editing ? body : mapCreateStaffRequest({ ...body, email: values.email, password: values.password })
    try {
      await save.mutateAsync({ id: editing?.nhanVienId, body: request })
      await query.refetch()
      message.success(editing ? 'Cập nhật nhân viên thành công.' : 'Thêm nhân viên thành công.')
      setOpen(false)
      form.resetFields()
    } catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu nhân viên. Vui lòng thử lại.')) }
  }

  async function deleteRecord(record: Staff) {
    if (!canManage) return
    try {
      await remove.mutateAsync(record.nhanVienId)
      message.success('Xóa nhân viên thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa nhân viên. Vui lòng thử lại.'))
      throw error
    }
  }

  return <>
    <ManagementTable<Staff>
      title="Nhân viên" columns={[
        { title: 'Họ tên', dataIndex: 'hoTen', key: 'hoTen', render: (value: string | null) => value || '—' },
        { title: 'Mã tài khoản', dataIndex: 'taiKhoanId', key: 'taiKhoanId', render: (value: number | null | undefined) => value ?? 'Chưa có' },
        { title: 'Chức vụ', dataIndex: 'chucVu', key: 'chucVu', render: (value: string | null) => value || '—' },
        { title: 'Chuyên môn', dataIndex: 'chuyenMon', key: 'chuyenMon', render: (value: string | null) => value || '—' },
        { title: 'Số điện thoại', dataIndex: 'soDienThoai', key: 'soDienThoai', render: (value: string | null) => value || '—' },
        { title: 'Ngày vào làm', dataIndex: 'ngayVaoLam', key: 'ngayVaoLam', render: (value: string) => dayjs(value).format('DD/MM/YYYY') },
      ]} data={filtered} searchFields={['hoTen']} loading={query.isLoading} error={query.isError}
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên nhân viên"
      canManage={canManage} onEdit={openForm} onDelete={deleteRecord}
      onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      toolbar={<Space className="filter-bar" wrap>
        <Select allowClear placeholder="Tất cả chức vụ" style={{ width: 190, maxWidth: '100%' }} value={position} onChange={(value: string | undefined) => { setPosition(value); setPage(1) }} options={positions} />
        {canManage && <Button type="primary" onClick={() => openForm()}>Thêm nhân viên</Button>}
      </Space>}
    />
    {query.isError && <div role="alert">{getApiErrorMessage(query.error, 'Không tải được danh sách nhân viên.')}</div>}
    <Modal className="responsive-modal" title={editing ? 'Sửa nhân viên' : 'Thêm nhân viên'} open={open && canManage} onCancel={() => { if (!save.isPending) { setOpen(false); form.resetFields() } }} maskClosable={!save.isPending} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập họ tên.' }]}><Input maxLength={100} /></Form.Item>
        <Form.Item name="position" label="Chức vụ" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập chức vụ.' }]}><Input maxLength={50} /></Form.Item>
        <Form.Item name="specialty" label="Chuyên môn" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập chuyên môn.' }]}><Input maxLength={255} /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ required: true, message: 'Vui lòng nhập số điện thoại.' }, { validator: async (_, value: string | undefined) => { if (value && !isValidPhone(value)) throw new Error('Vui lòng nhập số điện thoại hợp lệ.') } }]}><Input maxLength={15} /></Form.Item>
        {!editing && <>
          <Form.Item name="email" label="Email đăng nhập" rules={[{ required: true, message: 'Nhập email đăng nhập.' }, { type: 'email', message: 'Email không hợp lệ.' }, { max: 255 }]}><Input autoComplete="off" maxLength={255} /></Form.Item>
          <Form.Item name="password" label="Mật khẩu ban đầu" rules={[{ required: true, message: 'Nhập mật khẩu.' }, { min: 8, message: 'Mật khẩu tối thiểu 8 ký tự.' }, { max: 128 }]}><Input.Password autoComplete="new-password" maxLength={128} /></Form.Item>
        </>}
        <Form.Item name="hireDate" label="Ngày vào làm" rules={[{ required: true, message: 'Vui lòng chọn ngày vào làm.' }]}><DatePicker format="DD/MM/YYYY" style={{ width: '100%' }} /></Form.Item>
      </Form>
    </Modal>
  </>
}
