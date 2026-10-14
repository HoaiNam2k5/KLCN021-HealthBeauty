import { useState } from 'react'
import { Alert, App, Button, Form, Input, Modal, Select } from 'antd'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Customer, UpdateCustomerRequest } from '../../types/customersStaff'
import { useCustomers, useUpdateCustomer } from './customerStaffQueries'

export default function CustomersPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [editing, setEditing] = useState<Customer | null>(null)
  const [form] = Form.useForm<UpdateCustomerRequest>()
  const { message } = App.useApp()
  const { has } = usePermissions()
  const canEdit = has('CUSTOMER.WRITE')
  const query = useCustomers(keyword)
  const update = useUpdateCustomer()

  function edit(customer: Customer) {
    if (!canEdit) return
    form.setFieldsValue({ fullName: customer.fullName ?? '', phone: customer.phone, gender: customer.gender })
    setEditing(customer)
  }

  async function submit(body: UpdateCustomerRequest) {
    if (!canEdit || !editing) return
    try {
      await update.mutateAsync({ id: editing.id, body })
      message.success('Cập nhật khách hàng thành công.')
      setEditing(null)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể cập nhật khách hàng.')) }
  }

  return <>
    {query.isError && <Alert type="error" showIcon message="Không tải được danh sách khách hàng" description={getApiErrorMessage(query.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    <ManagementTable<Customer>
      title="Khách hàng"
      columns={[
        { title: 'Họ tên', dataIndex: 'fullName', key: 'fullName', render: (value: string | null) => value || '—' },
        { title: 'Số điện thoại', dataIndex: 'phone', key: 'phone', render: (value: string | null) => value || '—' },
        { title: 'Giới tính', dataIndex: 'gender', key: 'gender', render: (value: string | null) => value || '—' },
        { title: 'Điểm thưởng', dataIndex: 'rewardPoints', key: 'rewardPoints', render: (value: number) => value.toLocaleString('vi-VN') },
        ...(canEdit ? [{ title: 'Thao tác', key: 'edit', render: (_: unknown, customer: Customer) => <Button type="link" onClick={() => edit(customer)}>Sửa</Button> }] : []),
      ]}
      data={query.data ?? []} searchFields={['fullName', 'phone']} loading={query.isLoading} error={query.isError}
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên hoặc số điện thoại"
      canManage={false} onEdit={edit} onDelete={() => undefined}
    />
    <Modal className="responsive-modal" title="Sửa khách hàng" open={editing !== null && canEdit} onCancel={() => setEditing(null)} onOk={() => form.submit()} confirmLoading={update.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={(body) => void submit(body)}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập họ tên.' }, { max: 100 }]}><Input maxLength={100} /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ max: 15 }, { pattern: /^\+?[0-9][0-9\s().-]*$/, message: 'Số điện thoại không hợp lệ.' }]}><Input maxLength={15} /></Form.Item>
        <Form.Item name="gender" label="Giới tính"><Select allowClear options={[{ value: 'Nam', label: 'Nam' }, { value: 'Nữ', label: 'Nữ' }, { value: 'Khác', label: 'Khác' }]} /></Form.Item>
      </Form>
    </Modal>
  </>
}
