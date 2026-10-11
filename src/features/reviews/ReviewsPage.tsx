import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Col, Popconfirm, Rate, Row, Select, Space, Table, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs from 'dayjs'
import { getApiErrorMessage } from '../../components/apiError'
import { ACCOUNT_ROLES } from '../../constants/roles'
import { useAuth } from '../../hooks/useAuth'
import type { Review } from '../../types/reviews'
import { useReviewAppointments, useReviewCustomers, useReviewInvoices, useReviews, useReviewStaff, useSetReviewVisibility } from './reviewQueries'

interface ReviewRow extends Review { tenKhach: string; tenNhanVien: string }

export default function ReviewsPage() {
  const [rating, setRating] = useState<number | undefined>()
  const [customerSearch, setCustomerSearch] = useState('')
  const { message } = App.useApp()
  const role = useAuth()?.account?.role
  const canModerate = role === ACCOUNT_ROLES.ADMIN || role === ACCOUNT_ROLES.MANAGER
  const reviews = useReviews()
  const invoices = useReviewInvoices()
  const appointments = useReviewAppointments()
  const customers = useReviewCustomers()
  const staff = useReviewStaff()
  const visibility = useSetReviewVisibility()

  const rows = useMemo<ReviewRow[]>(() => {
    const invoiceMap = new Map((invoices.data ?? []).map((item) => [item.id, item]))
    const appointmentMap = new Map((appointments.data ?? []).map((item) => [item.id, item]))
    const customerMap = new Map((customers.data ?? []).map((item) => [item.id, item.fullName]))
    const staffMap = new Map((staff.data ?? []).map((item) => [item.nhanVienId || item.id, item.hoTen]))
    return (reviews.data ?? []).map((review) => {
      const invoice = invoiceMap.get(review.hoaDonId)
      const appointment = invoice ? appointmentMap.get(invoice.appointmentId) : undefined
      const customerId = invoice?.customerId ?? appointment?.customerId
      return { ...review, tenKhach: customerId === undefined ? '—' : customerMap.get(customerId) || '—', tenNhanVien: appointment?.staffId == null ? '—' : staffMap.get(appointment.staffId) || '—' }
    })
  }, [reviews.data, invoices.data, appointments.data, customers.data, staff.data])
  const filtered = rows.filter((review) => (rating === undefined || review.soSao === rating) && review.tenKhach.toLocaleLowerCase().includes(customerSearch.trim().toLocaleLowerCase()))
  const counts = [1, 2, 3, 4, 5].map((stars) => rows.filter((review) => review.soSao === stars).length)
  const average = rows.length ? rows.reduce((sum, review) => sum + review.soSao, 0) / rows.length : 0
  const hasError = reviews.isError || invoices.isError || appointments.isError || customers.isError || staff.isError

  async function moderate(record: ReviewRow, visible: boolean) {
    try {
      await visibility.mutateAsync({ id: record.danhGiaId, visible })
      message.success(visible ? 'Đã hiện đánh giá.' : 'Đã ẩn đánh giá.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể cập nhật hiển thị đánh giá.'))
    }
  }

  const columns: ColumnsType<ReviewRow> = [
    { title: 'Khách hàng', dataIndex: 'tenKhach', key: 'customer' },
    { title: 'Nhân viên', dataIndex: 'tenNhanVien', key: 'staff' },
    { title: 'Số sao', dataIndex: 'soSao', key: 'stars', render: (value: number) => <Rate disabled value={value} /> },
    { title: 'Bình luận', dataIndex: 'binhLuan', key: 'comment', render: (value: string | null) => value || '—' },
    { title: 'Ngày đánh giá', dataIndex: 'ngayDanhGia', key: 'date', render: (value: string) => value && dayjs(value).isValid() ? dayjs(value).format('DD/MM/YYYY HH:mm') : '—' },
    ...(canModerate ? [{ title: 'Thao tác', key: 'actions', render: (_value: unknown, record: ReviewRow) => <Space>
      <Popconfirm title="Ẩn đánh giá này?" okText="Ẩn" cancelText="Hủy" onConfirm={() => void moderate(record, false)}><Button loading={visibility.isPending}>Ẩn</Button></Popconfirm>
      <Popconfirm title="Hiện đánh giá này?" okText="Hiện" cancelText="Hủy" onConfirm={() => void moderate(record, true)}><Button loading={visibility.isPending}>Hiện</Button></Popconfirm>
    </Space> }] : []),
  ]

  return <section>
    <Space direction="vertical" size={16} style={{ display: 'flex' }}>
      <div><Typography.Title level={4} style={{ margin: 0 }}>Đánh giá</Typography.Title>
        <Typography.Text type="secondary">Trạng thái hiển thị chưa có trong dữ liệu trả về.</Typography.Text>
        {/* TODO: backend bổ sung trạng thái hiển thị để chọn đúng nút cho từng đánh giá. */}
      </div>
      {hasError && <Alert type="error" showIcon message="Không tải được đánh giá hoặc dữ liệu liên quan." description={getApiErrorMessage(reviews.error ?? invoices.error ?? appointments.error ?? customers.error ?? staff.error, 'Vui lòng thử lại sau.')} />}
      <Row gutter={[12, 12]}>
        <Col xs={24} sm={12} md={8}><Card size="small"><Typography.Text type="secondary">Điểm trung bình</Typography.Text><Typography.Title level={3} style={{ margin: 0 }}>{average.toFixed(1)} / 5</Typography.Title></Card></Col>
        {[1, 2, 3, 4, 5].map((stars) => <Col xs={12} sm={6} md={3} key={stars}><Card size="small"><Typography.Text>{stars} sao</Typography.Text><Typography.Title level={4} style={{ margin: 0 }}>{counts[stars - 1]}</Typography.Title></Card></Col>)}
      </Row>
      <Space wrap>
        <Select allowClear placeholder="Lọc theo số sao" value={rating} onChange={(value: number | undefined) => setRating(value)} options={[1, 2, 3, 4, 5].map((value) => ({ value, label: `${value} sao` }))} style={{ width: 170 }} />
        <input aria-label="Tìm theo tên khách" placeholder="Tìm theo tên khách" value={customerSearch} onChange={(event) => setCustomerSearch(event.target.value)} style={{ padding: '6px 10px', border: '1px solid #dedbd6', borderRadius: 4, font: 'inherit' }} />
      </Space>
      {reviews.isLoading ? <div role="status">Đang tải đánh giá…</div> : <Table<ReviewRow> rowKey="danhGiaId" columns={columns} dataSource={filtered} loading={reviews.isFetching} locale={{ emptyText: 'Chưa có đánh giá' }} pagination={{ pageSize: 10, showSizeChanger: true }} />}</Space></section>
}
