import { useEffect, useMemo, useState } from 'react'
import { Alert, Avatar, Badge, Button, Card, DatePicker, Empty, Spin, Tag, Tooltip, Typography } from 'antd'
import { CalendarOutlined, LeftOutlined, PlusOutlined, RightOutlined, UserOutlined } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import type { Appointment, Staff } from '../../types/appointments'
import { getAppointmentStatusPresentation } from './appointmentStatus'
import { appointmentDuration, appointmentEnd, buildTimelineModel, canQuickBookTimeline, timelineCellKey } from './timelineModel'

interface StaffTimelineMatrixProps {
  currentDate: Dayjs
  onDateChange: (date: Dayjs) => void
  appointments: Appointment[]
  staffList: Staff[]
  customerNames: Map<number, string>
  onSelectAppointment: (appointment: Appointment) => void
  onQuickBook?: (staffId: number | undefined, hour: number) => void
  canCreate: boolean
  isLoading: boolean
  isRefreshing?: boolean
  error?: string
  onRetry?: () => void
}

export default function StaffTimelineMatrix({
  currentDate,
  onDateChange,
  appointments,
  staffList,
  customerNames,
  onSelectAppointment,
  onQuickBook,
  canCreate,
  isLoading,
  isRefreshing = false,
  error,
  onRetry,
}: StaffTimelineMatrixProps) {
  const day = currentDate.format('YYYY-MM-DD')
  const model = useMemo(() => buildTimelineModel(day, appointments, staffList), [day, appointments, staffList])
  const dayAppointments = model.appointments
  const columns = model.columns
  const [now, setNow] = useState(() => Date.now())
  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), 60000)
    return () => window.clearInterval(timer)
  }, [])

  // Count appointments per staff
  const staffAppointmentCounts = useMemo(() => {
    const counts = new Map<number | null, number>()
    for (const apt of dayAppointments) {
      counts.set(apt.staffId, (counts.get(apt.staffId) ?? 0) + 1)
    }
    return counts
  }, [dayAppointments])

  const totalToday = dayAppointments.length
  const completedToday = dayAppointments.filter((a) => a.status === 'HoanThanh').length
  const inProgressToday = dayAppointments.filter((a) => a.status === 'DangThucHien' || a.status === 'DaDen').length

  return (
    <Card
      size="small"
      style={{ borderRadius: 10, border: '1px solid #e8e4e0', overflow: 'hidden' }}
      title={
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <CalendarOutlined style={{ color: '#8c4559', fontSize: 18 }} />
            <Typography.Text strong style={{ fontSize: 15 }}>
              Ma trận xếp lịch kỹ thuật viên ({currentDate.format('dddd, DD/MM/YYYY')})
            </Typography.Text>
          </div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <Button
              size="small"
              icon={<LeftOutlined />}
              onClick={() => onDateChange(currentDate.subtract(1, 'day'))}
              title="Ngày trước"
            />
            <DatePicker
              size="small"
              allowClear={false}
              format="DD/MM/YYYY"
              value={currentDate}
              onChange={(val) => { if (val) onDateChange(val) }}
              style={{ width: 125 }}
            />
            <Button
              size="small"
              icon={<RightOutlined />}
              onClick={() => onDateChange(currentDate.add(1, 'day'))}
              title="Ngày sau"
            />
            <Button
              size="small"
              type={currentDate.isSame(dayjs(), 'day') ? 'primary' : 'default'}
              onClick={() => onDateChange(dayjs())}
            >
              Hôm nay
            </Button>
          </div>
        </div>
      }
      extra={
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <Tag color="default">Tổng: <b>{totalToday}</b></Tag>
          <Tag color="processing">Đang phục vụ: <b>{inProgressToday}</b></Tag>
          <Tag color="success">Hoàn thành: <b>{completedToday}</b></Tag>
        </div>
      }
    >
      <Alert type="info" showIcon style={{ marginBottom: 12 }} message="Ma trận hiển thị toàn bộ lịch trong ngày, không áp dụng bộ lọc của bảng." description="Ô chưa có lịch chưa xác nhận ca làm hoặc khả năng nhận dịch vụ. Khung giờ sẽ được kiểm tra lại khi chọn dịch vụ và lưu lịch hẹn." />
      {error ? <Alert type="error" showIcon message="Chưa thể xác minh lịch trong ngày" description={error} action={<Button onClick={onRetry}>Tải lại</Button>} /> : isLoading ? (
        <div style={{ padding: '60px 0', textAlign: 'center' }}>
          <Spin tip="Đang tải lịch hẹn và nhân viên…" />
        </div>
      ) : columns.length === 0 ? (
        <Empty description="Không có dữ liệu nhân viên để hiển thị ma trận" />
      ) : (
        <div style={{ overflowX: 'auto', maxHeight: '72vh', overflowY: 'auto' }}>
          <table
            style={{
              width: '100%',
              minWidth: Math.max(760, columns.length * 180 + 90),
              borderCollapse: 'separate',
              borderSpacing: 0,
              fontSize: 13,
            }}
          >
            <thead>
              <tr>
                <th
                  style={{
                    position: 'sticky',
                    top: 0,
                    left: 0,
                    zIndex: 10,
                    width: 90,
                    minWidth: 90,
                    padding: '10px 8px',
                    background: '#f5f3f0',
                    borderBottom: '2px solid #e0dbd5',
                    borderRight: '2px solid #e0dbd5',
                    textAlign: 'center',
                    fontWeight: 600,
                  }}
                >
                  Giờ hẹn
                </th>
                {columns.map((col) => {
                  const count = staffAppointmentCounts.get(col.id) ?? 0
                  return (
                    <th
                      key={col.id ?? 'unassigned'}
                      style={{
                        position: 'sticky',
                        top: 0,
                        zIndex: 5,
                        minWidth: 175,
                        padding: '8px 10px',
                        background: '#faf8f6',
                        borderBottom: '2px solid #e0dbd5',
                        borderRight: '1px solid #eee5df',
                        textAlign: 'left',
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 8, overflow: 'hidden' }}>
                          <Avatar
                            size={28}
                            icon={col.id === null ? <UserOutlined /> : undefined}
                            style={{
                              background: col.id === null ? '#d9d9d9' : '#8c4559',
                              color: '#fff',
                              fontSize: 12,
                              flexShrink: 0,
                            }}
                          >
                            {col.id !== null ? col.name.trim().split(' ').pop()?.slice(0, 2).toUpperCase() : null}
                          </Avatar>
                          <div style={{ overflow: 'hidden' }}>
                            <Typography.Text strong style={{ fontSize: 13, display: 'block', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                              {col.name}
                            </Typography.Text>
                          </div>
                        </div>
                        <Badge
                          count={count}
                          overflowCount={99}
                          style={{
                            backgroundColor: count > 0 ? '#8c4559' : '#d9d9d9',
                            boxShadow: 'none',
                          }}
                        />
                      </div>
                    </th>
                  )
                })}
              </tr>
            </thead>
            <tbody>
              {model.hours.map((hour) => {
                const hourFormatted = `${hour.toString().padStart(2, '0')}:00`
                const isCurrentHour = currentDate.isSame(dayjs(now), 'day') && dayjs(now).hour() === hour
                return (
                  <tr key={hour} style={{ background: isCurrentHour ? '#fffbf0' : '#ffffff' }}>
                    <td
                      style={{
                        position: 'sticky',
                        left: 0,
                        zIndex: 4,
                        padding: '10px 6px',
                        background: isCurrentHour ? '#fff7e6' : '#faf9f7',
                        borderBottom: '1px solid #eee',
                        borderRight: '2px solid #e0dbd5',
                        textAlign: 'center',
                        fontWeight: isCurrentHour ? 700 : 500,
                        color: isCurrentHour ? '#d46b08' : '#666',
                      }}
                    >
                      {hourFormatted}
                    </td>
                    {columns.map((col) => {
                      const key = timelineCellKey(col.id, hour)
                      const itemsInSlot = model.cells.get(key) ?? []
                      const canBook = canCreate && canQuickBookTimeline(day, hour, col.id, model, !isLoading && !isRefreshing && !error, now)
                      return (
                        <td
                          key={col.id ?? 'unassigned'}
                          style={{
                            padding: '6px',
                            borderBottom: '1px solid #f0ece9',
                            borderRight: '1px solid #f0ece9',
                            verticalAlign: 'top',
                            background: isCurrentHour ? 'rgba(255, 251, 230, 0.4)' : '#ffffff',
                            position: 'relative',
                            minHeight: 68,
                            height: 68,
                          }}
                        >
                          {itemsInSlot.length > 0 ? (
                            <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
                              {itemsInSlot.map((apt) => {
                                const presentation = getAppointmentStatusPresentation(apt.status)
                                const customerName = apt.customerName || customerNames.get(apt.customerId) || `Khách #${apt.customerId}`
                                const serviceNames = apt.items.map((i) => i.serviceName).join(', ') || 'Dịch vụ'
                                const timeStr = `${dayjs(apt.appointmentAt).format('DD/MM HH:mm')} – ${dayjs(appointmentEnd(apt)).format('DD/MM HH:mm')}`
                                return (
                                  <div
                                    key={apt.id}
                                    onClick={() => onSelectAppointment(apt)}
                                    style={{
                                      padding: '6px 8px',
                                      borderRadius: 6,
                                      background: presentation.background || '#f0f5ff',
                                      borderLeft: `4px solid ${presentation.color || '#1677ff'}`,
                                      boxShadow: '0 1px 3px rgba(0,0,0,0.06)',
                                      cursor: 'pointer',
                                      transition: 'all 0.15s ease',
                                    }}
                                    onMouseEnter={(e) => {
                                      e.currentTarget.style.transform = 'translateY(-1px)'
                                      e.currentTarget.style.boxShadow = '0 3px 8px rgba(0,0,0,0.12)'
                                    }}
                                    onMouseLeave={(e) => {
                                      e.currentTarget.style.transform = 'none'
                                      e.currentTarget.style.boxShadow = '0 1px 3px rgba(0,0,0,0.06)'
                                    }}
                                  >
                                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 2 }}>
                                      <Typography.Text strong style={{ fontSize: 12, color: '#262626' }}>
                                        {timeStr} · {customerName}
                                      </Typography.Text>
                                    </div>
                                    <div style={{ fontSize: 11, color: '#595959', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis', marginBottom: 2 }}>
                                      {serviceNames} · {appointmentDuration(apt)} phút
                                    </div>
                                    <Tag
                                      style={{
                                        fontSize: 10,
                                        lineHeight: '16px',
                                        padding: '0 4px',
                                        margin: 0,
                                        color: presentation.color,
                                        background: 'rgba(255,255,255,0.85)',
                                        borderColor: 'transparent',
                                      }}
                                    >
                                      {presentation.label}
                                    </Tag>
                                  </div>
                                )
                              })}
                            </div>
                          ) : null}
                          {canBook && (
                            <Tooltip title={`Tạo lịch dự kiến cho ${col.name} lúc ${hourFormatted}; ca làm và dịch vụ sẽ được kiểm tra khi lưu`}>
                              <div
                                onClick={() => onQuickBook?.(col.id ?? undefined, hour)}
                                style={{
                                  height: '100%',
                                  minHeight: 52,
                                  borderRadius: 4,
                                  display: 'flex',
                                  alignItems: 'center',
                                  justifyContent: 'center',
                                  cursor: 'pointer',
                                  color: 'transparent',
                                  transition: 'all 0.15s ease',
                                }}
                                onMouseEnter={(e) => {
                                  e.currentTarget.style.background = '#f9f5f6'
                                  e.currentTarget.style.color = '#8c4559'
                                }}
                                onMouseLeave={(e) => {
                                  e.currentTarget.style.background = 'transparent'
                                  e.currentTarget.style.color = 'transparent'
                                }}
                              >
                                <PlusOutlined style={{ fontSize: 16 }} />
                              </div>
                            </Tooltip>
                          )}
                        </td>
                      )
                    })}
                  </tr>
                )
              })}
            </tbody>
          </table>
        </div>
      )}
    </Card>
  )
}
