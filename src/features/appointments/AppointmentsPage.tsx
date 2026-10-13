import axios from 'axios'
import { useEffect, useMemo, useState } from 'react'
import { App as AntApp, Alert, Button, DatePicker, Descriptions, Drawer, Form, Input, Modal, Popconfirm, Select, Space, Tag, TimePicker, Typography } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import * as appointmentsApi from '../../api/appointments'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import { useAuth } from '../../hooks/useAuth'
import type { Appointment, AppointmentUpdateRequest, CreateAppointmentRequest, Staff } from '../../types/appointments'
import { useServices, useCombos } from '../services/serviceQueries'
import { APPOINTMENT_STATUS, APPOINTMENT_STATUSES, getAllowedNextAppointmentStatuses, getAppointmentStatusPresentation } from './appointmentStatus'
import { appointmentKeys, useAppointmentCustomers, useAppointments, useAppointmentStaff, useAvailableSlots } from './appointmentQueries'

const writableRoles: string[] = [ACCOUNT_ROLES.ADMIN, ACCOUNT_ROLES.MANAGER, ACCOUNT_ROLES.RECEPTION]
const statusLabels: Record<string, string> = { ChoXacNhan: 'Chờ xác nhận', DaXacNhan: 'Đã xác nhận', DaDen: 'Khách đã đến', DangThucHien: 'Đang thực hiện', HoanThanh: 'Hoàn thành', DaHuy: 'Đã hủy' }
const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

function AppointmentEditor({ appointment, staff, mode, onCancel, onSubmit, busy }: { appointment: Appointment; staff: Staff[]; mode: 'edit' | 'reschedule'; onCancel: () => void; onSubmit: (body: AppointmentUpdateRequest) => void; busy: boolean }) {
  const [form] = Form.useForm<{ appointmentDate: Dayjs; appointmentTime: Dayjs; staffId: number | null; note: string }>()
  const [date, setDate] = useState(dayjs(appointment.appointmentAt))
  const [selectedStaff, setSelectedStaff] = useState<number | undefined>(appointment.staffId ?? undefined)
  const slots = useAvailableSlots(date.format('YYYY-MM-DD'), selectedStaff)
  const slotOptions = (slots.data ?? []).flatMap((slot) => {
    for (const key of ['appointmentAt', 'startAt', 'startTime', 'time', 'availableAt']) {
      const value = slot[key]
      if (typeof value === 'string' && dayjs(value).isValid()) return [{ value, label: typeof slot.label === 'string' ? slot.label : dayjs(value).format('HH:mm') }]
    }
    return []
  })
  return <Form form={form} layout="vertical" initialValues={{ appointmentDate: dayjs(appointment.appointmentAt), appointmentTime: dayjs(appointment.appointmentAt), staffId: appointment.staffId, note: appointment.note ?? '' }} onFinish={(values) => onSubmit({ appointmentAt: values.appointmentDate.hour(values.appointmentTime.hour()).minute(values.appointmentTime.minute()).second(0).toISOString(), staffId: values.staffId ?? null, note: values.note.trim() || null })}>
    <Form.Item label="Ngày hẹn" name="appointmentDate" rules={[{ required: true, message: 'Vui lòng chọn ngày hẹn' }]}><DatePicker format="DD/MM/YYYY" style={{ width: '100%' }} onChange={(value) => { if (value) { setDate(value); form.setFieldValue('appointmentTime', null) } }} /></Form.Item>
    <Form.Item label="Nhân viên" name="staffId"><Select allowClear placeholder="Chưa phân công" options={staff.map((item) => ({ value: item.nhanVienId, label: item.hoTen }))} onChange={setSelectedStaff} /></Form.Item>
    {mode === 'reschedule' && <>
      {slots.isLoading && <Alert type="info" message="Đang tải khung giờ trống…" style={{ marginBottom: 12 }} />}
      {slots.isError && <Alert type="warning" message={getApiErrorMessage(slots.error, 'Không tải được khung giờ trống')} style={{ marginBottom: 12 }} />}
      {!slots.isLoading && !slots.isError && slotOptions.length === 0 && <Alert type="info" message="Chưa có khung giờ trống" description="Bạn có thể nhập giờ tự do bên dưới." style={{ marginBottom: 12 }} />}
      {slotOptions.length > 0 && <Form.Item label="Khung giờ trống"><Select options={slotOptions} placeholder="Chọn khung giờ" onChange={(value: string) => form.setFieldValue('appointmentTime', dayjs(value))} /></Form.Item>}
    </>}
    <Form.Item label="Giờ hẹn" name="appointmentTime" rules={[{ required: true, message: 'Vui lòng chọn giờ hẹn' }]}><TimePicker format="HH:mm" minuteStep={5} style={{ width: '100%' }} /></Form.Item>
    <Form.Item label="Ghi chú" name="note"><Input.TextArea rows={3} maxLength={1000} /></Form.Item>
    <Space><Button type="primary" htmlType="submit" loading={busy}>Lưu</Button><Button onClick={onCancel}>Hủy</Button></Space>
  </Form>
}


type CreateFields = { customerId: number; staffId?: number; appointmentDate: Dayjs; appointmentTime: Dayjs; itemKeys: string[]; note?: string }

function localAppointmentDateTime(date: Dayjs, time: Dayjs): string {
  return `${date.format('YYYY-MM-DD')}T${time.format('HH:mm:ss')}`
}

function AppointmentCreateDrawer({ open, staff, form, onClose, onSubmit, busy }: { open: boolean; staff: Staff[]; form: ReturnType<typeof Form.useForm<CreateFields>>[0]; onClose: () => void; onSubmit: (body: CreateAppointmentRequest) => void; busy: boolean }) {
  const [date, setDate] = useState<Dayjs | null>(null)
  const [staffId, setStaffId] = useState<number | undefined>()
  const [customerKeyword, setCustomerKeyword] = useState('')
  const [debouncedKeyword, setDebouncedKeyword] = useState('')
  const customers = useAppointmentCustomers(debouncedKeyword)
  const slots = useAvailableSlots(date?.format('YYYY-MM-DD') ?? '', staffId)
  const services = useServices()
  const combos = useCombos()
  useEffect(() => {
    const timeout = window.setTimeout(() => setDebouncedKeyword(customerKeyword.trim()), 350)
    return () => window.clearTimeout(timeout)
  }, [customerKeyword])
  useEffect(() => {
    if (!open) form.resetFields()
  }, [open, form])
  const serviceMap = new Map((services.data ?? []).map((service) => [service.id, service]))
  const selectedKeys = Form.useWatch('itemKeys', form) ?? []
  const itemOptions = [
    ...(services.data ?? []).map((service) => ({ value: `service:${service.id}`, label: `Dịch vụ: ${service.name ?? 'Không tên'} — ${money(service.price)}` })),
    ...(combos.data ?? []).map((combo) => ({ value: `combo:${combo.id}`, label: `Combo: ${combo.name ?? 'Không tên'} — ${money(combo.price)}` })),
  ]
  const estimate = selectedKeys.reduce((total, key) => {
    const [kind, rawId] = key.split(':')
    const id = Number(rawId)
    return total + (kind === 'service' ? serviceMap.get(id)?.price ?? 0 : combos.data?.find((combo) => combo.id === id)?.price ?? 0)
  }, 0)
  const slotOptions = (slots.data ?? []).flatMap((slot) => {
    for (const key of ['appointmentAt', 'startAt', 'startTime', 'time', 'availableAt']) {
      const value = slot[key]
      if (typeof value === 'string' && dayjs(value).isValid()) return [{ value: dayjs(value).format('HH:mm'), label: typeof slot.label === 'string' ? slot.label : dayjs(value).format('HH:mm') }]
    }
    return []
  })
  const finish = (values: CreateFields) => {
    const items = values.itemKeys.flatMap<CreateAppointmentRequest['items'][number]>((key) => {
      const [kind, rawId] = key.split(':')
      const id = Number(rawId)
      if (kind === 'service') {
        const service = serviceMap.get(id)
        return service ? [{ serviceId: service.id, comboId: null, expectedPrice: service.price }] : []
      }
      const combo = combos.data?.find((item) => item.id === id)
      const componentId = combo?.items?.find((item) => serviceMap.has(item.serviceId))?.serviceId
      return combo && componentId !== undefined ? [{ serviceId: componentId, comboId: combo.id, expectedPrice: combo.price }] : []
    })
    onSubmit({ appointmentAt: localAppointmentDateTime(values.appointmentDate, values.appointmentTime), items, note: values.note?.trim() || null, customerId: values.customerId, staffId: values.staffId ?? null })
  }
  return <Drawer title="Tạo lịch hẹn" open={open} onClose={onClose} width={560} destroyOnClose>
    <Form form={form} layout="vertical" onFinish={finish}>
      <Form.Item label="Khách hàng" name="customerId" rules={[{ required: true, message: 'Vui lòng chọn khách hàng' }]}><Select showSearch filterOption={false} onSearch={setCustomerKeyword} loading={customers.isFetching} placeholder="Tìm theo tên hoặc số điện thoại" notFoundContent={customers.isError ? 'Không tải được khách hàng' : 'Không tìm thấy khách hàng'} options={(customers.data ?? []).map((customer) => ({ value: customer.id, label: `${customer.fullName} — ${customer.phone ?? 'Chưa có SĐT'}` }))} /></Form.Item>
      <Form.Item label="Nhân viên" name="staffId"><Select allowClear placeholder="Chọn nhân viên" options={staff.map((item) => ({ value: item.nhanVienId, label: `${item.hoTen}${item.soDienThoai ? ` — ${item.soDienThoai}` : ''}` }))} onChange={setStaffId} /></Form.Item>
      <Form.Item label="Ngày hẹn" name="appointmentDate" rules={[{ required: true, message: 'Vui lòng chọn ngày hẹn' }]}><DatePicker format="DD/MM/YYYY" disabledDate={(value) => value.isBefore(dayjs(), 'day')} style={{ width: '100%' }} onChange={(value) => { setDate(value); form.setFieldValue('appointmentTime', null) }} /></Form.Item>
      {date && staffId !== undefined && <>
        {slots.isLoading && <Alert type="info" message="Đang tải khung giờ trống…" style={{ marginBottom: 12 }} />}
        {slots.isError && <Alert type="warning" message={getApiErrorMessage(slots.error, 'Không tải được khung giờ trống')} style={{ marginBottom: 12 }} />}
        {!slots.isLoading && !slots.isError && slotOptions.length === 0 && <Alert type="info" message="Không có khung giờ gợi ý" description="Bạn có thể nhập giờ tự do; backend sẽ kiểm tra trùng lịch." style={{ marginBottom: 12 }} />}
        {slotOptions.length > 0 && <Form.Item label="Khung giờ gợi ý"><Select options={slotOptions} placeholder="Chọn khung giờ trống" onChange={(value: string) => form.setFieldValue('appointmentTime', dayjs(`2000-01-01T${value}`))} /></Form.Item>}
      </>}
      <Form.Item label="Giờ hẹn" name="appointmentTime" rules={[{ required: true, message: 'Vui lòng chọn giờ hẹn' }, { validator: (_, value: Dayjs | undefined) => !value || !date || !date.isSame(dayjs(), 'day') || value.isAfter(dayjs(), 'minute') ? Promise.resolve() : Promise.reject(new Error('Vui lòng chọn thời điểm trong tương lai')) }]}><TimePicker format="HH:mm" minuteStep={5} style={{ width: '100%' }} /></Form.Item>
      <Form.Item label="Dịch vụ / combo" name="itemKeys" rules={[{ required: true, type: 'array', min: 1, message: 'Chọn ít nhất một dịch vụ hoặc combo' }]}><Select mode="multiple" placeholder="Chọn dịch vụ hoặc combo" options={itemOptions} loading={services.isLoading || combos.isLoading} /></Form.Item>
      {(services.isError || combos.isError) && <Alert type="error" message="Không tải được danh sách dịch vụ/combo" style={{ marginBottom: 16 }} />}
      <Alert type="info" message={`Tổng tiền dự kiến: ${money(estimate)}`} description="Dự kiến, backend tính chính thức." style={{ marginBottom: 16 }} />
      <Form.Item label="Ghi chú" name="note"><Input.TextArea rows={3} maxLength={1000} /></Form.Item>
      <Space><Button type="primary" htmlType="submit" loading={busy}>Tạo lịch hẹn</Button><Button onClick={onClose}>Hủy</Button></Space>
    </Form>
  </Drawer>
}

function useAppointmentMutations() {
  const client = useQueryClient()

  const invalidate = () => client.invalidateQueries({ queryKey: appointmentKeys.appointments })
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
  const role = useAuth()?.account?.role
  const canWrite = role !== null && role !== undefined && writableRoles.includes(role)
  const mutations = useAppointmentMutations()
  const filters = useMemo(() => ({
    ...(date ? { from: date.startOf('day').toISOString(), to: date.endOf('day').toISOString() } : {}),
    ...(status ? { status } : {}),
    ...(staffId !== undefined ? { staffId } : {}),
    ...(debouncedKeyword ? { keyword: debouncedKeyword } : {}),
    page,
    pageSize,
  }), [date, status, staffId, debouncedKeyword, page, pageSize])
  const appointments = useAppointments(filters)
  const staff = useAppointmentStaff()
  const customers = useAppointmentCustomers()
  const pending = mutations.update.isPending || mutations.reschedule.isPending || mutations.status.isPending || mutations.remove.isPending || mutations.create.isPending
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
    if (!activeAppointment) return
    const mutation = editor === 'reschedule' ? mutations.reschedule : mutations.update
    mutation.mutate({ id: activeAppointment.id, body }, { onSuccess: () => { message.success(editor === 'reschedule' ? 'Đổi lịch hẹn thành công' : 'Cập nhật lịch hẹn thành công'); setEditor(null) }, onError: handleError })
  }
  const confirmStatus = (appointment: Appointment, nextStatus: string) => modal.confirm({ title: `Đổi trạng thái thành “${statusLabels[nextStatus] ?? nextStatus}”?`, content: 'Xác nhận cập nhật trạng thái lịch hẹn.', okText: 'Xác nhận', cancelText: 'Hủy', onOk: () => new Promise<void>((resolve, reject) => mutations.status.mutate({ id: appointment.id, status: nextStatus }, { onSuccess: () => { message.success('Cập nhật trạng thái thành công'); resolve() }, onError: (error: unknown) => { handleError(error); reject(error) } })) })
  const error = appointments.isError || staff.isError || customers.isError
  const errorMessage = error
    ? getApiErrorMessage(appointments.error ?? staff.error ?? customers.error, 'Không thể tải danh sách lịch hẹn. Vui lòng thử lại.')
    : ''
  const staffNames = useMemo(() => new Map((staff.data ?? []).map((item) => [item.nhanVienId, item.hoTen])), [staff.data])
  const customerNames = useMemo(() => new Map((customers.data ?? []).map((item) => [item.id, item.fullName])), [customers.data])
  const appointmentItems = appointments.data?.items ?? []

  return <>
    {error && <Alert type="error" showIcon message="Không tải được dữ liệu lịch hẹn" description={errorMessage} style={{ marginBottom: 16 }} />}
    <ManagementTable<Appointment>
      title="Lịch hẹn"
      columns={[
        { title: 'Ngày giờ', dataIndex: 'appointmentAt', key: 'appointmentAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
        { title: 'Khách hàng', dataIndex: 'customerId', key: 'customer', render: (id: number) => customerNames.get(id) ?? 'Không rõ khách hàng' },
        { title: 'Nhân viên', dataIndex: 'staffId', key: 'staff', render: (id: number | null) => id === null ? 'Chưa phân công' : staffNames.get(id) ?? 'Không rõ nhân viên' },
        { title: 'Dịch vụ', dataIndex: 'items', key: 'items', render: (items: Appointment['items']) => items.map((item) => item.serviceName).join(', ') || '—' },
        { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: (value: string) => { const presentation = getAppointmentStatusPresentation(value); return <Tag style={{ color: presentation.color, background: presentation.background, borderColor: 'transparent', fontWeight: 500 }}>{presentation.label}</Tag> } },
        { title: 'Ghi chú', dataIndex: 'note', key: 'note', render: (value: string | null) => value || '—' },
        { title: 'Chi tiết', key: 'details', render: (_, record) => <Button type="link" onClick={() => setSelected(record)}>Xem chi tiết</Button> },
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
      toolbar={<Space wrap>
        {canWrite && <Button type="primary" onClick={() => setCreateOpen(true)}>Tạo lịch hẹn</Button>}
        <DatePicker allowClear placeholder="Lọc theo ngày" format="DD/MM/YYYY" value={date} onChange={(value) => { setDate(value); setPage(1) }} />
        <Select allowClear placeholder="Tất cả trạng thái" style={{ width: 190 }} value={status} onChange={(value) => { setStatus(value); setPage(1) }} options={APPOINTMENT_STATUSES.map((value) => ({ value, label: statusLabels[value] }))} />
        <Select allowClear showSearch optionFilterProp="label" placeholder="Tất cả nhân viên" style={{ width: 190 }} value={staffId} onChange={(value) => { setStaffId(value); setPage(1) }} options={(staff.data ?? []).map((item) => ({ value: item.nhanVienId, label: item.hoTen }))} />
      </Space>}
    />
    <AppointmentCreateDrawer open={createOpen} staff={staff.data ?? []} form={createForm} onClose={() => setCreateOpen(false)} onSubmit={createAppointment} busy={mutations.create.isPending} />
    <Drawer title={`Chi tiết lịch hẹn #${activeAppointment?.id ?? ''}`} open={Boolean(activeAppointment)} onClose={() => setSelected(null)} width={560}>
      {activeAppointment && <>
        <Descriptions column={1} bordered size="small">
          <Descriptions.Item label="Khách hàng">{customerNames.get(activeAppointment.customerId) ?? 'Không rõ khách hàng'}</Descriptions.Item>
          <Descriptions.Item label="Nhân viên">{activeAppointment.staffId === null ? 'Chưa phân công' : staffNames.get(activeAppointment.staffId) ?? 'Không rõ nhân viên'}</Descriptions.Item>
          <Descriptions.Item label="Giờ hẹn">{dayjs(activeAppointment.appointmentAt).format('DD/MM/YYYY HH:mm')}</Descriptions.Item>
          <Descriptions.Item label="Ghi chú">{activeAppointment.note || '—'}</Descriptions.Item>
          <Descriptions.Item label="Trạng thái">{(() => { const p = getAppointmentStatusPresentation(activeAppointment.status); return <Tag style={{ color: p.color, background: p.background, borderColor: 'transparent' }}>{p.label}</Tag> })()}</Descriptions.Item>
        </Descriptions>
        <Typography.Title level={5} style={{ marginTop: 20 }}>Dịch vụ / combo</Typography.Title>
        {activeAppointment.items.length ? <>{activeAppointment.items.map((item) => <div key={item.id} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0' }}><span>{item.serviceName}{item.comboId !== null ? ' (combo)' : ''}</span><span>{money(item.expectedPrice)}</span></div>)}<div style={{ borderTop: '1px solid #dedbd6', paddingTop: 12, textAlign: 'right', fontWeight: 500 }}>Tổng tiền: {money(activeAppointment.items.reduce((sum, item) => sum + item.expectedPrice, 0))}</div></> : <Typography.Text type="secondary">Chưa có dịch vụ</Typography.Text>}
        {canWrite && <Space wrap style={{ marginTop: 24 }}>
          {getAllowedNextAppointmentStatuses(activeAppointment.status).map((next) => <Button key={next} loading={pending} onClick={() => confirmStatus(activeAppointment, next)}>{next === 'DaHuy' ? 'Hủy lịch' : `Chuyển: ${statusLabels[next] ?? next}`}</Button>)}
          {activeAppointment.status !== APPOINTMENT_STATUS.COMPLETED && activeAppointment.status !== APPOINTMENT_STATUS.CANCELLED && <>
            <Button onClick={() => setEditor('reschedule')}>Đổi lịch</Button><Button onClick={() => setEditor('edit')}>Sửa ghi chú / nhân viên</Button>
            <Popconfirm title="Xóa lịch hẹn này?" description="Thao tác này không thể hoàn tác." okText="Xóa" cancelText="Hủy" onConfirm={() => mutations.remove.mutate(activeAppointment.id, { onSuccess: () => { message.success('Xóa lịch hẹn thành công'); setSelected(null) }, onError: handleError })}><Button danger loading={mutations.remove.isPending}>Xóa lịch</Button></Popconfirm>
          </>}
        </Space>}
      </>}
    </Drawer>
    <Modal title={editor === 'reschedule' ? 'Đổi lịch hẹn' : 'Sửa ghi chú / nhân viên'} open={editor !== null} footer={null} onCancel={() => setEditor(null)} destroyOnClose>
      {activeAppointment && editor && <AppointmentEditor key={`${activeAppointment.id}-${editor}`} appointment={activeAppointment} staff={staff.data ?? []} mode={editor} onCancel={() => setEditor(null)} onSubmit={submitEditor} busy={mutations.update.isPending || mutations.reschedule.isPending} />}
    </Modal>
  </>
}
