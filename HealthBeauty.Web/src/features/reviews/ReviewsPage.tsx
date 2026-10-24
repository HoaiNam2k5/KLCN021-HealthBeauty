import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Col, DatePicker, Form, Input, Modal, Rate, Row, Segmented, Select, Space, Table, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { DeleteOutlined, SearchOutlined } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { ReviewFilterParams, ReviewManagementItem } from '../../types/reviews'
import { useServices } from '../services/serviceQueries'
import { useDeleteReview, useManagementReviews, useReplyReview, useSetReviewVisibility } from './reviewQueries'

export default function ReviewsPage() {
  const [status, setStatus] = useState<ReviewFilterParams['status']>()
  const [rating, setRating] = useState<number>()
  const [serviceId, setServiceId] = useState<number>()
  const [dateRange, setDateRange] = useState<[Dayjs | null, Dayjs | null] | null>(null)
  const [customerSearch, setCustomerSearch] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [replyingTo, setReplyingTo] = useState<ReviewManagementItem | null>(null)
  const [replyForm] = Form.useForm<{ reply: string }>()
  const { message, modal } = App.useApp()
  const { has } = usePermissions()
  const canModerate = has('REVIEW.MODERATE')
  const services = useServices()
  const visibility = useSetReviewVisibility()
  const replyMutation = useReplyReview()
  const deleteMutation = useDeleteReview()
  const filterParams = useMemo<ReviewFilterParams>(() => ({ status, stars: rating, serviceId, page, pageSize, from: dateRange?.[0]?.startOf('day').format('YYYY-MM-DDTHH:mm:ss'), to: dateRange?.[1]?.endOf('day').format('YYYY-MM-DDTHH:mm:ss') }), [status, rating, serviceId, page, pageSize, dateRange])
  const managementQuery = useManagementReviews(filterParams, canModerate)
  const rows = managementQuery.data?.items ?? []
  const filtered = rows.filter((item) => (item.tenKhachHang ?? '').toLocaleLowerCase().includes(customerSearch.trim().toLocaleLowerCase()))

  function submitReply(values: { reply: string }) {
    if (!replyingTo) return
    replyMutation.mutate({ id: replyingTo.danhGiaId, reply: values.reply }, { onSuccess: () => { message.success('Phản hồi đã được lưu.'); setReplyingTo(null); replyForm.resetFields() }, onError: (error) => message.error(getApiErrorMessage(error, 'Không thể lưu phản hồi.')) })
  }
  function moderate(record: ReviewManagementItem, visible: boolean) {
    visibility.mutate({ id: record.danhGiaId, visible }, { onSuccess: () => message.success(visible ? 'Đã duyệt đánh giá.' : 'Đã ẩn đánh giá.'), onError: (error) => message.error(getApiErrorMessage(error, 'Không thể cập nhật trạng thái đánh giá.')) })
  }
  function confirmDelete(record: ReviewManagementItem) {
    modal.confirm({ title: 'Xóa đánh giá', content: 'Đánh giá sẽ được xóa mềm. Bạn có chắc chắn muốn tiếp tục?', okText: 'Xóa', okType: 'danger', cancelText: 'Hủy', onOk: () => deleteMutation.mutateAsync(record.danhGiaId).then(() => message.success('Đã xóa đánh giá.')).catch((error: unknown) => { message.error(getApiErrorMessage(error, 'Không thể xóa đánh giá.')); throw error }) })
  }

  const columns: ColumnsType<ReviewManagementItem> = [
    { title: 'STT', key: 'index', width: 70, render: (_value, _record, index) => (page - 1) * pageSize + index + 1 },
    { title: 'Khách hàng', dataIndex: 'tenKhachHang', render: (value: string | null) => value || '—' },
    { title: 'Dịch vụ/Combo', key: 'services', render: (_value, record) => record.services.map((service) => service.comboName || service.serviceName).filter(Boolean).join(', ') || '—' },
    { title: 'Số sao', dataIndex: 'soSao', render: (value: number) => <Rate disabled value={value} /> },
    { title: 'Bình luận & Phản hồi', key: 'comment', render: (_value, record) => <Space direction="vertical" size={4}><span>{record.binhLuan || 'Không có bình luận'}</span>{record.reply && <blockquote style={{ margin: 0, paddingLeft: 10, borderLeft: '2px solid #d9d9d9' }}><Typography.Text>[HealthBeauty Spa]: “{record.reply}”</Typography.Text><br /><Typography.Text type="secondary">{record.repliedAt ? dayjs(record.repliedAt).format('DD/MM/YYYY HH:mm') : ''}</Typography.Text></blockquote>}</Space> },
    { title: 'Ngày đánh giá', dataIndex: 'ngayDanhGia', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Trạng thái', dataIndex: 'trangThai', render: (value: ReviewManagementItem['trangThai']) => <Tag color={value === 'ChoDuyet' ? 'gold' : value === 'HienThi' ? 'green' : 'default'}>{value === 'ChoDuyet' ? 'Chờ duyệt' : value === 'HienThi' ? 'Đang hiển thị' : 'Đã ẩn'}</Tag> },
    ...(canModerate ? [{ title: 'Thao tác', key: 'actions', render: (_value: unknown, record: ReviewManagementItem) => <Space wrap>{record.trangThai !== 'HienThi' ? <Button size="small" onClick={() => moderate(record, true)}>{record.trangThai === 'ChoDuyet' ? 'Duyệt' : 'Hiện lại'}</Button> : <Button size="small" onClick={() => moderate(record, false)}>Ẩn</Button>}<Button size="small" onClick={() => { replyForm.setFieldsValue({ reply: record.reply ?? '' }); setReplyingTo(record) }}>{record.reply ? 'Sửa phản hồi' : 'Phản hồi'}</Button><Button size="small" danger icon={<DeleteOutlined />} onClick={() => confirmDelete(record)} /></Space> }] : []),
  ]

  return <section><Space direction="vertical" size={16} style={{ display: 'flex' }}>
    <div><Typography.Title level={4} style={{ margin: 0 }}>Đánh giá</Typography.Title>{canModerate && <Typography.Text type="secondary">Quản lý đánh giá dịch vụ và phản hồi khách hàng.</Typography.Text>}</div>
    {managementQuery.isError && <Alert type="error" showIcon message="Không tải được danh sách đánh giá." description={getApiErrorMessage(managementQuery.error, 'Vui lòng thử lại sau.')} />}
    <Row gutter={[12, 12]}><Col xs={24} sm={12}><Card size="small"><Typography.Text type="secondary">Điểm trung bình</Typography.Text><Typography.Title level={3} style={{ margin: 0 }}>{(managementQuery.data?.averageRating ?? 0).toFixed(1)} / 5 ⭐</Typography.Title></Card></Col><Col xs={24} sm={12}><Card size="small"><Typography.Text type="secondary">Tổng số đánh giá</Typography.Text><Typography.Title level={3} style={{ margin: 0 }}>{managementQuery.data?.totalCount ?? 0}</Typography.Title></Card></Col></Row>
    <Space wrap size={10} align="center">
      <Segmented value={status ?? 'all'} onChange={(value) => { setStatus(value === 'all' ? undefined : value as ReviewFilterParams['status']); setPage(1) }} options={[{ label: 'Tất cả', value: 'all' }, { label: 'Chờ duyệt', value: 'ChoDuyet' }, { label: 'Đang hiển thị', value: 'HienThi' }, { label: 'Đã ẩn', value: 'An' }]} />
      <Input allowClear prefix={<SearchOutlined />} placeholder="Tìm theo tên khách hàng" value={customerSearch} onChange={(event) => setCustomerSearch(event.target.value)} style={{ width: 240, maxWidth: '100%' }} />
      <Select allowClear placeholder="Lọc số sao" value={rating} onChange={(value: number | undefined) => { setRating(value); setPage(1) }} options={[1, 2, 3, 4, 5].map((value) => ({ value, label: `${value} sao` }))} style={{ width: 150 }} />
      <Select allowClear showSearch optionFilterProp="label" placeholder="Lọc theo dịch vụ" value={serviceId} onChange={(value: number | undefined) => { setServiceId(value); setPage(1) }} options={(services.data ?? []).map((service) => ({ value: service.id, label: service.name }))} style={{ width: 210 }} />
      <DatePicker.RangePicker value={dateRange} onChange={(value) => { setDateRange(value); setPage(1) }} format="DD/MM/YYYY" />
    </Space>
    <Table<ReviewManagementItem> className="responsive-table" rowKey="danhGiaId" scroll={{ x: 'max-content' }} columns={columns} dataSource={filtered} loading={managementQuery.isLoading || managementQuery.isFetching} locale={{ emptyText: 'Chưa có đánh giá' }} pagination={{ current: page, pageSize, total: managementQuery.data?.totalCount ?? 0, responsive: true, showSizeChanger: true, onChange: (nextPage, nextPageSize) => { setPage(nextPage); setPageSize(nextPageSize) } }} />
  </Space>
  <Modal className="responsive-modal" title={`Phản hồi đánh giá của khách hàng ${replyingTo?.tenKhachHang ?? ''}`} open={Boolean(replyingTo)} onCancel={() => { setReplyingTo(null); replyForm.resetFields() }} footer={null} destroyOnClose>
    {replyingTo && <><Space direction="vertical" style={{ display: 'flex', marginBottom: 16 }}><Typography.Text>Số sao của khách: <Rate disabled value={replyingTo.soSao} /></Typography.Text><Typography.Text type="secondary">Bình luận: {replyingTo.binhLuan || 'Không có bình luận'}</Typography.Text></Space><Form form={replyForm} layout="vertical" onFinish={submitReply}><Form.Item name="reply" label="Nội dung phản hồi của HealthBeauty Spa & Clinic" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập nội dung phản hồi.' }, { min: 1 }, { max: 2000 }]}><Input.TextArea rows={4} maxLength={2000} showCount placeholder="Nhập nội dung phản hồi..." /></Form.Item><Space><Button type="primary" htmlType="submit" loading={replyMutation.isPending}>Gửi phản hồi</Button><Button onClick={() => { setReplyingTo(null); replyForm.resetFields() }}>Hủy</Button></Space></Form></>}
  </Modal></section>
}
