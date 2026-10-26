import { useMemo, useState } from 'react'
import { useSearchParams } from 'react-router-dom'
import { Alert, App, Button, Card, DatePicker, Descriptions, Drawer, Empty, Form, Input, InputNumber, Modal, Select, Space, Statistic, Table, Tag, Typography, Row, Col } from 'antd'
import { DeleteOutlined, PlusOutlined, PrinterOutlined, QrcodeOutlined } from '@ant-design/icons'
import { useQueryClient } from '@tanstack/react-query'
import type { ColumnsType } from 'antd/es/table'
import dayjs, { type Dayjs } from 'dayjs'
import type { Appointment } from '../../types/appointments'
import type { CreateInvoiceRequest, Invoice, InvoiceLineRequest, PaymentRequest } from '../../types/billing'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import { useAuth } from '../../hooks/useAuth'
import { useAllAppointments, useAppointmentCustomers } from '../appointments/appointmentQueries'
import { APPOINTMENT_STATUS, getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import { useCombos, useServices } from '../services/serviceQueries'
import { useCustomers } from '../customers-staff/customerStaffQueries'
import { INVOICE_STATUS, INVOICE_STATUS_LABELS, PAYMENT_METHOD, PAYMENT_METHOD_OPTIONS, PAYMENT_METHOD_LABELS, PAYMENT_STATUS, PAYMENT_STATUS_LABELS, PAYMENT_STATUS_OPTIONS } from './billingConstants'
import { useApplyInvoiceDiscount, useCreateInvoice, useInvoiceDetail, useInvoices, useRecordInvoicePayment } from './billingQueries'
import { buildInvoiceDraft, eligibleInvoiceAppointments } from './invoiceDraft'
import { canApplyInvoiceDiscount, currentInvoice } from './invoiceSync'
import BankTransferModal from './BankTransferModal'
import { cacheVerifiedPaidInvoice } from './transferSafety'
import { getSession } from '../../api/session'
import { useCreateIntent } from '../../hooks/useCreateIntent'

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`
type CreateFields = { appointmentId: number; voucherCode?: string; pointsToRedeem?: number }
type PaymentFields = { method: string; status: string }
type DiscountFields = { voucherCode?: string; pointsToRedeem?: number }
type EditableInvoiceLine = { key: string; name: string; serviceId: number | null; comboId: number | null; quantity: number; unitPrice: number }

export default function BillingPage() {
  const [searchParams] = useSearchParams()
  const { message } = App.useApp()
  const { has } = usePermissions()
  const session = useAuth()
  const client = useQueryClient()
  const cashierName = session?.account?.name ?? 'HealthBeauty Spa & Clinic'
  const canWrite = has('INVOICE.WRITE') && has('APPOINTMENT.READ')
  const canPay = has('PAYMENT.WRITE')
  const invoices = useInvoices()
  const customers = useCustomers('', has('CUSTOMER.READ'))
  const appointments = useAllAppointments(has('APPOINTMENT.READ'))
  const catalogCustomers = useAppointmentCustomers('', has('CUSTOMER.READ'))
  const services = useServices()
  const combos = useCombos()
  const createInvoice = useCreateInvoice()
  const recordPayment = useRecordInvoicePayment()
  const applyDiscount = useApplyInvoiceDiscount()
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState<string>()
  const [range, setRange] = useState<[Dayjs | null, Dayjs | null] | null>(null)
  const [selectedId, setSelectedId] = useState<number | null>(() => {
    const id = Number(searchParams.get('invoiceId'))
    return searchParams.get('collect') !== '1' && Number.isSafeInteger(id) && id > 0 ? id : null
  })
  const [receiptInvoiceId, setReceiptInvoiceId] = useState<number | null>(null)
  const [qrInvoiceId, setQrInvoiceId] = useState<number | null>(() => {
    const id = Number(searchParams.get('invoiceId'))
    return searchParams.get('collect') === '1' && Number.isSafeInteger(id) && id > 0 ? id : null
  })
  const [createOpen, setCreateOpen] = useCreateIntent(canWrite)
  const [invoiceLineEdits, setInvoiceLineEdits] = useState<{ appointmentId: number | undefined; lines: EditableInvoiceLine[] } | null>(null)
  const [newItemKey, setNewItemKey] = useState<string>()
  const [newItemQuantity, setNewItemQuantity] = useState(1)
  const [createForm] = Form.useForm<CreateFields>()
  const [paymentForm] = Form.useForm<PaymentFields>()
  const selectedAppointmentId = Form.useWatch('appointmentId', createForm)
  const selectedAppointment = appointments.data?.find((item) => item.id === selectedAppointmentId)
  const draftCustomer = customers.data?.find((item) => item.id === selectedAppointment?.customerId)
  const customerNames = useMemo(() => new Map((customers.data ?? []).map((customer) => [customer.id, customer.fullName])), [customers.data])
  const list = useMemo(() => invoices.data ?? [], [invoices.data])
  const activeInvoiceId = receiptInvoiceId ?? selectedId
  const activeIsInList = list.some((invoice) => invoice.id === activeInvoiceId)
  const invoiceDetail = useInvoiceDetail(activeInvoiceId, !activeIsInList)
  const selected = currentInvoice(selectedId, list, invoiceDetail.data)
  const receiptInvoice = currentInvoice(receiptInvoiceId, list, invoiceDetail.data)
  const eligibleAppointments = useMemo(() => {
    return eligibleInvoiceAppointments(appointments.data ?? [], list)
  }, [appointments.data, list])
  const draft = useMemo(() => {
    const appointment = eligibleAppointments.find((item) => item.id === selectedAppointmentId)
    if (!appointment) return { value: null, error: null }
    try { return { value: buildInvoiceDraft(appointment, services.data ?? [], combos.data ?? []), error: null } }
    catch (error) { return { value: null, error: error instanceof Error ? error.message : 'Không thể tính hóa đơn cho lịch hẹn này.' } }
  }, [eligibleAppointments, selectedAppointmentId, services.data, combos.data])
  const defaultInvoiceLines = draft.value?.lines ?? []
  const invoiceLines = invoiceLineEdits && invoiceLineEdits.appointmentId === selectedAppointmentId ? invoiceLineEdits.lines : defaultInvoiceLines
  function setInvoiceLines(update: (lines: EditableInvoiceLine[]) => EditableInvoiceLine[]) {
    setInvoiceLineEdits((current) => ({ appointmentId: selectedAppointmentId, lines: update(current && current.appointmentId === selectedAppointmentId ? current.lines : defaultInvoiceLines) }))
  }
  const paidRevenue = list.filter((invoice) => invoice.status === INVOICE_STATUS.PAID).reduce((sum, invoice) => sum + invoice.total, 0)
  const unpaidCount = list.filter((invoice) => invoice.status === INVOICE_STATUS.UNPAID).length
  const openInvoice = (invoice: Invoice) => setSelectedId(invoice.id)
  const printReceipt = (invoice: Invoice) => { openInvoice(invoice); setReceiptInvoiceId(invoice.id) }
  async function acceptPaidInvoice(invoice: Invoice, print = false) {
    if (!session || !await cacheVerifiedPaidInvoice(client, invoice, () => getSession() === session)) return
    if (print) printReceipt(invoice)
    else message.success(`Hóa đơn #${invoice.id} đã được thanh toán.`)
    void Promise.all(['invoices', 'customers', 'appointment-customers', 'appointments', 'reports'].map(key => client.invalidateQueries({ queryKey: [key] })))
  }
  const filtered = useMemo(() => list.filter((invoice) => {
    const matchesCustomer = !keyword || (customerNames.get(invoice.customerId) ?? '').toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase())
    const matchesStatus = !status || invoice.status === status
    const date = dayjs(invoice.createdAt)
    const matchesDate = !range || (!range[0] || !date.isBefore(range[0].startOf('day'))) && (!range[1] || !date.isAfter(range[1].endOf('day')))
    return matchesCustomer && matchesStatus && matchesDate
  }), [list, keyword, status, range, customerNames])

  async function submitCreate(values: CreateFields) {
    if (!canWrite || invoices.isError || appointments.isError || services.isError || combos.isError) return
    const appointment = eligibleAppointments.find((item) => item.id === values.appointmentId)
    if (!appointment || !draft.value) { message.error(draft.error ?? 'Chọn lịch hẹn đã hoàn thành và chưa có hóa đơn.'); return }
    if (!invoiceLines.length) { message.error('Hóa đơn phải có ít nhất một dòng dịch vụ hoặc combo.'); return }
    const items: InvoiceLineRequest[] = invoiceLines.map(({ serviceId, comboId, quantity }) => ({ serviceId, comboId, quantity }))
    if (items.some((item) => (item.serviceId === null) === (item.comboId === null))) {
      message.error('Mỗi dòng hóa đơn phải thuộc một dịch vụ hoặc một combo hợp lệ.')
      return
    }
    const body: CreateInvoiceRequest = { appointmentId: appointment.id, items, voucherCode: values.voucherCode?.trim() || null, pointsToRedeem: values.pointsToRedeem ?? 0 }
    try {
      await createInvoice.mutateAsync(body)
      message.success('Tạo hóa đơn thành công'); setCreateOpen(false); createForm.resetFields(); setInvoiceLineEdits(null)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể tạo hóa đơn')) }
  }

  function addInvoiceLine() {
    if (!newItemKey) { message.warning('Chọn dịch vụ hoặc combo cần thêm.'); return }
    const [kind, idText] = newItemKey.split(':')
    const id = Number(idText)
    const service = kind === 'service' ? services.data?.find((item) => item.id === id) : undefined
    const combo = kind === 'combo' ? combos.data?.find((item) => item.id === id) : undefined
    if (!service && !combo) { message.error('Không tìm thấy dịch vụ hoặc combo đã chọn.'); return }
    const serviceId = service?.id ?? null
    const comboId = combo?.id ?? null
    const key = `${kind}:${id}`
    const name = service?.name ?? combo?.name ?? `${kind === 'service' ? 'Dịch vụ' : 'Combo'} #${id}`
    const unitPrice = service?.price ?? combo?.price ?? 0
    setInvoiceLines((lines) => {
      const existing = lines.find((line) => line.key === key)
      if (existing) return lines.map((line) => line.key === key ? { ...line, quantity: Math.min(99, line.quantity + newItemQuantity) } : line)
      return [...lines, { key, name, serviceId, comboId, quantity: newItemQuantity, unitPrice }]
    })
    setNewItemKey(undefined)
    setNewItemQuantity(1)
  }

  async function submitPayment(values: PaymentFields) {
    if (!canPay || !selected || selected.status !== INVOICE_STATUS.UNPAID || invoices.isError || (!activeIsInList && invoiceDetail.isError) || applyDiscount.isPending || recordPayment.isPending) return
    try {
      const recorded = await recordPayment.mutateAsync({ id: selected.id, body: values as PaymentRequest, expectedTotal: selected.total })
      if (recorded) message.success('Ghi nhận thanh toán thành công')
      else message.info('Hóa đơn đã được cập nhật. Vui lòng kiểm tra trạng thái thanh toán mới nhất.')
      setSelectedId(null)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể ghi nhận thanh toán')) }
  }

  async function submitDiscount(values: DiscountFields) {
    if (!has('INVOICE.WRITE') || !selected || !canApplyInvoiceDiscount(selected) || invoices.isError || (!activeIsInList && invoiceDetail.isError) || applyDiscount.isPending || recordPayment.isPending) return
    const body = { voucherCode: values.voucherCode?.trim() || null, pointsToRedeem: values.pointsToRedeem ?? 0 }
    if (!body.voucherCode && body.pointsToRedeem === 0) { message.warning('Nhập mã voucher hoặc số điểm muốn đổi.'); return }
    try {
      await applyDiscount.mutateAsync({ id: selected.id, body })
      message.success('Đã áp dụng ưu đãi và cập nhật số tiền hóa đơn.')
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể áp dụng ưu đãi. Vui lòng kiểm tra lại hóa đơn.')) }
  }

  const appointmentOptions = eligibleAppointments.map((appointment: Appointment) => ({
    value: appointment.id,
    label: `Lịch #${appointment.id} · ${catalogCustomers.data?.find((customer) => customer.id === appointment.customerId)?.fullName ?? `Khách #${appointment.customerId}`} · ${getAppointmentStatusPresentation(appointment.status).label}${appointment.status !== APPOINTMENT_STATUS.COMPLETED ? ' (chưa hoàn thành)' : ''}`,
  }))
  const columns: ColumnsType<Invoice> = [
    { title: 'STT', key: 'stt', width: 60, align: 'center', render: (_value, _record, index) => index + 1 },
    { title: 'Mã hóa đơn', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Mã lịch hẹn', dataIndex: 'appointmentId', key: 'appointmentId', render: (id: number) => `#${id}` },
    { title: 'Khách hàng', dataIndex: 'customerId', key: 'customerId', render: (id: number) => customerNames.get(id) ?? `#${id}` },
    { title: 'Ngày tạo', dataIndex: 'createdAt', key: 'createdAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Tạm tính', dataIndex: 'subtotal', key: 'subtotal', align: 'right', render: (value: number) => money(value) },
    { title: 'Tổng tiền', dataIndex: 'total', key: 'total', align: 'right', render: (value: number) => money(value) },
    { title: 'Thanh toán', dataIndex: 'status', key: 'status', render: (value: string) => <Tag color={value === INVOICE_STATUS.PAID ? 'success' : value === INVOICE_STATUS.UNPAID ? 'warning' : undefined}>{INVOICE_STATUS_LABELS[value] ?? 'Trạng thái chưa xác định'}</Tag> },
    { title: 'Phương thức', key: 'method', render: (_, invoice) => {
      const successfulPayments = invoice.status === INVOICE_STATUS.PAID
        ? invoice.payments.filter((payment) => payment.status === PAYMENT_STATUS.SUCCESS)
        : []
      return successfulPayments.length
        ? <Space size={[4, 4]} wrap>{successfulPayments.map((payment) => <Tag key={payment.id}>{PAYMENT_METHOD_LABELS[payment.method] ?? 'Phương thức khác'}</Tag>)}</Space>
        : '—'
    } },
    { title: 'Thao tác', key: 'actions', render: (_, invoice) => (
      <Space size={4}>
        {invoice.status === INVOICE_STATUS.UNPAID && invoice.total > 0 && (
          <Button
            type="link"
            icon={<QrcodeOutlined />}
            onClick={(event) => {
              event.stopPropagation()
              setQrInvoiceId(invoice.id)
            }}
          >
            Quét QR
          </Button>
        )}
        <Button type="link" icon={<PrinterOutlined />} onClick={(event) => { event.stopPropagation(); printReceipt(invoice) }}>In phiếu</Button>
      </Space>
    ) },
  ]

  const receiptCustomer = receiptInvoice ? customers.data?.find((customer) => customer.id === receiptInvoice.customerId) : undefined
  const receiptPaid = receiptInvoice?.payments.filter((payment) => payment.status === PAYMENT_STATUS.SUCCESS).reduce((sum, payment) => sum + payment.amount, 0) ?? 0
  const receiptDiscount = receiptInvoice ? Math.max(0, receiptInvoice.subtotal - receiptInvoice.total) : 0
  const receiptMethod = receiptInvoice?.payments.find((payment) => payment.status === PAYMENT_STATUS.SUCCESS)?.method
  const receiptMethodLabel = receiptMethod ? PAYMENT_METHOD_LABELS[receiptMethod] || 'Phương thức khác' : receiptInvoice?.status === INVOICE_STATUS.PAID ? receiptInvoice.total === 0 ? 'Không phát sinh khoản thu' : 'Chưa có thông tin' : 'Chờ thanh toán'
  const printNow = () => window.print()

  return <section>
    <style>{`@media print { body * { visibility: hidden !important; } #healthbeauty-receipt, #healthbeauty-receipt * { visibility: visible !important; } #healthbeauty-receipt { position: absolute !important; inset: 0 auto auto 0 !important; width: 100% !important; max-width: none !important; margin: 0 !important; padding: 20mm !important; box-shadow: none !important; color: #222 !important; background: #fff !important; } .receipt-no-print { display: none !important; } @page { size: A4; margin: 0; } }`}</style>
    <div className="page-heading">
      <Typography.Title level={4} style={{ margin: 0 }}>Hóa đơn và thanh toán</Typography.Title>
      <Space className="filter-bar" wrap>
        <Input allowClear value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Tìm theo tên khách" style={{ width: 220, maxWidth: '100%' }} />
        <Select allowClear value={status} onChange={setStatus} placeholder="Trạng thái thanh toán" style={{ width: 210, maxWidth: '100%' }} options={[...new Set(list.map((invoice) => invoice.status))].map((value) => ({ value, label: INVOICE_STATUS_LABELS[value] ?? 'Trạng thái chưa xác định' }))} />
        <DatePicker.RangePicker value={range} onChange={setRange} format="DD/MM/YYYY" />
        {canWrite && <Button type="primary" onClick={() => setCreateOpen(true)}>Tạo hóa đơn</Button>}
      </Space>
    </div>
    <Row gutter={[16, 16]} style={{ marginBottom: 20 }}>
      <Col xs={24} sm={8}><Card size="small"><Statistic title="Tổng doanh thu đã thu" value={paidRevenue} formatter={(value) => money(Number(value))} /></Card></Col>
      <Col xs={24} sm={8}><Card size="small"><Statistic title="Chờ thanh toán" value={unpaidCount} /></Card></Col>
      <Col xs={24} sm={8}><Card size="small"><Statistic title="Tổng hóa đơn" value={list.length} /></Card></Col>
    </Row>
    {invoices.isError && <Alert type="error" showIcon message="Không tải được danh sách hóa đơn" description={getApiErrorMessage(invoices.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    {customers.isError && <Alert type="warning" message="Không tải được tên khách hàng." style={{ marginBottom: 16 }} />}
    <div className="table-scroll-container"><Table<Invoice> className="responsive-table" scroll={{ x: 'max-content' }} rowKey="id" columns={columns} dataSource={filtered} loading={invoices.isLoading || customers.isLoading} onRow={(invoice) => ({ onClick: () => openInvoice(invoice), style: { cursor: 'pointer' } })} locale={{ emptyText: <Empty description={invoices.isError ? 'Không có dữ liệu để hiển thị' : 'Chưa có hóa đơn'} /> }} pagination={{ responsive: true, pageSize: 10, showSizeChanger: true, pageSizeOptions: [10, 20, 50], showTotal: (count) => `Tổng ${count} hóa đơn` }} /></div>
    <Drawer className="responsive-drawer" title={`Chi tiết hóa đơn #${selectedId ?? ''}`} open={selectedId !== null} onClose={() => setSelectedId(null)} width={640}>
      {!selected && <Alert type={invoiceDetail.isError ? 'error' : 'info'} showIcon message={invoiceDetail.isError ? 'Không tải được hóa đơn. Vui lòng thử lại.' : 'Đang tải hóa đơn…'} />}
      {selected && <>
        <Space className="receipt-no-print" style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: 12 }}>
          {selected.status === INVOICE_STATUS.UNPAID && selected.total > 0 && (
            <Button
              type="primary"
              icon={<QrcodeOutlined />}
              onClick={() => setQrInvoiceId(selected.id)}
              style={{ background: '#8c4559', borderColor: '#8c4559' }}
            >
              Mã QR SePay
            </Button>
          )}
          <Button icon={<PrinterOutlined />} onClick={() => printReceipt(selected)}>In hóa đơn</Button>
        </Space>
        <Descriptions column={1} bordered size="small">
          <Descriptions.Item label="Lịch hẹn">#{selected.appointmentId}</Descriptions.Item>
          <Descriptions.Item label="Khách hàng">{customerNames.get(selected.customerId) ?? `#${selected.customerId}`}</Descriptions.Item>
          <Descriptions.Item label="Ngày tạo">{dayjs(selected.createdAt).format('DD/MM/YYYY HH:mm')}</Descriptions.Item>
          <Descriptions.Item label="Thanh toán"><Tag color={selected.status === INVOICE_STATUS.PAID ? 'success' : 'warning'}>{INVOICE_STATUS_LABELS[selected.status] ?? 'Trạng thái chưa xác định'}</Tag></Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5}>Các dòng hóa đơn</Typography.Title>
        <Table className="responsive-table" scroll={{ x: 'max-content' }} rowKey="id" size="small" pagination={false} dataSource={selected.items} columns={[{ title: 'Dịch vụ / combo', render: (_, item) => item.serviceName ?? item.comboName ?? (item.serviceId !== null ? services.data?.find((s) => s.id === item.serviceId)?.name : null) ?? (item.comboId !== null ? combos.data?.find((c) => c.id === item.comboId)?.name : null) ?? 'Không rõ tên' }, { title: 'SL', dataIndex: 'quantity' }, { title: 'Đơn giá', dataIndex: 'unitPrice', render: (value: number) => money(value) }]} />
        <Descriptions column={1} bordered size="small" style={{ marginTop: 16 }}>
          <Descriptions.Item label="Tạm tính">{money(selected.subtotal)}</Descriptions.Item>
          <Descriptions.Item label="Chênh lệch tạm tính và tổng">{money(selected.subtotal - selected.total)}</Descriptions.Item>
          <Descriptions.Item label="Tổng">{money(selected.total)}</Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5}>Các lần thanh toán</Typography.Title>
        {selected.payments.length ? <Table className="responsive-table" scroll={{ x: 'max-content' }} rowKey="id" size="small" pagination={false} dataSource={selected.payments} columns={[{ title: 'Phương thức', dataIndex: 'method', render: (value: string) => <Tag>{PAYMENT_METHOD_LABELS[value] ?? 'Phương thức khác'}</Tag> }, { title: 'Trạng thái', dataIndex: 'status', render: (value: string) => <Tag color={value === PAYMENT_STATUS.SUCCESS ? 'success' : undefined}>{PAYMENT_STATUS_LABELS[value] ?? 'Trạng thái chưa xác định'}</Tag> }, { title: 'Số tiền', dataIndex: 'amount', render: (value: number) => money(value) }, { title: 'Ngày', dataIndex: 'paidAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') }]} /> : <Empty description="Chưa có lần thanh toán" />}
        {has('INVOICE.WRITE') && canApplyInvoiceDiscount(selected) && <Form key={selected.id} className="responsive-form" layout="vertical" initialValues={{ pointsToRedeem: 0 }} onFinish={(values: DiscountFields) => void submitDiscount(values)} style={{ marginTop: 20 }}>
          <Typography.Title level={5}>Ưu đãi hóa đơn</Typography.Title>
          <Alert type="info" showIcon message="Áp dụng trước khi khách chuyển khoản. Voucher và điểm thưởng chỉ được áp dụng một lần cho hóa đơn chưa giảm giá." style={{ marginBottom: 16 }} />
          <Form.Item name="voucherCode" label="Mã voucher"><Input /></Form.Item>
          <Form.Item name="pointsToRedeem" label="Điểm muốn đổi"><InputNumber min={0} max={Math.min(1000000, customers.data?.find((customer) => customer.id === selected.customerId)?.rewardPoints ?? 1000000)} precision={0} style={{ width: '100%' }} /></Form.Item>
          <Button type="primary" htmlType="submit" disabled={invoices.isError || (!activeIsInList && invoiceDetail.isError) || recordPayment.isPending} loading={applyDiscount.isPending}>Áp dụng ưu đãi</Button>
        </Form>}
        {canPay && selected.status === INVOICE_STATUS.UNPAID && <Form className="responsive-form" form={paymentForm} layout="vertical" initialValues={{ method: PAYMENT_METHOD.CASH, status: PAYMENT_STATUS.SUCCESS }} onFinish={(values: PaymentFields) => void submitPayment(values)} style={{ marginTop: 20 }}>
          <Typography.Title level={5}>Ghi nhận tiền mặt / thẻ</Typography.Title>
          <Form.Item name="method" label="Phương thức" rules={[{ required: true }]}><Select options={PAYMENT_METHOD_OPTIONS.filter(option => option.value !== PAYMENT_METHOD.BANK_TRANSFER)} /></Form.Item>
          <Form.Item name="status" label="Trạng thái" rules={[{ required: true }]}><Select options={PAYMENT_STATUS_OPTIONS} /></Form.Item>
          <Button type="primary" htmlType="submit" disabled={invoices.isError || (!activeIsInList && invoiceDetail.isError) || applyDiscount.isPending} loading={recordPayment.isPending}>Ghi nhận thanh toán</Button>
        </Form>}
      </>}
    </Drawer>
    <Modal className="responsive-modal receipt-preview-modal" title="Xem trước phiếu thanh toán" open={receiptInvoiceId !== null} onCancel={() => setReceiptInvoiceId(null)} width={760} footer={<Space className="receipt-no-print"><Button onClick={() => setReceiptInvoiceId(null)}>Đóng</Button><Button type="primary" icon={<PrinterOutlined />} disabled={!receiptInvoice || invoices.isError || (!activeIsInList && invoiceDetail.isError)} onClick={printNow}>In ngay (Print / PDF)</Button></Space>}>
      {receiptInvoice && <article id="healthbeauty-receipt" style={{ maxWidth: 680, margin: '0 auto', padding: 28, color: '#333', background: '#fff', border: '1px solid #eadfd5', borderRadius: 8, fontFamily: 'Arial, sans-serif' }}>
        <header style={{ textAlign: 'center', borderBottom: '2px solid #b88b62', paddingBottom: 18, marginBottom: 20 }}>
          <div style={{ color: '#8b6448', fontSize: 22, fontWeight: 700, letterSpacing: 1 }}>HEALTHBEAUTY SPA &amp; CLINIC</div>
          <div style={{ marginTop: 6 }}>140 Lê Trọng Tấn, Tây Thạnh, Tân Phú, TP. Hồ Chí Minh</div>
          <div>Hotline: 1900 6868 | Email: cskh@healthbeauty.vn</div>
          <h1 style={{ fontSize: 21, margin: '24px 0 8px', letterSpacing: 1 }}>PHIẾU THANH TOÁN DỊCH VỤ</h1>
          <div>Số hóa đơn: <strong>#HD-{receiptInvoice.id}</strong> | Ngày lập: {dayjs(receiptInvoice.createdAt).format('DD/MM/YYYY HH:mm')}</div>
        </header>
        <section style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '8px 24px', marginBottom: 18 }}>
          <div><strong>Khách hàng:</strong> {receiptCustomer?.fullName ?? customerNames.get(receiptInvoice.customerId) ?? `#${receiptInvoice.customerId}`}</div><div><strong>Số điện thoại:</strong> {receiptCustomer?.phone || '—'}</div>
          <div><strong>Mã lịch hẹn:</strong> #{receiptInvoice.appointmentId}</div><div><strong>Thu ngân / Người lập:</strong> {cashierName}</div>
        </section>
        <table style={{ width: '100%', borderCollapse: 'collapse', marginBottom: 18 }}>
          <thead><tr>{['STT', 'Tên dịch vụ / combo', 'Số lượng', 'Đơn giá', 'Thành tiền'].map((header) => <th key={header} style={{ borderBottom: '1px solid #b88b62', padding: 9, textAlign: header === 'Tên dịch vụ / combo' ? 'left' : 'right' }}>{header}</th>)}</tr></thead>
          <tbody>{receiptInvoice.items.map((item, index) => {
            const name = item.serviceName ?? item.comboName ?? (item.serviceId !== null ? services.data?.find((service) => service.id === item.serviceId)?.name : null) ?? (item.comboId !== null ? combos.data?.find((combo) => combo.id === item.comboId)?.name : null) ?? 'Dịch vụ / combo'
            return <tr key={item.id}><td style={{ borderBottom: '1px solid #eee', padding: 9, textAlign: 'right' }}>{index + 1}</td><td style={{ borderBottom: '1px solid #eee', padding: 9 }}>{name}</td><td style={{ borderBottom: '1px solid #eee', padding: 9, textAlign: 'right' }}>{item.quantity}</td><td style={{ borderBottom: '1px solid #eee', padding: 9, textAlign: 'right' }}>{money(item.unitPrice)}</td><td style={{ borderBottom: '1px solid #eee', padding: 9, textAlign: 'right' }}>{money(item.quantity * item.unitPrice)}</td></tr>
          })}</tbody>
        </table>
        <section style={{ marginLeft: 'auto', maxWidth: 340, lineHeight: 2 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Tạm tính:</span><span>{money(receiptInvoice.subtotal)}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Giảm giá voucher / Đổi điểm thưởng:</span><span>-{money(receiptDiscount)}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between', borderTop: '2px solid #b88b62', paddingTop: 5, fontSize: 18, fontWeight: 700 }}><span>TỔNG TIỀN PHẢI TRẢ:</span><span>{money(receiptInvoice.total)}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Đã thanh toán:</span><span>{money(receiptPaid)}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between' }}><span>Phương thức thanh toán:</span><span>{receiptMethodLabel}</span></div>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}><span>Trạng thái:</span><Tag color={receiptInvoice.status === INVOICE_STATUS.PAID ? 'success' : 'warning'}>{(INVOICE_STATUS_LABELS[receiptInvoice.status] ?? 'Trạng thái chưa xác định').toLocaleUpperCase('vi-VN')}</Tag></div>
        </section>
        <footer style={{ marginTop: 34, textAlign: 'center' }}>
          <em>Cảm ơn quý khách đã tin tưởng và đồng hành cùng HealthBeauty!</em>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 24, marginTop: 28 }}><div><strong>Khách hàng</strong><div style={{ color: '#777', marginTop: 5 }}>(Ký, ghi rõ họ tên)</div><div style={{ height: 70 }} /></div><div><strong>Thu ngân/Lễ tân</strong><div style={{ color: '#777', marginTop: 5 }}>(Ký, ghi rõ họ tên)</div><div style={{ height: 70 }} /><strong>{cashierName}</strong></div></div>
        </footer>
      </article>}
    </Modal>
    <Modal className="responsive-modal" title="Tạo hóa đơn từ lịch hẹn" open={createOpen} onCancel={() => setCreateOpen(false)} onOk={() => createForm.submit()} okText="Tạo hóa đơn" cancelText="Hủy" confirmLoading={createInvoice.isPending} okButtonProps={{ disabled: !draft.value || invoiceLines.length === 0 || invoices.isError || appointments.isError || services.isError || combos.isError || services.isLoading || combos.isLoading || appointments.isLoading || invoices.isLoading }} destroyOnClose>
      <Form className="responsive-form" form={createForm} layout="vertical" onFinish={(values: CreateFields) => void submitCreate(values)}>
        <Form.Item name="appointmentId" label="Lịch hẹn đã hoàn thành" rules={[{ required: true, message: 'Vui lòng chọn lịch hẹn' }]}><Select showSearch optionFilterProp="label" options={appointmentOptions} loading={appointments.isLoading || invoices.isLoading} placeholder="Chọn lịch hẹn chưa có hóa đơn" /></Form.Item>
        {!eligibleAppointments.length && !appointments.isLoading && <Alert type="info" showIcon message="Chưa có lịch hẹn đã hoàn thành để tạo hóa đơn." style={{ marginBottom: 16 }} />}
        {draft.error && <Alert type="error" showIcon message={draft.error} style={{ marginBottom: 16 }} />}
        {draft.value && <>
          <Table<EditableInvoiceLine> className="responsive-table" size="small" rowKey="key" pagination={false} dataSource={invoiceLines} columns={[
            { title: 'Dịch vụ / combo', dataIndex: 'name' },
            { title: 'SL', key: 'quantity', render: (_, line) => <InputNumber min={1} max={99} precision={0} value={line.quantity} onChange={(value) => { if (value !== null) setInvoiceLines((lines) => lines.map((item) => item.key === line.key ? { ...item, quantity: value } : item)) }} style={{ width: 70 }} /> },
            { title: 'Đơn giá', dataIndex: 'unitPrice', render: (value: number) => money(value) },
            { title: 'Thành tiền', key: 'amount', align: 'right', render: (_, line) => money(line.quantity * line.unitPrice) },
            { title: 'Thao tác', key: 'actions', render: (_, line) => <Button type="text" danger icon={<DeleteOutlined />} aria-label={`Xóa ${line.name}`} disabled={invoiceLines.length <= 1} onClick={() => setInvoiceLines((lines) => lines.filter((item) => item.key !== line.key))} /> },
          ]} />
          <Space wrap style={{ display: 'flex', marginTop: 12 }}>
            <Select placeholder="Chọn dịch vụ hoặc combo" value={newItemKey} onChange={setNewItemKey} style={{ minWidth: 240, flex: 1 }} options={[
              ...(services.data ?? []).map((service) => ({ value: `service:${service.id}`, label: `Dịch vụ · ${service.name ?? `#${service.id}`} · ${money(service.price)}` })),
              ...(combos.data ?? []).map((combo) => ({ value: `combo:${combo.id}`, label: `Combo · ${combo.name ?? `#${combo.id}`} · ${money(combo.price)}` })),
            ]} />
            <InputNumber min={1} max={99} precision={0} value={newItemQuantity} onChange={(value) => setNewItemQuantity(value ?? 1)} aria-label="Số lượng dịch vụ thêm" style={{ width: 90 }} />
            <Button icon={<PlusOutlined />} onClick={addInvoiceLine}>Thêm</Button>
          </Space>
          <Typography.Paragraph style={{ marginTop: 12 }}>Tạm tính: <strong>{money(invoiceLines.reduce((sum, line) => sum + line.quantity * line.unitPrice, 0))}</strong></Typography.Paragraph>
        </>}
        <Form.Item name="voucherCode" label="Mã voucher"><Input /></Form.Item>
        <Form.Item name="pointsToRedeem" label="Điểm muốn đổi" initialValue={0}><InputNumber min={0} max={Math.min(1000000, draftCustomer?.rewardPoints ?? 1000000)} precision={0} style={{ width: '100%' }} /></Form.Item>
        {(services.isError || combos.isError) && <Alert type="warning" message="Không tải được danh mục dịch vụ/combo." />}
      </Form>
    </Modal>
    <BankTransferModal
      open={qrInvoiceId !== null}
      invoiceId={qrInvoiceId}
      onClose={() => setQrInvoiceId(null)}
      canPayCash={canPay}
      onCash={(invoice) => { setSelectedId(invoice.id); setQrInvoiceId(null); paymentForm.setFieldsValue({ method: PAYMENT_METHOD.CASH, status: PAYMENT_STATUS.SUCCESS }) }}
      onPaymentSuccess={(invoice) => {
        void acceptPaidInvoice(invoice)
      }}
      onPrintReceipt={(invoice) => {
        void acceptPaidInvoice(invoice, true)
      }}
    />
  </section>
}
