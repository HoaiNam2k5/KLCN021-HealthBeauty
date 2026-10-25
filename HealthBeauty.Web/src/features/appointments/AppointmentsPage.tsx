import axios from 'axios'
import { useEffect, useMemo, useState } from 'react'
import { App as AntApp, Alert, Button, Card, Col, DatePicker, Descriptions, Drawer, Form, Input, Modal, Row, Select, Space, Tag, TimePicker, Typography } from 'antd'
import { DownloadOutlined } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import * as appointmentsApi from '../../api/appointments'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Appointment, AppointmentUpdateRequest, CreateAppointmentRequest, Staff } from '../../types/appointments'
import { useServices, useCombos } from '../services/serviceQueries'
import { useCustomerPackages } from '../service-packages/packageQueries'
import { APPOINTMENT_STATUSES, getAllowedNextAppointmentStatuses, getAppointmentStatusPresentation } from './appointmentStatus'
import { bookingItems, bookingDuration, canReschedule, canCancel, localAppointmentDateTime } from './appointmentContract'
import { appointmentKeys, useAppointmentDetail, useAppointmentCustomers, useAppointments, useAppointmentStaff, useAvailableSlots } from './appointmentQueries'

const statusLabels: Record<string, string> = { ChoXacNhan: 'Chờ xác nhận', DaXacNhan: 'Đã xác nhận', DaDen: 'Khách đã đến', DangThucHien: 'Đang thực hiện', HoanThanh: 'Hoàn thành', DaHuy: 'Đã hủy' }
const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

function AppointmentEditor({ appointment, staff, mode, onCancel, onSubmit, busy }: { appointment: Appointment; staff: Staff[]; mode: 'edit' | 'reschedule'; onCancel: () => void; onSubmit: (body: AppointmentUpdateRequest) => void; busy: boolean }) {
  const [form] = Form.useForm<{ appointmentDate: Dayjs; appointmentTime: Dayjs; staffId: number | null; note: string }>()
  const [date, setDate] = useState(dayjs(appointment.appointmentAt))
  const [selectedStaff, setSelectedStaff] = useState<number | undefined>(appointment.staffId ?? undefined)
  const durationMinutes = appointment.items.reduce((total, item) => total + (item.durationMinutes || 30), 0) || 30
  const slots = useAvailableSlots(date.format('YYYY-MM-DD'), selectedStaff, durationMinutes)
  const slotOptions = (slots.data ?? []).map((slot) => ({ value: slot.gioBatDau, label: `${slot.gioBatDau.slice(0, 5)} – ${slot.gioKetThuc.slice(0, 5)}` }))
  return <Form className="responsive-form" form={form} layout="vertical" initialValues={{ appointmentDate: dayjs(appointment.appointmentAt), appointmentTime: dayjs(appointment.appointmentAt), staffId: appointment.staffId, note: appointment.note ?? '' }} onFinish={(values) => onSubmit({ appointmentAt: localAppointmentDateTime(values.appointmentDate, values.appointmentTime), staffId: values.staffId ?? null, note: values.note.trim() || null })}>
    <Form.Item label="Ngày hẹn" name="appointmentDate" rules={[{ required: true, message: 'Vui lòng chọn ngày hẹn' }]}><DatePicker format="DD/MM/YYYY" style={{ width: '100%' }} onChange={(value) => { if (value) { setDate(value); form.setFieldValue('appointmentTime', null) } }} /></Form.Item>
    <Form.Item label="Nhân viên" name="staffId"><Select allowClear placeholder="Chưa phân công" options={staff.map((item) => ({ value: item.nhanVienId, label: item.hoTen }))} onChange={setSelectedStaff} /></Form.Item>
    {mode === 'reschedule' && <>
      {slots.isLoading && <Alert type="info" message="Đang tải khung giờ trống…" style={{ marginBottom: 12 }} />}
      {slots.isError && <Alert type="warning" message={getApiErrorMessage(slots.error, 'Không tải được khung giờ trống')} style={{ marginBottom: 12 }} />}
      {!slots.isLoading && !slots.isError && slotOptions.length === 0 && <Alert type="info" message="Chưa có khung giờ trống" style={{ marginBottom: 12 }} />}
      {slotOptions.length > 0 && <Form.Item label="Khung giờ trống"><Select options={slotOptions} placeholder="Chọn khung giờ" onChange={(value: string) => form.setFieldValue('appointmentTime', dayjs(`2000-01-01T${value}`))} /></Form.Item>}
    </>}
    <Form.Item label="Giờ hẹn" name="appointmentTime" rules={[{ required: true, message: 'Vui lòng chọn giờ hẹn' }]}><TimePicker format="HH:mm" minuteStep={5} style={{ width: '100%' }} /></Form.Item>
    <Form.Item label="Ghi chú" name="note"><Input.TextArea rows={3} maxLength={1000} /></Form.Item>
    <Space><Button type="primary" htmlType="submit" loading={busy}>Lưu</Button><Button onClick={onCancel}>Hủy</Button></Space>
  </Form>
}


type CreateFields = { customerId: number; staffId?: number; appointmentDate: Dayjs; appointmentTime: Dayjs; itemKeys: string[]; note?: string; customerPackageId?: number }

function AppointmentCreateDrawer({ open, staff, form, onClose, onSubmit, busy }: { open: boolean; staff: Staff[]; form: ReturnType<typeof Form.useForm<CreateFields>>[0]; onClose: () => void; onSubmit: (body: CreateAppointmentRequest) => void; busy: boolean }) {
  const date: Dayjs | null = Form.useWatch('appointmentDate', form) ?? null
  const staffId: number | undefined = Form.useWatch('staffId', form)
  const customerId: number | undefined = Form.useWatch('customerId', form)
  const customerPackageId: number | undefined = Form.useWatch('customerPackageId', form)
  const customerPackages = useCustomerPackages(customerId)
  const chosenPackage = customerPackages.data?.find(p => p.id === customerPackageId)
  const [customerKeyword, setCustomerKeyword] = useState('')
  const [debouncedKeyword, setDebouncedKeyword] = useState('')
  const customers = useAppointmentCustomers(debouncedKeyword)
  const services = useServices()
  const combos = useCombos()
  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedKeyword(customerKeyword.trim()), 350)
    return () => window.clearTimeout(timeout)
  }, [customerKeyword])
  useEffect(() => {
    if (!open) {
      form.resetFields()
    }
  }, [open, form])
  const serviceMap = new Map((services.data ?? []).map((service) => [service.id, service]))
  const selectedKeys = Form.useWatch('itemKeys', form) ?? []
  let durationMinutes = 0
  let selectionError = ''
  try { durationMinutes = bookingDuration(selectedKeys, services.data ?? [], combos.data ?? []) }
  catch (error) { selectionError = error instanceof Error ? error.message : 'Không thể tính thời lượng dịch vụ.' }
  const slots = useAvailableSlots(date?.format('YYYY-MM-DD') ?? '', staffId, durationMinutes)

  const itemOptions = [
    ...(services.data ?? []).map((service) => ({ value: `service:${service.id}`, label: `Dịch vụ: ${service.name ?? 'Không tên'} — ${money(service.price)}` })),
    ...(combos.data ?? []).map((combo) => ({ value: `combo:${combo.id}`, label: `Combo: ${combo.name ?? 'Không tên'} — ${money(combo.price)}` })),
  ]
  const estimate = chosenPackage ? 0 : selectedKeys.reduce((total, key) => {
    const [kind, rawId] = key.split(':')
    const id = Number(rawId)
    return total + (kind === 'service' ? serviceMap.get(id)?.price ?? 0 : combos.data?.find((combo) => combo.id === id)?.price ?? 0)
  }, 0)
  const slotOptions = (slots.data ?? []).map((slot) => ({ value: slot.gioBatDau, label: `${slot.gioBatDau.slice(0, 5)} – ${slot.gioKetThuc.slice(0, 5)}` }))
  const finish = (values: CreateFields) => {
    try {
      const items = bookingItems(values.itemKeys, services.data ?? [], combos.data ?? [])
      if (chosenPackage) {
        const counts = new Map<number, number>()
        for (const item of items) { if (item.comboId !== null || !chosenPackage.items.some(p => p.serviceId === item.serviceId && p.available > (counts.get(item.serviceId) ?? 0))) throw new Error('Dịch vụ đã chọn không đủ lượt trong gói.') ; counts.set(item.serviceId, (counts.get(item.serviceId) ?? 0) + 1) }
        items.forEach(item => { item.expectedPrice = 0 })
      }
      onSubmit({ appointmentAt: localAppointmentDateTime(values.appointmentDate, values.appointmentTime), items, note: values.note?.trim() || null, customerId: values.customerId, staffId: values.staffId ?? null, customerPackageId: chosenPackage?.id })
    } catch (error) {
      form.setFields([{ name: 'itemKeys', errors: [error instanceof Error ? error.message : 'Dịch vụ / combo không hợp lệ.'] }])
    }
  }
  return <Drawer className="responsive-drawer" title="Tạo lịch hẹn" open={open} onClose={onClose} width={560} destroyOnClose>
    <Form className="responsive-form" form={form} layout="vertical" onFinish={finish}>
      <Form.Item label="Khách hàng" name="customerId" rules={[{ required: true, message: 'Vui lòng chọn khách hàng' }]}><Select showSearch filterOption={false} onSearch={setCustomerKeyword} loading={customers.isFetching} placeholder="Tìm theo tên hoặc số điện thoại" notFoundContent={customers.isError ? 'Không tải được khách hàng' : 'Không tìm thấy khách hàng'} options={(customers.data ?? []).map((customer) => ({ value: customer.id, label: `${customer.fullName} — ${customer.phone ?? 'Chưa có SĐT'}` }))} /></Form.Item>
      <Form.Item label="Nhân viên" name="staffId"><Select allowClear placeholder="Chọn nhân viên" options={staff.map((item) => ({ value: item.nhanVienId, label: `${item.hoTen}${item.soDienThoai ? ` — ${item.soDienThoai}` : ''}` }))} /></Form.Item>
      <Form.Item label="Ngày hẹn" name="appointmentDate" rules={[{ required: true, message: 'Vui lòng chọn ngày hẹn' }]}><DatePicker format="DD/MM/YYYY" disabledDate={(value) => value.isBefore(dayjs(), 'day')} style={{ width: '100%' }} onChange={() => { form.setFieldValue('appointmentTime', null) }} /></Form.Item>
      {date && staffId !== undefined && durationMinutes > 0 && <>
        {slots.isLoading && <Alert type="info" message="Đang tải khung giờ trống…" style={{ marginBottom: 12 }} />}
        {slots.isError && <Alert type="warning" message={getApiErrorMessage(slots.error, 'Không tải được khung giờ trống')} style={{ marginBottom: 12 }} />}
        {!slots.isLoading && !slots.isError && slotOptions.length === 0 && <Alert type="info" message="Không có khung giờ gợi ý" style={{ marginBottom: 12 }} />}
        {slotOptions.length > 0 && <Form.Item label="Khung giờ gợi ý"><Select options={slotOptions} placeholder="Chọn khung giờ trống" onChange={(value: string) => form.setFieldValue('appointmentTime', dayjs(`2000-01-01T${value}`))} /></Form.Item>}
      </>}
      <Form.Item label="Giờ hẹn" name="appointmentTime" rules={[{ required: true, message: 'Vui lòng chọn giờ hẹn' }, { validator: (_, value: Dayjs | undefined) => !value || !date || dayjs(localAppointmentDateTime(date, value)).isAfter(dayjs()) ? Promise.resolve() : Promise.reject(new Error('Vui lòng chọn thời điểm trong tương lai')) }]}><TimePicker format="HH:mm" minuteStep={5} style={{ width: '100%' }} /></Form.Item>
      <Form.Item label="Gói dịch vụ đã thanh toán" name="customerPackageId"><Select allowClear placeholder="Không dùng gói" options={(customerPackages.data??[]).filter(p=>p.status==='Paid'&&(!p.expiresAt||dayjs(p.expiresAt).isAfter(dayjs()))&&p.items.some(i=>i.available>0)).map(p=>({value:p.id,label:`${p.name} — còn lượt khả dụng`}))} onChange={()=>form.setFieldValue('itemKeys',[])} /></Form.Item>
      <Form.Item label="Dịch vụ / combo" name="itemKeys" rules={[{ required: true, type: 'array', min: 1, message: 'Chọn ít nhất một dịch vụ hoặc combo' }]}><Select mode="multiple" placeholder="Chọn dịch vụ hoặc combo" options={itemOptions} loading={services.isLoading || combos.isLoading} /></Form.Item>
      {selectionError && <Alert type="error" message={selectionError} style={{ marginBottom: 16 }} />}
      {(services.isError || combos.isError) && <Alert type="error" message="Không tải được danh sách dịch vụ/combo" style={{ marginBottom: 16 }} />}
      <Alert type="info" message={`Tổng tiền dự kiến: ${money(estimate)}`} style={{ marginBottom: 16 }} />
      <Form.Item label="Ghi chú" name="note"><Input.TextArea rows={3} maxLength={1000} /></Form.Item>
      <Space><Button type="primary" htmlType="submit" loading={busy}>Tạo lịch hẹn</Button><Button onClick={onClose}>Hủy</Button></Space>
    </Form>
  </Drawer>
}

function useAppointmentMutations() {
  const client = useQueryClient()

  const invalidate = () => Promise.all([
    client.invalidateQueries({ queryKey: appointmentKeys.appointments }),
    client.invalidateQueries({ queryKey: appointmentKeys.availableSlots }),
    client.invalidateQueries({ queryKey: ['invoices'] }),
    client.invalidateQueries({ queryKey: ['customers'] }),
    client.invalidateQueries({ queryKey: ['appointment-customers'] }),
    client.invalidateQueries({ queryKey: ['reports'] }),
  ])
  return {
    update: useMutation({ mutationFn: ({ id, body }: { id: number; body: AppointmentUpdateRequest }) => appointmentsApi.updateAppointment(id, body), onSuccess: invalidate }),
    reschedule: useMutation({ mutationFn: ({ id, body }: { id: number; body: AppointmentUpdateRequest }) => appointmentsApi.rescheduleAppointment(id, body), onSuccess: invalidate }),
    status: useMutation({ mutationFn: ({ id, status }: { id: number; status: string }) => appointmentsApi.updateAppointmentStatus(id, { status }), onSuccess: invalidate }),
    remove: useMutation({ mutationFn: appointmentsApi.deleteAppointment, onSuccess: invalidate }),
    create: useMutation({ mutationFn: appointmentsApi.createAppointment, onSuccess: invalidate }),
  }
}

export default function AppointmentsPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(20)
  const [date, setDate] = useState<Dayjs | null>(null)
  const [status, setStatus] = useState<string>()
  const [staffId, setStaffId] = useState<number>()
  const [keyword, setKeyword] = useState('')
  const [debouncedKeyword, setDebouncedKeyword] = useState('')
  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedKeyword(keyword.trim()), 400)
    return () => window.clearTimeout(timeout)
  }, [keyword])
  const [selected, setSelected] = useState<Appointment | null>(null)
  const [createOpen, setCreateOpen] = useState(false)
  const [createForm] = Form.useForm<CreateFields>()
  const [editor, setEditor] = useState<'edit' | 'reschedule' | null>(null)
  const { message, modal } = AntApp.useApp()
  const { has, role } = usePermissions()
  const canReadStaff = role !== 'Staff' && has('STAFF.READ')
  const canWrite = has('APPOINTMENT.WRITE')
  const canCreate = canWrite && has('CUSTOMER.READ')
  const mutations = useAppointmentMutations()
  const filters = useMemo(() => ({
    ...(date ? { from: date.startOf('day').format('YYYY-MM-DDTHH:mm:ss'), to: date.add(1, 'day').startOf('day').format('YYYY-MM-DDTHH:mm:ss') } : {}),
    ...(status ? { status } : {}),
    ...(staffId !== undefined ? { staffId } : {}),
    ...(debouncedKeyword ? { keyword: debouncedKeyword } : {}),
    page,
    pageSize,
  }), [date, status, staffId, debouncedKeyword, page, pageSize])
  const appointments = useAppointments(filters)
  const staff = useAppointmentStaff(canReadStaff)
  const customers = useAppointmentCustomers('', has('CUSTOMER.READ'))
  const detail = useAppointmentDetail(selected?.id)
  const handleError = (error: unknown) => {
    const fallback = axios.isAxiosError(error) && error.response?.status === 409
      ? (typeof error.response.data === 'object' && error.response.data !== null && 'message' in error.response.data && error.response.data.message === 'Invalid appointment status transition'
        ? 'Không thể chuyển lịch hẹn sang trạng thái này. Vui lòng làm mới và thử lại.'
        : 'Lịch hẹn bị trùng với lịch khác. Vui lòng chọn khung giờ khác.')
      : 'Không thể thực hiện thao tác. Vui lòng thử lại.'
    message.error(getApiErrorMessage(error, fallback))
  }
  const activeAppointment = selected ? appointments.data?.items.find((item) => item.id === selected.id) ?? selected : null
  const applyCreateErrors = (errors: { name: string; errors: string[] }[]) => {
    const names: Record<string, keyof CreateFields> = { appointmentAt: 'appointmentDate', items: 'itemKeys', customerId: 'customerId', staffId: 'staffId', note: 'note' }
    const mapped = errors.map((entry) => ({ name: names[entry.name] ?? 'appointmentDate', errors: entry.errors }))
    createForm.setFields(mapped)
  }
  const createAppointment = (body: CreateAppointmentRequest) => mutations.create.mutate(body, {
    onSuccess: () => { message.success('Tạo lịch hẹn thành công'); setCreateOpen(false) },
    onError: (error: unknown) => {
      if (axios.isAxiosError(error) && error.response?.status === 409) {
        message.error('Khách hàng hoặc nhân viên đã có lịch vào giờ này')
        return
      }
      if (axios.isAxiosError(error) && error.response?.status === 400 && typeof error.response.data === 'object' && error.response.data !== null && 'errors' in error.response.data) {
        const errors = error.response.data.errors
        if (typeof errors === 'object' && errors !== null) {
          const fieldErrors = Object.entries(errors).map(([name, values]) => ({ name: name.charAt(0).toLowerCase() + name.slice(1), errors: Array.isArray(values) ? values.map(String) : [] }))
          applyCreateErrors(fieldErrors)
          message.error('Dữ liệu chưa hợp lệ. Vui lòng kiểm tra các trường được đánh dấu.')
          return
        }
      }
      message.error(getApiErrorMessage(error, 'Không thể tạo lịch hẹn. Vui lòng thử lại.'))
    },
  })
  const submitEditor = (body: AppointmentUpdateRequest) => {
    if (!canWrite || !activeAppointment) return
    const mutation = editor === 'reschedule' ? mutations.reschedule : mutations.update
    mutation.mutate({ id: activeAppointment.id, body }, { onSuccess: () => { message.success(editor === 'reschedule' ? 'Đổi lịch hẹn thành công' : 'Cập nhật lịch hẹn thành công'); setEditor(null) }, onError: handleError })
  }
  const error = appointments.isError || staff.isError || customers.isError
  const errorMessage = error
    ? getApiErrorMessage(appointments.error ?? staff.error ?? customers.error, 'Không thể tải danh sách lịch hẹn. Vui lòng thử lại.')
    : ''
  const staffNames = useMemo(() => new Map((staff.data ?? []).map((item) => [item.nhanVienId, item.hoTen])), [staff.data])
  const customerNames = useMemo(() => new Map((customers.data ?? []).map((item) => [item.id, item.fullName])), [customers.data])
  const appointmentItems = appointments.data?.items ?? []
  const statusCounts = appointmentItems.reduce<Record<string, number>>((counts, appointment) => {
    counts[appointment.status] = (counts[appointment.status] ?? 0) + 1
    return counts
  }, {})
  const exportAppointments = () => {
    if (!appointmentItems.length) {
      message.info('Không có lịch hẹn để xuất.')
      return
    }
    const escapeCsv = (value: unknown) => `"${String(value ?? '').replace(/"/g, '""')}"`
    const rows = [
      ['Mã lịch', 'Ngày giờ hẹn', 'Tên khách hàng', 'Nhân viên phụ trách', 'Dịch vụ/Combo', 'Trạng thái', 'Ghi chú'],
      ...appointmentItems.map((appointment) => [
        appointment.id,
        dayjs(appointment.appointmentAt).format('DD/MM/YYYY HH:mm'),
        customerNames.get(appointment.customerId) ?? `Khách #${appointment.customerId}`,
        appointment.staffId === null ? 'Chưa phân công' : staffNames.get(appointment.staffId) ?? `Nhân viên #${appointment.staffId}`,
        appointment.items.map((item) => `${item.serviceName}${item.comboId !== null ? ' (combo)' : ''}`).join(', '),
        statusLabels[appointment.status] ?? appointment.status,
        appointment.note ?? '',
      ]),
    ]
    const csv = `\\uFEFF${rows.map((row) => row.map(escapeCsv).join(',')).join('\\r\\n')}`
    const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }))
    const link = document.createElement('a')
    link.href = url
    link.download = `Danh_sach_lich_hen_${date?.format('YYYY-MM-DD') ?? dayjs().format('YYYY-MM-DD')}.csv`
    document.body.appendChild(link)
    link.click()
    link.remove()
    URL.revokeObjectURL(url)
    if ((appointments.data?.totalCount ?? appointmentItems.length) > appointmentItems.length) {
      message.info(`Đã xuất ${appointmentItems.length} lịch đang hiển thị. Hãy xuất từng trang để lấy đầy đủ kết quả.`)
    } else {
      message.success('Xuất danh sách lịch hẹn thành công!')
    }
  }

  const kpiCards = [
    { title: 'Tất cả lịch hẹn', count: appointments.data?.totalCount ?? 0, status: undefined, color: '#d9d9d9' },
    { title: 'Chờ xác nhận', count: statusCounts.ChoXacNhan ?? 0, status: 'ChoXacNhan', color: '#faad14' },
    { title: 'Đang phục vụ', count: (statusCounts.DangThucHien ?? 0) + (statusCounts.DaDen ?? 0), status: 'DaDen', color: '#1677ff' },
    { title: 'Đã hoàn thành', count: statusCounts.HoanThanh ?? 0, status: 'HoanThanh', color: '#52c41a' },
  ]

  return <>
    {error && <Alert type="error" showIcon message="Không tải được dữ liệu lịch hẹn" description={errorMessage} style={{ marginBottom: 16 }} />}
    <Row gutter={[12, 12]} style={{ marginBottom: 16 }}>
      {kpiCards.map((card) => <Col xs={12} sm={12} md={6} key={card.title}>
        <Card size="small" hoverable style={{ borderTop: `3px solid ${card.color}`, cursor: 'pointer' }} onClick={() => { setStatus(card.status); setPage(1) }}>
          <Typography.Text type="secondary">{card.title}</Typography.Text>
          <Typography.Title level={3} style={{ margin: '4px 0 0' }}>{card.count}</Typography.Title>
        </Card>
      </Col>)}
    </Row>
    <ManagementTable<Appointment>
      title="Lịch hẹn"
      columns={[
        { title: 'Ngày giờ', dataIndex: 'appointmentAt', key: 'appointmentAt', render: (value: string, appointment: Appointment) => <Space>{dayjs(value).format('DD/MM/YYYY HH:mm')}{appointment.fundingSource === 'ServicePackage' && <Tag color="purple">Gói dịch vụ</Tag>}</Space> },
        { title: 'Khách hàng', dataIndex: 'customerId', key: 'customer', render: (id: number) => customerNames.get(id) ?? `Khách #${id}` },
        { title: 'Nhân viên', dataIndex: 'staffId', key: 'staff', render: (id: number | null) => id === null ? 'Chưa phân công' : staffNames.get(id) ?? `Nhân viên #${id}` },
        { title: 'Dịch vụ', dataIndex: 'items', key: 'items', render: (items: Appointment['items']) => items.map((item) => item.serviceName).join(', ') || '—' },
        { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: (value: string, record) => { const presentation = getAppointmentStatusPresentation(value); const allowed = getAllowedNextAppointmentStatuses(value); return <Select disabled={!canWrite || allowed.length === 0} loading={mutations.status.isPending} value={value} style={{ minWidth: 160 }} options={[{ value, label: <Tag style={{ color: presentation.color, background: presentation.background, borderColor: 'transparent', fontWeight: 500 }}>{presentation.label}</Tag> }, ...allowed.map((nextStatus) => ({ value: nextStatus, label: statusLabels[nextStatus] ?? nextStatus }))]} onChange={(nextStatus: string) => modal.confirm({ title: `Đổi trạng thái lịch hẹn #${record.id} thành "${statusLabels[nextStatus]}"?`, onOk: () => mutations.status.mutate({ id: record.id, status: nextStatus }, { onError: handleError }) })} /> } },
        { title: 'Ghi chú', dataIndex: 'note', key: 'note', render: (value: string | null) => value || '—' },
        { title: 'Thao tác', key: 'details', render: (_, record) => <Button type="link" onClick={() => setSelected(record)}>Xem chi tiết</Button> },
      ]}
      data={appointmentItems}
      total={appointments.data?.totalCount ?? 0}
      searchFields={[]}
      onSearch={(value) => { setKeyword(value); setPage(1) }}
      searchPlaceholder="Tìm theo tên khách hoặc SĐT"
      loading={appointments.isLoading || staff.isLoading || customers.isLoading}
      error={error}
      page={page}
      pageSize={pageSize}
      onPageChange={(next, size) => { setPageSize(size); setPage(next) }}
      canManage={false}
      onEdit={() => undefined}
      onDelete={() => undefined}
      toolbar={<>
        <DatePicker allowClear placeholder="Lọc theo ngày" format="DD/MM/YYYY" value={date} onChange={(value) => { setDate(value); setPage(1) }} />
        <Select allowClear placeholder="Tất cả trạng thái" style={{ width: 190, maxWidth: '100%' }} value={status} onChange={(value) => { setStatus(value); setPage(1) }} options={APPOINTMENT_STATUSES.map((value) => ({ value, label: statusLabels[value] }))} />
        {canReadStaff && <Select allowClear showSearch optionFilterProp="label" placeholder="Tất cả nhân viên" style={{ width: 190, maxWidth: '100%' }} value={staffId} onChange={(value) => { setStaffId(value); setPage(1) }} options={(staff.data ?? []).map((item) => ({ value: item.nhanVienId, label: item.hoTen }))} />}
        <Button onClick={() => { setDate(dayjs()); setPage(1) }}>Hôm nay</Button>
        <Button icon={<DownloadOutlined />} onClick={exportAppointments}>Xuất danh sách</Button>
        {canCreate && <Button type="primary" onClick={() => setCreateOpen(true)}>Tạo lịch hẹn</Button>}
      </>}
    />
    {canCreate && <AppointmentCreateDrawer open={createOpen} staff={staff.data ?? []} form={createForm} onClose={() => setCreateOpen(false)} onSubmit={createAppointment} busy={mutations.create.isPending} />}
    <Drawer className="responsive-drawer" title={`Chi tiết lịch hẹn #${activeAppointment?.id ?? ''}`} open={Boolean(activeAppointment)} onClose={() => setSelected(null)} width={560}>
      {activeAppointment && <>
        {detail.isError && <Alert type="warning" message={getApiErrorMessage(detail.error, 'Không tải được thông tin chi tiết lịch hẹn.')} style={{ marginBottom: 12 }} />}
        <Descriptions column={1} bordered size="small">
          <Descriptions.Item label="Khách hàng">{detail.data?.khachHang?.hoTen ?? customerNames.get(activeAppointment.customerId) ?? `Khách #${activeAppointment.customerId}`}</Descriptions.Item>
          <Descriptions.Item label="Nhân viên">{activeAppointment.staffId === null ? 'Chưa phân công' : detail.data?.nhanVien?.hoTen ?? staffNames.get(activeAppointment.staffId) ?? `Nhân viên #${activeAppointment.staffId}`}</Descriptions.Item>
          <Descriptions.Item label="Giờ hẹn">{dayjs(activeAppointment.appointmentAt).format('DD/MM/YYYY HH:mm')}</Descriptions.Item>
          <Descriptions.Item label="Ghi chú">{activeAppointment.note || '—'}</Descriptions.Item>
          <Descriptions.Item label="Trạng thái">{(() => { const p = getAppointmentStatusPresentation(activeAppointment.status); return <Tag style={{ color: p.color, background: p.background, borderColor: 'transparent' }}>{p.label}</Tag> })()}</Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5} style={{ marginTop: 20 }}>Dịch vụ / combo</Typography.Title>
        {activeAppointment.items.length ? <>{activeAppointment.items.map((item) => <div className="booking-line" key={item.id} style={{ padding: '8px 0' }}><span>{item.serviceName}{item.comboId !== null ? ' (combo)' : ''}</span><span>{money(item.expectedPrice)}</span></div>)}<div style={{ borderTop: '1px solid #dedbd6', paddingTop: 12, textAlign: 'right', fontWeight: 500 }}>Tổng tiền: {money(activeAppointment.items.reduce((sum, item) => sum + item.expectedPrice, 0))}</div></> : <Typography.Text type="secondary">Chưa có dịch vụ</Typography.Text>}
        {canWrite && <Space wrap style={{ marginTop: 24 }}>
          {canReschedule(activeAppointment.status) && <>
            <Button onClick={() => setEditor('reschedule')}>Đổi lịch</Button><Button onClick={() => setEditor('edit')}>Sửa ghi chú / nhân viên</Button>
          </>}
          {canCancel(activeAppointment.status) && <>
            <Button danger loading={mutations.remove.isPending} onClick={() => modal.confirm({ title: 'Xác nhận xóa lịch hẹn?', content: 'Thao tác này không thể hoàn tác. Bạn có chắc chắn muốn xóa lịch hẹn này?', okText: 'Xóa', okType: 'danger', cancelText: 'Hủy', centered: true, onOk: () => mutations.remove.mutateAsync(activeAppointment.id).then(() => { message.success('Xóa lịch hẹn thành công'); setSelected(null) }).catch((error: unknown) => { handleError(error); throw error }) })}>Xóa lịch</Button>
          </>}
        </Space>}
      </>}
    </Drawer>
    <Modal className="responsive-modal" title={editor === 'reschedule' ? 'Đổi lịch hẹn' : 'Sửa ghi chú / nhân viên'} open={editor !== null && canWrite} footer={null} onCancel={() => setEditor(null)} destroyOnClose>
      {activeAppointment && editor && <AppointmentEditor key={`${activeAppointment.id}-${editor}`} appointment={activeAppointment} staff={staff.data ?? []} mode={editor} onCancel={() => setEditor(null)} onSubmit={submitEditor} busy={mutations.update.isPending || mutations.reschedule.isPending} />}
    </Modal>
  </>
}
