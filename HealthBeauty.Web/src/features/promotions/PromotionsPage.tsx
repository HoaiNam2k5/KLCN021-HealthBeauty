import { useState } from 'react'
import { Alert, App, Button, DatePicker, Form, Input, InputNumber, Modal, Select, Space, Tag } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Promotion, PromotionRequest } from '../../types/promotions'
import { DISCOUNT_TYPE_OPTIONS, isValidPromotionPeriod, promotionStatus } from '../../types/promotions'
import { useDeletePromotion, usePromotions, useSavePromotion } from './promotionQueries'
import VouchersSection from './VouchersSection'

interface PromotionFormValues {
  name: string
  discountType: string
  discount: number
  condition?: string
  period?: [Dayjs | null, Dayjs | null] | null
}

const displayDate = (value: string | null) => value ? dayjs(value).format('DD/MM/YYYY HH:mm') : '—'

export default function PromotionsPage() {
  const [form] = Form.useForm<PromotionFormValues>()
  const discountType = Form.useWatch('discountType', form)
  const [editing, setEditing] = useState<Promotion | null>(null)
  const [open, setOpen] = useState(false)
  const [statusFilter, setStatusFilter] = useState('all')
  const [keyword, setKeyword] = useState('')
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const { message } = App.useApp()
  const { has } = usePermissions()
  const canManage = has('PROMOTION.WRITE')
  const query = usePromotions()
  const save = useSavePromotion()
  const remove = useDeletePromotion()
  const filtered = (query.data ?? []).filter((item) => (statusFilter === 'all' || promotionStatus(item) === statusFilter) && (item.name ?? '').toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase()))

  function openForm(record?: Promotion) {
    if (!canManage) return
    setEditing(record ?? null)
    form.setFieldsValue(record ? {
      name: record.name ?? '', discountType: record.discountType ?? 'PhanTram', discount: record.discount,
      condition: record.condition ?? '', period: [record.startsAt ? dayjs(record.startsAt) : null, record.endsAt ? dayjs(record.endsAt) : null],
    } : { name: '', discountType: 'PhanTram', discount: 0, condition: '', period: [dayjs(), dayjs().add(1, 'day')] })
    setOpen(true)
  }

  async function submit(values: PromotionFormValues) {
    if (!canManage) return
    const [startsAt, endsAt] = values.period ?? [null, null]
    if (startsAt && endsAt && !isValidPromotionPeriod(startsAt.toISOString(), endsAt.toISOString())) {
      form.setFields([{ name: 'period', errors: ['Thời điểm kết thúc phải sau thời điểm bắt đầu.'] }])
      return
    }
    const body: PromotionRequest = {
      name: values.name, discountType: values.discountType, discount: values.discount,
      condition: values.condition?.trim() || null, startsAt: startsAt?.format('YYYY-MM-DDTHH:mm:ss') ?? null, endsAt: endsAt?.format('YYYY-MM-DDTHH:mm:ss') ?? null,
    }
    try {
      await save.mutateAsync({ id: editing?.id, body })
      message.success(editing ? 'Cập nhật khuyến mãi thành công.' : 'Thêm khuyến mãi thành công.')
      setOpen(false)
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể lưu khuyến mãi.'))
    }
  }

  async function deletePromotion(record: Promotion) {
    if (!canManage) return
    try {
      await remove.mutateAsync(record.id)
      message.success('Xóa khuyến mãi thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa khuyến mãi.'))
      throw error
    }
  }

  return <>
    <ManagementTable<Promotion>
      title="Khuyến mãi"
      columns={[
        { title: 'Tên khuyến mãi', dataIndex: 'name', key: 'name', render: (value: string | null) => value || '—' },
        { title: 'Loại giảm', dataIndex: 'discountType', key: 'discountType', render: (value: string | null) => value === 'PhanTram' ? 'Phần trăm' : value === 'SoTien' ? 'Số tiền' : '—' },
        { title: 'Mức giảm', dataIndex: 'discount', key: 'discount', render: (value: number, record) => record.discountType === 'PhanTram' ? `${value}%` : `${new Intl.NumberFormat('vi-VN').format(value)} ₫` },
        { title: 'Điều kiện', dataIndex: 'condition', key: 'condition', render: (value: string | null) => value || '—' },
        { title: 'Bắt đầu', dataIndex: 'startsAt', key: 'startsAt', render: displayDate },
        { title: 'Kết thúc', dataIndex: 'endsAt', key: 'endsAt', render: displayDate },
        { title: 'Trạng thái', key: 'status', render: (_, record) => {
          const value = promotionStatus(record)
          return <Tag color={value === 'active' ? 'green' : value === 'upcoming' ? 'blue' : 'default'}>{value === 'active' ? 'Đang diễn ra' : value === 'upcoming' ? 'Sắp diễn ra' : 'Hết hạn'}</Tag>
        } },
      ]}
      data={filtered} searchFields={[]} loading={query.isLoading} error={query.isError}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên khuyến mãi"
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      canManage={canManage} onEdit={openForm} onDelete={deletePromotion}
      onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      toolbar={<Space wrap size={10} align="center">
        <Select aria-label="Lọc trạng thái khuyến mãi" value={statusFilter} onChange={(value) => { setStatusFilter(value); setPage(1) }} options={[{ value: 'all', label: 'Tất cả trạng thái' }, { value: 'active', label: 'Đang diễn ra' }, { value: 'upcoming', label: 'Sắp diễn ra' }, { value: 'expired', label: 'Hết hạn' }]} style={{ width: 180, maxWidth: '100%' }} />
        {canManage && <Button type="primary" onClick={() => openForm()}>Thêm khuyến mãi</Button>}
      </Space>}
    />
    {query.isError && <Alert type="error" showIcon message="Không tải được danh sách khuyến mãi" description={getApiErrorMessage(query.error, 'Vui lòng thử lại sau.')} style={{ marginTop: 16 }} />}
    {canManage && <VouchersSection promotions={query.data ?? []} canManage={canManage} />}
    <Modal className="responsive-modal" title={editing ? 'Sửa khuyến mãi' : 'Thêm khuyến mãi'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={(values) => void submit(values)}>
        <Form.Item name="name" label="Tên khuyến mãi" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên khuyến mãi.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="discountType" label="Loại giảm" rules={[{ required: true }]}><Select options={DISCOUNT_TYPE_OPTIONS} /></Form.Item>
        <Form.Item name="discount" label="Mức giảm" rules={[{ required: true, message: 'Vui lòng nhập mức giảm.' }, { type: 'number', min: 0, max: discountType === 'PhanTram' ? 100 : 1000000000 }]}><InputNumber min={0} max={discountType === 'PhanTram' ? 100 : 1000000000} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="condition" label="Điều kiện áp dụng"><Input.TextArea rows={3} maxLength={1000} /></Form.Item>
        <Form.Item name="period" label="Thời gian hiệu lực"><DatePicker.RangePicker allowEmpty={[true, true]} showTime format="DD/MM/YYYY HH:mm" style={{ width: '100%' }} /></Form.Item>
      </Form>
    </Modal>
  </>
}
