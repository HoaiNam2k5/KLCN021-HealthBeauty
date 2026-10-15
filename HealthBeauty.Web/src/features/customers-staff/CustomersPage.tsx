import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Descriptions, Drawer, Empty, Form, Input, Modal, Select, Space, Statistic, Table, Tabs, Tag } from 'antd'
import dayjs from 'dayjs'
import type { Appointment } from '../../types/appointments'
import type { Invoice } from '../../types/billing'
import { APPOINTMENT_STATUS, getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import { useAllAppointments } from '../appointments/appointmentQueries'
import { INVOICE_STATUS, INVOICE_STATUS_LABELS } from '../billing/billingConstants'
import { useInvoices } from '../billing/billingQueries'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Customer, UpdateCustomerRequest } from '../../types/customersStaff'
import { useCustomers, useUpdateCustomer } from './customerStaffQueries'

function membership(points: number) {
  if (points >= 2000) return { label: 'Kim Cương', color: 'purple' }
  if (points >= 1000) return { label: 'Vàng', color: 'gold' }
  if (points >= 300) return { label: 'Bạc', color: 'blue' }
  return { label: 'Đồng', color: 'default' }
}

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

export default function CustomersPage() {
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
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
  const appointmentsQuery = useAllAppointments()
  const invoicesQuery = useInvoices()
  const customerAppointments = useMemo(() => (appointmentsQuery.data ?? []).filter((item: Appointment) => item.customerId === selectedCustomer?.id).sort((a, b) => dayjs(b.appointmentAt).valueOf() - dayjs(a.appointmentAt).valueOf()), [appointmentsQuery.data, selectedCustomer?.id])
  const customerInvoices = useMemo(() => (invoicesQuery.data ?? []).filter((item: Invoice) => item.customerId === selectedCustomer?.id).sort((a, b) => dayjs(b.createdAt).valueOf() - dayjs(a.createdAt).valueOf()), [invoicesQuery.data, selectedCustomer?.id])
  const spent = customerInvoices.filter((invoice) => invoice.status === INVOICE_STATUS.PAID).reduce((total, invoice) => total + invoice.total, 0)
  const appointmentColumns = [
    { title: 'Mã lịch', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Ngày thực hiện', dataIndex: 'appointmentAt', key: 'appointmentAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Dịch vụ / Combo', dataIndex: 'items', key: 'items', render: (items: Appointment['items']) => items.map((item) => item.comboId ? `Combo: ${item.serviceName}` : item.serviceName).join(', ') || '—' },
    { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: (status: string) => { const presentation = getAppointmentStatusPresentation(status); return <Tag style={{ color: presentation.color, background: presentation.background, borderColor: 'transparent' }}>{presentation.label}</Tag> } },
  ]
  const invoiceColumns = [
    { title: 'Mã HĐ', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Ngày lập', dataIndex: 'createdAt', key: 'createdAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Tạm tính', dataIndex: 'subtotal', key: 'subtotal', render: (value: number) => money(value) },
    { title: 'Tổng tiền', dataIndex: 'total', key: 'total', render: (value: number) => money(value) },
    { title: 'Thanh toán', dataIndex: 'status', key: 'status', render: (status: string) => <Tag color={status === INVOICE_STATUS.PAID ? 'success' : 'warning'}>{INVOICE_STATUS_LABELS[status] ?? status}</Tag> },
  ]
  const historyTabs = selectedCustomer ? [
    { key: 'overview', label: 'Tổng quan', children: <Space direction="vertical" size="middle" style={{ width: '100%' }}><Card><Descriptions column={2} title={selectedCustomer.fullName || 'Hồ sơ khách hàng'}><Descriptions.Item label="Số điện thoại">{selectedCustomer.phone || '—'}</Descriptions.Item><Descriptions.Item label="Giới tính">{selectedCustomer.gender || '—'}</Descriptions.Item><Descriptions.Item label="Hạng thành viên"><Tag color={membership(selectedCustomer.rewardPoints).color} style={{ fontSize: 16, padding: '4px 12px' }}>{membership(selectedCustomer.rewardPoints).label}</Tag></Descriptions.Item><Descriptions.Item label="Điểm thưởng">{selectedCustomer.rewardPoints.toLocaleString('vi-VN')}</Descriptions.Item></Descriptions></Card><Space wrap style={{ width: '100%' }}><Card><Statistic title="Tổng lịch hẹn" value={customerAppointments.length} /></Card><Card><Statistic title="Đã hoàn thành" value={customerAppointments.filter((item) => item.status === APPOINTMENT_STATUS.COMPLETED).length} /></Card><Card><Statistic title="Tổng chi tiêu" value={money(spent)} /></Card></Space></Space> },
    { key: 'appointments', label: 'Lịch sử Lịch hẹn', children: customerAppointments.length ? <Table<Appointment> rowKey="id" size="small" scroll={{ x: 'max-content' }} pagination={{ pageSize: 5 }} dataSource={customerAppointments} columns={appointmentColumns} /> : <Empty description="Chưa có lịch sử" /> },
    { key: 'invoices', label: 'Lịch sử Hóa đơn', children: customerInvoices.length ? <Table<Invoice> rowKey="id" size="small" scroll={{ x: 'max-content' }} pagination={{ pageSize: 5 }} dataSource={customerInvoices} columns={invoiceColumns} /> : <Empty description="Chưa có lịch sử" /> },
  ] : []

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
        { title: 'Hạng thành viên', key: 'membership', render: (_: unknown, customer: Customer) => <Tag color={membership(customer.rewardPoints).color}>{membership(customer.rewardPoints).label}</Tag> },
        { title: 'Thao tác', key: 'actions', render: (_: unknown, customer: Customer) => <Space><Button type="link" onClick={() => setSelectedCustomer(customer)}>Lịch sử</Button>{canEdit && <Button type="link" onClick={() => edit(customer)}>Sửa</Button>}</Space> },
      ]}
      data={query.data ?? []} searchFields={['fullName', 'phone']} loading={query.isLoading} error={query.isError}
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên hoặc số điện thoại"
      canManage={false} onEdit={edit} onDelete={() => undefined}
    />
    <Drawer title="Hồ sơ & Lịch sử khách hàng" open={selectedCustomer !== null} onClose={() => setSelectedCustomer(null)} width={680} size="large">
      {selectedCustomer && <Tabs items={historyTabs} />}
    </Drawer>
    <Modal className="responsive-modal" title="Sửa khách hàng" open={editing !== null && canEdit} onCancel={() => setEditing(null)} onOk={() => form.submit()} confirmLoading={update.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={(body) => void submit(body)}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập họ tên.' }, { max: 100 }]}><Input maxLength={100} /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ max: 15 }, { pattern: /^\+?[0-9][0-9\s().-]*$/, message: 'Số điện thoại không hợp lệ.' }]}><Input maxLength={15} /></Form.Item>
        <Form.Item name="gender" label="Giới tính"><Select allowClear options={[{ value: 'Nam', label: 'Nam' }, { value: 'Nữ', label: 'Nữ' }, { value: 'Khác', label: 'Khác' }]} /></Form.Item>
      </Form>
    </Modal>
  </>
}
