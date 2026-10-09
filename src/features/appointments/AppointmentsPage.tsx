import { useMemo, useState } from 'react'
import { Alert, DatePicker, Select, Space, Tag } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import type { Appointment } from '../../types/appointments'
import { getAppointmentStatusPresentation } from './appointmentStatus'
import { useAppointmentCustomers, useAppointments, useAppointmentStaff } from './appointmentQueries'

export default function AppointmentsPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [date, setDate] = useState<Dayjs | null>(null)
  const [status, setStatus] = useState<string>()
  const [staffId, setStaffId] = useState<number>()
  const [keyword, setKeyword] = useState('')
  const appointments = useAppointments()
  const staff = useAppointmentStaff()
  const customers = useAppointmentCustomers()
  const error = appointments.isError || staff.isError || customers.isError
  const errorMessage = error
    ? getApiErrorMessage(appointments.error ?? staff.error ?? customers.error, 'Không thể tải danh sách lịch hẹn. Vui lòng thử lại.')
    : ''
  const staffNames = useMemo(() => new Map((staff.data ?? []).map((item) => [item.nhanVienId, item.hoTen])), [staff.data])
  const customerNames = useMemo(() => new Map((customers.data ?? []).map((item) => [item.id, item.fullName])), [customers.data])
  const filtered = (appointments.data ?? []).filter((item) => {
    const appointmentDate = dayjs(item.appointmentAt)
    const matchesDate = !date || appointmentDate.isSame(date, 'day')
    const matchesStatus = !status || item.status === status
    const matchesStaff = staffId === undefined || item.staffId === staffId
    const customerName = customerNames.get(item.customerId) ?? ''
    const matchesKeyword = !keyword || customerName.toLocaleLowerCase().includes(keyword.toLocaleLowerCase())
    return matchesDate && matchesStatus && matchesStaff && matchesKeyword
  })

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
      ]}
      data={filtered}
      searchFields={['customerId']}
      onSearch={(value) => { setKeyword(value); setPage(1) }}
      searchPlaceholder="Tìm theo tên khách"
      loading={appointments.isLoading || staff.isLoading || customers.isLoading}
      error={error}
      page={page}
      pageSize={pageSize}
      onPageChange={(next, size) => { setPageSize(size); setPage(next) }}
      canManage={false}
      onEdit={() => undefined}
      onDelete={() => undefined}
      toolbar={<Space wrap>
        <DatePicker allowClear placeholder="Lọc theo ngày" format="DD/MM/YYYY" value={date} onChange={(value) => { setDate(value); setPage(1) }} />
        <Select allowClear placeholder="Tất cả trạng thái" style={{ width: 190 }} value={status} onChange={(value) => { setStatus(value); setPage(1) }} options={[
          { value: 'ChoXacNhan', label: 'Chờ xác nhận' }, { value: 'DaXacNhan', label: 'Đã xác nhận' },
          { value: 'KhachDaDen', label: 'Khách đã đến' }, { value: 'DangThucHien', label: 'Đang thực hiện' },
          { value: 'HoanThanh', label: 'Hoàn thành' }, { value: 'DaHuy', label: 'Đã hủy' },
        ]} />
        <Select allowClear showSearch optionFilterProp="label" placeholder="Tất cả nhân viên" style={{ width: 190 }} value={staffId} onChange={(value) => { setStaffId(value); setPage(1) }} options={(staff.data ?? []).map((item) => ({ value: item.nhanVienId, label: item.hoTen }))} />
      </Space>}
    />
  </>
}
