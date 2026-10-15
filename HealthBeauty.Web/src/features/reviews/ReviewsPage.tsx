import { useEffect, useMemo, useState } from 'react'
import { Alert, App, Button, Card, Col, Form, Input, Modal, Rate, Row, Segmented, Select, Space, Table, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { SearchOutlined } from '@ant-design/icons'
import dayjs from 'dayjs'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Review } from '../../types/reviews'
import { useAllAppointments } from '../appointments/appointmentQueries'
import { usePendingReviews, useReviewCustomers, useReviewInvoices, useReviews, useReviewStaff, useSetReviewVisibility } from './reviewQueries'

interface ReviewRow extends Review { tenKhach: string; tenNhanVien: string }
const reviewRepliesKey = 'healthbeauty.reviewReplies'

export default function ReviewsPage() {
  const [view, setView] = useState<'HienThi' | 'ChoDuyet'>('ChoDuyet')
  const [rating, setRating] = useState<number | undefined>()
  const [customerSearch, setCustomerSearch] = useState('')
  const [replies, setReplies] = useState<Record<number, string>>({})
  const [replyingTo, setReplyingTo] = useState<ReviewRow | null>(null)
  const [replyForm] = Form.useForm<{ reply: string }>()
  const { message } = App.useApp()
  const { has } = usePermissions()
  const canModerate = has('REVIEW.MODERATE')
  const published = useReviews()
  const pending = usePendingReviews(canModerate)
  const reviews = canModerate && view === 'ChoDuyet' ? pending : published
  const invoices = useReviewInvoices(has('INVOICE.READ'))
  const appointments = useAllAppointments(has('APPOINTMENT.READ'))
  const customers = useReviewCustomers(has('CUSTOMER.READ'))
  const staff = useReviewStaff(has('STAFF.READ'))
  const visibility = useSetReviewVisibility()

  useEffect(() => {
    try {
      const stored = localStorage.getItem(reviewRepliesKey)
      if (stored) {
        const parsed: unknown = JSON.parse(stored)
        if (typeof parsed === 'object' && parsed !== null && !Array.isArray(parsed)) {
          const entries = Object.entries(parsed).filter((entry): entry is [string, string] => typeof entry[1] === 'string')
          setReplies(Object.fromEntries(entries.map(([id, text]) => [Number(id), text])))
        }
      }
    } catch {
      setReplies({})
    }
  }, [])

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

  function submitReply(values: { reply: string }) {
    if (!replyingTo) return
    const next = { ...replies, [replyingTo.danhGiaId]: values.reply.trim() }
    try {
      localStorage.setItem(reviewRepliesKey, JSON.stringify(next))
      setReplies(next)
      setReplyingTo(null)
      replyForm.resetFields()
      message.success('Đã gửi phản hồi đánh giá thành công!')
    } catch {
      message.error('Không thể lưu phản hồi trên trình duyệt này.')
    }
  }

  async function moderate(record: ReviewRow, visible: boolean) {
    if (!canModerate) return
    try {
      await visibility.mutateAsync({ id: record.danhGiaId, visible })
      message.success(visible ? 'Đã duyệt hiển thị đánh giá.' : 'Đã ẩn đánh giá.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể cập nhật hiển thị đánh giá.'))
    }
  }

  const columns: ColumnsType<ReviewRow> = [
    { title: 'STT', key: 'stt', width: 60, align: 'center', render: (_value, _record, index) => index + 1 },
    { title: 'Khách hàng', dataIndex: 'tenKhach', key: 'customer' },
    { title: 'Nhân viên', dataIndex: 'tenNhanVien', key: 'staff' },
    { title: 'Trạng thái', dataIndex: 'trangThai', key: 'status', render: (value: string) => <Tag color={value === 'ChoDuyet' ? 'gold' : 'green'}>{value === 'ChoDuyet' ? 'Chờ duyệt' : 'Đang hiển thị'}</Tag> },
    { title: 'Số sao', dataIndex: 'soSao', key: 'stars', render: (value: number) => <Rate disabled value={value} /> },
    { title: 'Bình luận', dataIndex: 'binhLuan', key: 'comment', render: (value: string | null, record: ReviewRow) => <Space direction="vertical" size={4}><span>{value || '—'}</span>{replies[record.danhGiaId] && <Typography.Text type="secondary">[Phản hồi từ Spa]: “{replies[record.danhGiaId]}”</Typography.Text>}</Space> },
    { title: 'Ngày đánh giá', dataIndex: 'ngayDanhGia', key: 'date', render: (value: string) => value && dayjs(value).isValid() ? dayjs(value).format('DD/MM/YYYY HH:mm') : '—' },
    ...(canModerate ? [{ title: 'Thao tác', key: 'actions', render: (_value: unknown, record: ReviewRow) => <Space>
      <Button loading={visibility.isPending} onClick={() => Modal.confirm({ title: 'Ẩn đánh giá này?', content: 'Đánh giá sẽ không còn hiển thị công khai.', okText: 'Ẩn', okType: 'danger', cancelText: 'Hủy', centered: true, onOk: () => moderate(record, false) })}>Ẩn</Button>
      {record.trangThai === 'ChoDuyet' && <Button type="primary" loading={visibility.isPending} onClick={() => Modal.confirm({ title: 'Duyệt hiển thị đánh giá này?', content: 'Đánh giá sẽ được hiển thị công khai.', okText: 'Duyệt', okType: 'danger', cancelText: 'Hủy', centered: true, onOk: () => moderate(record, true) })}>Duyệt</Button>}
      <Button onClick={() => { replyForm.setFieldsValue({ reply: replies[record.danhGiaId] ?? '' }); setReplyingTo(record) }}>Phản hồi</Button>
    </Space> }] : []),
  ]

  return <section>
    <Space direction="vertical" size={16} style={{ display: 'flex' }}>
      <div><Typography.Title level={4} style={{ margin: 0 }}>Đánh giá</Typography.Title>
        {canModerate && <Typography.Text type="secondary">Duyệt đánh giá mới trước khi hiển thị công khai.</Typography.Text>}
      </div>
      {hasError && <Alert type="error" showIcon message="Không tải được đánh giá hoặc dữ liệu liên quan." description={getApiErrorMessage(reviews.error ?? invoices.error ?? appointments.error ?? customers.error ?? staff.error, 'Vui lòng thử lại sau.')} />}
      <Row gutter={[12, 12]}>
        <Col xs={24} sm={12} md={8}><Card size="small"><Typography.Text type="secondary">Điểm trung bình</Typography.Text><Typography.Title level={3} style={{ margin: 0 }}>{average.toFixed(1)} / 5</Typography.Title></Card></Col>
        {[1, 2, 3, 4, 5].map((stars) => <Col xs={12} sm={6} md={3} key={stars}><Card size="small"><Typography.Text>{stars} sao</Typography.Text><Typography.Title level={4} style={{ margin: 0 }}>{counts[stars - 1]}</Typography.Title></Card></Col>)}
      </Row>
      <Space wrap size={10} align="center">
        {canModerate && <Segmented value={view} onChange={(value) => setView(value as 'HienThi' | 'ChoDuyet')} options={[{ label: `Chờ duyệt (${pending.data?.length ?? 0})`, value: 'ChoDuyet' }, { label: 'Đang hiển thị', value: 'HienThi' }]} />}
        <Input allowClear prefix={<SearchOutlined />} placeholder="Tìm theo tên khách" value={customerSearch} onChange={(event) => setCustomerSearch(event.target.value)} style={{ width: 240, maxWidth: '100%' }} />
        <Select allowClear placeholder="Lọc theo số sao" value={rating} onChange={(value: number | undefined) => setRating(value)} options={[1, 2, 3, 4, 5].map((value) => ({ value, label: `${value} sao` }))} style={{ width: 170, maxWidth: '100%' }} />
      </Space>
      {reviews.isLoading ? <div role="status">Đang tải đánh giá…</div> : <Table<ReviewRow> className="responsive-table" rowKey="danhGiaId" scroll={{ x: 'max-content' }} columns={columns} dataSource={filtered} loading={reviews.isFetching} locale={{ emptyText: 'Chưa có đánh giá' }} pagination={{ responsive: true, pageSize: 10, showSizeChanger: true }} />}</Space>
    <Modal className="responsive-modal" title={`Phản hồi đánh giá của khách hàng ${replyingTo?.tenKhach ?? ''}`} open={Boolean(replyingTo)} onCancel={() => { setReplyingTo(null); replyForm.resetFields() }} footer={null} destroyOnClose>
      {replyingTo && <>
        <Space direction="vertical" style={{ display: 'flex', marginBottom: 16 }}>
          <Typography.Text>Số sao của khách: <Rate disabled value={replyingTo.soSao} /></Typography.Text>
          <Typography.Text type="secondary">Bình luận: {replyingTo.binhLuan || 'Không có bình luận'}</Typography.Text>
        </Space>
        <Form form={replyForm} layout="vertical" onFinish={submitReply}>
          <Form.Item name="reply" label="Nội dung phản hồi của HealthBeauty Spa & Clinic" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập nội dung phản hồi.' }]}>
            <Input.TextArea rows={4} maxLength={2000} showCount placeholder="Dạ HealthBeauty cảm ơn quý khách đã tin tưởng và sử dụng dịch vụ..." />
          </Form.Item>
          <Space><Button type="primary" htmlType="submit">Gửi phản hồi</Button><Button onClick={() => { setReplyingTo(null); replyForm.resetFields() }}>Hủy</Button></Space>
        </Form>
      </>}
    </Modal>
    </section>
}
