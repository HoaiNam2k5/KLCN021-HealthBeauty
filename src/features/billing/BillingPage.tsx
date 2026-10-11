import { useMemo, useState } from 'react'
import { Alert, App, Button, DatePicker, Descriptions, Drawer, Empty, Form, Input, InputNumber, Modal, Select, Space, Table, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs, { type Dayjs } from 'dayjs'
import type { Appointment } from '../../types/appointments'
import type { CreateInvoiceRequest, Invoice, InvoiceLineRequest, PaymentRequest } from '../../types/billing'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import { useAuth } from '../../hooks/useAuth'
import { useAppointmentCustomers, useAppointments } from '../appointments/appointmentQueries'
import { useCombos, useServices } from '../services/serviceQueries'
import { useCustomers } from '../customers-staff/customerStaffQueries'
import { INVOICE_STATUS, INVOICE_STATUS_LABELS, PAYMENT_METHOD, PAYMENT_METHOD_OPTIONS, PAYMENT_METHOD_LABELS, PAYMENT_STATUS, PAYMENT_STATUS_LABELS, PAYMENT_STATUS_OPTIONS } from './billingConstants'
import { useCreateInvoice, useInvoices, useRecordInvoicePayment } from './billingQueries'

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`
const writableRoles: string[] = [ACCOUNT_ROLES.ADMIN, ACCOUNT_ROLES.MANAGER, ACCOUNT_ROLES.RECEPTION]
type CreateFields = { appointmentId: number; voucherCode?: string; pointsToRedeem?: number }
type PaymentFields = { method: string; status: string }

export default function BillingPage() {
  const { message } = App.useApp()
  const session = useAuth()
  const canWrite = writableRoles.includes(session?.account?.role ?? '')
  const invoices = useInvoices()
  const customers = useCustomers('')
  const appointments = useAppointments()
  const catalogCustomers = useAppointmentCustomers()
  const services = useServices()
  const combos = useCombos()
  const createInvoice = useCreateInvoice()
  const recordPayment = useRecordInvoicePayment()
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState<string>()
  const [range, setRange] = useState<[Dayjs | null, Dayjs | null] | null>(null)
  const [selected, setSelected] = useState<Invoice | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [createForm] = Form.useForm<CreateFields>()
  const [paymentForm] = Form.useForm<PaymentFields>()
  const customerNames = useMemo(() => new Map((customers.data ?? []).map((customer) => [customer.id, customer.fullName])), [customers.data])
  const list = useMemo(() => invoices.data ?? [], [invoices.data])
  const filtered = useMemo(() => list.filter((invoice) => {
    const matchesCustomer = !keyword || (customerNames.get(invoice.customerId) ?? '').toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase())
    const matchesStatus = !status || invoice.status === status
    const date = dayjs(invoice.createdAt)
    const matchesDate = !range || (!range[0] || !date.isBefore(range[0].startOf('day'))) && (!range[1] || !date.isAfter(range[1].endOf('day')))
    return matchesCustomer && matchesStatus && matchesDate
  }), [list, keyword, status, range, customerNames])

  async function submitCreate(values: CreateFields) {
    const appointment = appointments.data?.find((item) => item.id === values.appointmentId)
    if (!appointment) return
    const comboIds = new Set<number>()
    const items: InvoiceLineRequest[] = []
    appointment.items.forEach((item) => {
      if (item.comboId !== null) comboIds.add(item.comboId)
      else items.push({ serviceId: item.serviceId, comboId: null, quantity: 1 })
    })
    comboIds.forEach((comboId) => items.push({ serviceId: null, comboId, quantity: 1 }))
    const body: CreateInvoiceRequest = { appointmentId: appointment.id, items, voucherCode: values.voucherCode?.trim() || null, pointsToRedeem: values.pointsToRedeem ?? 0 }
    try {
      await createInvoice.mutateAsync(body)
      message.success('Tạo hóa đơn thành công'); setCreateOpen(false); createForm.resetFields()
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể tạo hóa đơn')) }
  }

  async function submitPayment(values: PaymentFields) {
    if (!selected) return
    try {
      await recordPayment.mutateAsync({ id: selected.id, body: values as PaymentRequest })
      message.success('Ghi nhận thanh toán thành công'); setSelected(null)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể ghi nhận thanh toán')) }
  }

  const appointmentOptions = (appointments.data ?? []).map((appointment: Appointment) => ({
    value: appointment.id,
    label: `Lịch #${appointment.id} · ${catalogCustomers.data?.find((customer) => customer.id === appointment.customerId)?.fullName ?? `Khách #${appointment.customerId}`} · ${appointment.status}${appointment.status !== 'HoanThanh' ? ' (chưa hoàn thành)' : ''}`,
  }))
  const columns: ColumnsType<Invoice> = [
    { title: 'Mã hóa đơn', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Mã lịch hẹn', dataIndex: 'appointmentId', key: 'appointmentId', render: (id: number) => `#${id}` },
    { title: 'Khách hàng', dataIndex: 'customerId', key: 'customerId', render: (id: number) => customerNames.get(id) ?? `#${id}` },
    { title: 'Ngày tạo', dataIndex: 'createdAt', key: 'createdAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Tạm tính', dataIndex: 'subtotal', key: 'subtotal', align: 'right', render: (value: number) => money(value) },
    { title: 'Tổng tiền', dataIndex: 'total', key: 'total', align: 'right', render: (value: number) => money(value) },
    { title: 'Thanh toán', dataIndex: 'status', key: 'status', render: (value: string) => <Tag color={value === INVOICE_STATUS.PAID ? 'success' : value === INVOICE_STATUS.UNPAID ? 'warning' : undefined}>{INVOICE_STATUS_LABELS[value] ?? value}</Tag> },
    { title: 'Phương thức', key: 'method', render: (_, invoice) => invoice.payments.length ? invoice.payments.map((payment) => payment.method).join(', ') : '—' },
  ]

  return <section>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16, flexWrap: 'wrap', marginBottom: 20 }}>
      <Typography.Title level={4} style={{ margin: 0 }}>Hóa đơn và thanh toán</Typography.Title>
      <Space wrap>
        <Input allowClear value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Tìm theo tên khách" style={{ width: 220 }} />
        <Select allowClear value={status} onChange={setStatus} placeholder="Trạng thái thanh toán" style={{ width: 210 }} options={[...new Set(list.map((invoice) => invoice.status))].map((value) => ({ value, label: INVOICE_STATUS_LABELS[value] ?? value }))} />
        <DatePicker.RangePicker value={range} onChange={setRange} format="DD/MM/YYYY" />
        {canWrite && <Button type="primary" onClick={() => setCreateOpen(true)}>Tạo hóa đơn</Button>}
      </Space>
    </div>
    {invoices.isError && <Alert type="error" showIcon message="Không tải được danh sách hóa đơn" description={getApiErrorMessage(invoices.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    {customers.isError && <Alert type="warning" message="Không tải được tên khách hàng." style={{ marginBottom: 16 }} />}
    <div className="table-scroll-container"><Table<Invoice> scroll={{ x: 'max-content' }} rowKey="id" columns={columns} dataSource={filtered} loading={invoices.isLoading || customers.isLoading} onRow={(invoice) => ({ onClick: () => setSelected(invoice), style: { cursor: 'pointer' } })} locale={{ emptyText: <Empty description={invoices.isError ? 'Không có dữ liệu để hiển thị' : 'Chưa có hóa đơn'} /> }} pagination={{ pageSize: 10, showSizeChanger: true, pageSizeOptions: [10, 20, 50], showTotal: (count) => `Tổng ${count} hóa đơn` }} /></div>
    <Drawer title={`Chi tiết hóa đơn #${selected?.id ?? ''}`} open={Boolean(selected)} onClose={() => setSelected(null)} width={640}>
      {selected && <>
        <Descriptions column={1} bordered size="small">
          <Descriptions.Item label="Lịch hẹn">#{selected.appointmentId}</Descriptions.Item>
          <Descriptions.Item label="Khách hàng">{customerNames.get(selected.customerId) ?? `#${selected.customerId}`}</Descriptions.Item>
          <Descriptions.Item label="Ngày tạo">{dayjs(selected.createdAt).format('DD/MM/YYYY HH:mm')}</Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5}>Các dòng hóa đơn</Typography.Title>
        <Table rowKey="id" size="small" pagination={false} dataSource={selected.items} columns={[{ title: 'Dịch vụ / combo', render: (_, item) => item.serviceName ?? item.comboName ?? (item.serviceId !== null ? services.data?.find((s) => s.id === item.serviceId)?.name : null) ?? (item.comboId !== null ? combos.data?.find((c) => c.id === item.comboId)?.name : null) ?? 'Không rõ tên' }, { title: 'SL', dataIndex: 'quantity' }, { title: 'Đơn giá', dataIndex: 'unitPrice', render: (value: number) => money(value) }]} />
        <Descriptions column={1} bordered size="small" style={{ marginTop: 16 }}>
          <Descriptions.Item label="Tạm tính">{money(selected.subtotal)}</Descriptions.Item>
          <Descriptions.Item label="Chênh lệch tạm tính và tổng">{money(selected.subtotal - selected.total)}</Descriptions.Item>
          <Descriptions.Item label="Tổng">{money(selected.total)}</Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5}>Các lần thanh toán</Typography.Title>
        {selected.payments.length ? <Table rowKey="id" size="small" pagination={false} dataSource={selected.payments} columns={[{ title: 'Phương thức', dataIndex: 'method', render: (value: string) => <Tag>{PAYMENT_METHOD_LABELS[value] ?? value}</Tag> }, { title: 'Trạng thái', dataIndex: 'status', render: (value: string) => <Tag color={value === PAYMENT_STATUS.SUCCESS ? 'success' : undefined}>{PAYMENT_STATUS_LABELS[value] ?? value}</Tag> }, { title: 'Số tiền', dataIndex: 'amount', render: (value: number) => money(value) }, { title: 'Ngày', dataIndex: 'paidAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') }]} /> : <Empty description="Chưa có lần thanh toán" />}
        {canWrite && selected.status !== INVOICE_STATUS.PAID && <Form form={paymentForm} layout="vertical" initialValues={{ method: PAYMENT_METHOD.CASH, status: PAYMENT_STATUS.SUCCESS }} onFinish={(values: PaymentFields) => void submitPayment(values)} style={{ marginTop: 20 }}>
          <Typography.Title level={5}>Ghi nhận thanh toán</Typography.Title>
          <Form.Item name="method" label="Phương thức" rules={[{ required: true }]}><Select options={PAYMENT_METHOD_OPTIONS} /></Form.Item>
          <Form.Item name="status" label="Trạng thái" rules={[{ required: true }]}><Select options={PAYMENT_STATUS_OPTIONS} /></Form.Item>
          <Button type="primary" htmlType="submit" loading={recordPayment.isPending}>Ghi nhận thanh toán</Button>
        </Form>}
      </>}
    </Drawer>
    <Modal title="Tạo hóa đơn từ lịch hẹn" open={createOpen} onCancel={() => setCreateOpen(false)} onOk={() => createForm.submit()} confirmLoading={createInvoice.isPending} destroyOnClose>
      <Form form={createForm} layout="vertical" onFinish={(values: CreateFields) => void submitCreate(values)}>
        <Form.Item name="appointmentId" label="Lịch hẹn" rules={[{ required: true, message: 'Vui lòng chọn lịch hẹn' }]}><Select showSearch optionFilterProp="label" options={[...appointmentOptions].sort((a, b) => Number(b.label.includes('HoanThanh')) - Number(a.label.includes('HoanThanh')))} onChange={(id: number) => { const appointment = appointments.data?.find((item) => item.id === id); if (appointment?.status !== 'HoanThanh') message.warning('Lịch hẹn chưa hoàn thành; vẫn có thể tiếp tục.') }} /></Form.Item>
        <Form.Item name="voucherCode" label="Mã voucher"><Input /></Form.Item>
        <Form.Item name="pointsToRedeem" label="Điểm muốn đổi" initialValue={0}><InputNumber min={0} precision={0} style={{ width: '100%' }} /></Form.Item>
        {(services.isError || combos.isError) && <Alert type="warning" message="Không tải được danh mục dịch vụ/combo." />}
      </Form>
    </Modal>
  </section>
}
