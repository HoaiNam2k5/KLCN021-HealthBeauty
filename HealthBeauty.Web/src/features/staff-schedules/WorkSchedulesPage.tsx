import { useMemo, useState } from 'react'
import { App as AntApp, Button, DatePicker, Form, Modal, Select, Space, TimePicker, Typography } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import { useAuth } from '../../hooks/useAuth'
import { usePermissions } from '../../hooks/usePermissions'
import type { WorkSchedule, WorkScheduleRequest } from '../../types/workSchedules'
import { hasScheduleConflict } from '../../types/workSchedules'
import { useDeleteWorkSchedule, useSaveWorkSchedule, useScheduleStaff, useWorkSchedules } from './scheduleQueries'

interface FormValues { staffId: number; workDate: Dayjs; startAt: Dayjs; endAt: Dayjs }
const weekStart = dayjs().startOf('week')

export default function WorkSchedulesPage() {
  const [form] = Form.useForm<FormValues>()
  const [editing, setEditing] = useState<WorkSchedule | null>(null)
  const [open, setOpen] = useState(false)
  const [staffId, setStaffId] = useState<number | undefined>()
  const [week, setWeek] = useState(weekStart)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const { message } = AntApp.useApp()
  const role = useAuth()?.account?.role
  const { has } = usePermissions()
  const canManage = role !== ACCOUNT_ROLES.STAFF && has('STAFF.WRITE')
  const own = role === ACCOUNT_ROLES.STAFF
  const staffQuery = useScheduleStaff(!own && has('STAFF.READ'))
  const filters = useMemo(() => ({ staffId, from: week.startOf('week').format('YYYY-MM-DD'), to: week.endOf('week').format('YYYY-MM-DD') }), [staffId, week])
  const query = useWorkSchedules(filters, own)
  const save = useSaveWorkSchedule()
  const remove = useDeleteWorkSchedule()
  const schedules = query.data ?? []
  const data = [...schedules].sort((a, b) => a.ngayLam.localeCompare(b.ngayLam) || a.gioBatDau.localeCompare(b.gioBatDau))
  const staffOptions = (staffQuery.data ?? []).map((staff) => ({ value: staff.nhanVienId, label: staff.hoTen }))

  function openForm(record?: WorkSchedule) {
    if (!canManage) return
    setEditing(record ?? null)
    form.setFieldsValue({ staffId: record?.nhanVienId ?? staffId, workDate: dayjs(record?.ngayLam ?? week.format('YYYY-MM-DD')), startAt: dayjs(`2000-01-01T${record?.gioBatDau ?? '09:00:00'}`), endAt: dayjs(`2000-01-01T${record?.gioKetThuc ?? '18:00:00'}`) })
    setOpen(true)
  }

  async function submit(values: FormValues) {
    if (!canManage) return
    const startAt = values.startAt.format('HH:mm:ss')
    const endAt = values.endAt.format('HH:mm:ss')
    if (endAt <= startAt) {
      form.setFields([{ name: 'endAt', errors: ['Giờ kết thúc phải sau giờ bắt đầu.'] }])
      return
    }
    const body: WorkScheduleRequest = { staffId: values.staffId, workDate: values.workDate.format('YYYY-MM-DD'), startAt, endAt, status: editing?.trangThai || 'HoatDong' }
    if (hasScheduleConflict(schedules, body, editing?.id)) {
      message.error('Ca làm bị trùng với một ca khác của nhân viên trong ngày này.')
      return
    }
    try {
      await save.mutateAsync({ id: editing?.id, body })
      message.success(editing ? 'Cập nhật ca làm thành công.' : 'Thêm ca làm thành công.')
      setOpen(false)
    } catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu ca làm. Vui lòng thử lại.')) }
  }

  async function deleteRecord(record: WorkSchedule) {
    if (!canManage) return
    try {
      await remove.mutateAsync(record.id)
      message.success('Xóa ca làm thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa ca làm. Vui lòng thử lại.'))
      throw error
    }
  }

  return <>
    <ManagementTable<WorkSchedule> title="Lịch làm việc nhân viên" columns={[
      { title: 'Ngày làm', dataIndex: 'ngayLam', key: 'ngayLam', render: (value: string) => dayjs(value).format('DD/MM/YYYY') },
      { title: 'Nhân viên', dataIndex: 'staffName', key: 'staffName' },
      { title: 'Giờ bắt đầu', dataIndex: 'gioBatDau', key: 'gioBatDau', render: (value: string) => value.slice(0, 5) },
      { title: 'Giờ kết thúc', dataIndex: 'gioKetThuc', key: 'gioKetThuc', render: (value: string) => value.slice(0, 5) },
      { title: 'Trạng thái', dataIndex: 'trangThai', key: 'trangThai' },
    ]} data={data} loading={query.isLoading || staffQuery.isLoading} error={query.isError || staffQuery.isError} page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }} canManage={canManage} onEdit={openForm} onDelete={deleteRecord}
    onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
    toolbar={<Space className="filter-bar" wrap>
      {!own && <Select allowClear placeholder="Tất cả nhân viên" style={{ width: 210, maxWidth: '100%' }} value={staffId} options={staffOptions} onChange={(value: number | undefined) => { setStaffId(value); setPage(1) }} />}
      <Space className="page-toolbar" wrap><Button onClick={() => setWeek((current) => current.subtract(1, 'week'))}>Tuần trước</Button><Typography.Text>{week.startOf('week').format('DD/MM')} – {week.endOf('week').format('DD/MM/YYYY')}</Typography.Text><Button onClick={() => setWeek((current) => current.add(1, 'week'))}>Tuần sau</Button></Space>
      {canManage && <Button type="primary" onClick={() => openForm()}>Thêm ca làm</Button>}
    </Space>} />
    {(query.isError || staffQuery.isError) && <div role="alert">{getApiErrorMessage(query.error ?? staffQuery.error, 'Không tải được lịch làm việc.')}</div>}
    <Modal className="responsive-modal" title={editing ? 'Sửa ca làm' : 'Thêm ca làm'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="staffId" label="Nhân viên" rules={[{ required: true, message: 'Vui lòng chọn nhân viên.' }]}><Select options={staffOptions} /></Form.Item>
        <Form.Item name="workDate" label="Ngày làm" rules={[{ required: true, message: 'Vui lòng chọn ngày làm.' }]}><DatePicker format="DD/MM/YYYY" style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="startAt" label="Giờ bắt đầu" rules={[{ required: true, message: 'Vui lòng chọn giờ bắt đầu.' }]}><TimePicker format="HH:mm" minuteStep={15} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="endAt" label="Giờ kết thúc" rules={[{ required: true, message: 'Vui lòng chọn giờ kết thúc.' }]}><TimePicker format="HH:mm" minuteStep={15} style={{ width: '100%' }} /></Form.Item>
      </Form>
    </Modal>
  </>
}
