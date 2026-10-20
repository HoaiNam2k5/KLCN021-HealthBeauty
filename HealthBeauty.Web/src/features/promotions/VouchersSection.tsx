import { useState } from 'react'
import { Alert, App, Button, DatePicker, Form, Input, InputNumber, Modal, Select, Space, Table, Tag, Typography } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Promotion, Voucher, VoucherRequest } from '../../types/promotions'
import { useCustomers } from '../customers-staff/customerStaffQueries'
import { useDeleteVoucher, useSaveVoucher, useSetVoucherStatus, useVouchers } from './promotionQueries'

interface VoucherFields { code: string; promotionId: number; customerId?: number; discountValue: number; expiresAt: Dayjs; pointsCost?: number }

export default function VouchersSection({ promotions, canManage }: { promotions: Promotion[]; canManage: boolean }) {
  const { message } = App.useApp()
  const [keyword, setKeyword] = useState('')
  const [statusFilter, setStatusFilter] = useState('all')
  const [editing, setEditing] = useState<Voucher | null>(null)
  const [open, setOpen] = useState(false)
  const [form] = Form.useForm<VoucherFields>()
  const pointsCost = Form.useWatch('pointsCost', form) ?? 0
  const voucherOwnershipLocked = Boolean(editing && (editing.customerId !== null || !editing.active))
  const query = useVouchers(keyword, statusFilter === 'all' ? undefined : statusFilter === 'active')
  const { has } = usePermissions()
  const customers = useCustomers('', has('CUSTOMER.READ'))
  const save = useSaveVoucher()
  const toggle = useSetVoucherStatus()
  const remove = useDeleteVoucher()
  const promotionOptions = promotions.map((item) => ({ value: item.id, label: item.name ?? `Khuyến mãi #${item.id}` }))
  if (editing && !promotionOptions.some((item) => item.value === editing.promotionId)) {
    promotionOptions.push({ value: editing.promotionId, label: editing.promotionName })
  }

  function openForm(voucher?: Voucher) {
    if (!canManage) return
    setEditing(voucher ?? null)
    form.resetFields()
    form.setFieldsValue(voucher ? { code: voucher.code, promotionId: voucher.promotionId, customerId: voucher.customerId ?? undefined,
      discountValue: voucher.discountValue, expiresAt: dayjs(voucher.expiresAt), pointsCost: voucher.pointsCost ?? 0 } : { code: '', discountValue: 0, pointsCost: 0, expiresAt: dayjs().add(7, 'day') })
    setOpen(true)
  }

  async function submit(values: VoucherFields) {
    if (!canManage) return
    const body: VoucherRequest = { code: values.code.trim().toUpperCase(), promotionId: values.promotionId, customerId: (values.pointsCost ?? 0) > 0 ? (editing?.customerId ?? null) : (values.customerId ?? null),
      discountValue: values.discountValue, expiresAt: values.expiresAt.format('YYYY-MM-DDTHH:mm:ss'), pointsCost: values.pointsCost ?? 0 }
    try {
      await save.mutateAsync({ id: editing?.id, body })
      message.success('Lưu voucher thành công.')
      setOpen(false)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể lưu voucher.')) }
  }

  async function changeStatus(voucher: Voucher) {
    if (!canManage) return
    try {
      await toggle.mutateAsync({ id: voucher.id, active: !voucher.active })
      message.success('Đã cập nhật trạng thái voucher.')
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể đổi trạng thái voucher.')) }
  }

  async function disable(voucher: Voucher) {
    if (!canManage) return
    try { await remove.mutateAsync(voucher.id); message.success('Đã ngừng sử dụng voucher.') }
    catch (error) { message.error(getApiErrorMessage(error, 'Không thể ngừng sử dụng voucher.')) }
  }

  return <section style={{ marginTop: 28 }}>
    <div className="page-heading">
      <Typography.Title level={4} style={{ margin: 0 }}>Voucher</Typography.Title>
      <Space wrap size={10} align="center">
        <Input allowClear prefix={<SearchOutlined />} value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Tìm mã, khuyến mãi hoặc khách hàng" style={{ width: 280, maxWidth: '100%' }} />
        <Select value={statusFilter} onChange={setStatusFilter} options={[{ value: 'all', label: 'Tất cả trạng thái' }, { value: 'active', label: 'Đang bật' }, { value: 'inactive', label: 'Đã tắt / đã dùng' }]} style={{ width: 180, maxWidth: '100%' }} />
        {canManage && <Button type="primary" onClick={() => openForm()}>Thêm voucher</Button>}
      </Space>
    </div>
    {query.isError && <Alert type="error" showIcon message="Không tải được danh sách voucher" description={getApiErrorMessage(query.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    <Table<Voucher> className="responsive-table" rowKey="id" dataSource={query.data ?? []} loading={query.isLoading} scroll={{ x: 'max-content' }} pagination={{ responsive: true, pageSize: 10, showSizeChanger: true }} columns={[
      { title: 'STT', key: 'stt', width: 65, align: 'center', render: (_value, _record, index) => index + 1 },
      { title: 'Mã', dataIndex: 'code' }, { title: 'Khuyến mãi', dataIndex: 'promotionName' },
      { title: 'Khách hàng', dataIndex: 'customerName', render: (name: string | null) => name ?? 'Tất cả khách hàng' },
      { title: 'Điểm đổi', dataIndex: 'pointsCost', key: 'pointsCost', render: (pts?: number) => (pts && pts > 0 ? <Tag color="purple">{pts.toLocaleString('vi-VN')} điểm</Tag> : <Tag>Tặng / Miễn phí</Tag>) },
      { title: 'Giá trị giảm tối đa', dataIndex: 'discountValue', render: (value: number) => `${value.toLocaleString('vi-VN')} ₫` },
      { title: 'Hạn sử dụng', dataIndex: 'expiresAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
      { title: 'Trạng thái', render: (_, voucher) => <Tag color={!voucher.active ? 'default' : dayjs(voucher.expiresAt).isBefore(dayjs()) ? 'warning' : 'success'}>{!voucher.active ? 'Đã tắt / đã dùng' : dayjs(voucher.expiresAt).isBefore(dayjs()) ? 'Hết hạn' : 'Đang bật'}</Tag> },
      ...(canManage ? [{ title: 'Thao tác', key: 'actions', render: (_: unknown, voucher: Voucher) => <Space>
        <Button type="link" onClick={() => openForm(voucher)}>Sửa</Button>
        <Button type="link" loading={toggle.isPending && toggle.variables?.id === voucher.id} onClick={() => void changeStatus(voucher)}>{voucher.active ? 'Tắt' : 'Bật'}</Button>
        {voucher.active && <Button type="link" danger onClick={() => Modal.confirm({ title: 'Ngừng sử dụng voucher?', content: 'Thông tin voucher sẽ được giữ lại.', okText: 'Ngừng sử dụng', okType: 'danger', cancelText: 'Hủy', centered: true, onOk: () => disable(voucher) })}>Ngừng sử dụng</Button>}
      </Space> }] : []),
    ]} />
    <Modal className="responsive-modal" title={editing ? 'Sửa voucher' : 'Thêm voucher'} open={open} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={(values) => void submit(values)}>
        <Form.Item name="code" label="Mã voucher" rules={[{ required: true, whitespace: true }, { max: 30 }]}><Input maxLength={30} /></Form.Item>
        <Form.Item name="promotionId" label="Khuyến mãi" rules={[{ required: true }]}><Select showSearch optionFilterProp="label" options={promotionOptions} /></Form.Item>
        <Form.Item name="pointsCost" label="Điểm cần đổi" extra="0 điểm = Voucher khuyến mãi tặng; > 0 điểm = Khách tự dùng điểm thưởng để đổi (phải để trống khách hàng)." rules={[{ type: 'number', min: 0, max: 1000000 }]}><InputNumber disabled={voucherOwnershipLocked} min={0} max={1000000} style={{ width: '100%' }} onChange={(value) => { if (Number(value ?? 0) > 0) form.setFieldValue('customerId', undefined) }} /></Form.Item>
        <Form.Item name="customerId" label="Khách hàng"><Select disabled={voucherOwnershipLocked || pointsCost > 0} allowClear showSearch optionFilterProp="label" loading={customers.isLoading} placeholder="Tất cả khách hàng" options={(customers.data ?? []).map((item) => ({ value: item.id, label: item.fullName ?? `Khách #${item.id}` }))} /></Form.Item>
        <Form.Item name="discountValue" label="Giá trị giảm tối đa" rules={[{ required: true }, { type: 'number', min: 0, max: 1000000000 }]}><InputNumber min={0} max={1000000000} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="expiresAt" label="Hạn sử dụng" rules={[{ required: true }, { validator: (_, value: Dayjs | undefined) => !value || value.isAfter(dayjs()) ? Promise.resolve() : Promise.reject(new Error('Hạn sử dụng phải ở tương lai.')) }]}><DatePicker showTime format="DD/MM/YYYY HH:mm" style={{ width: '100%' }} /></Form.Item>
        {customers.isError && <Alert type="warning" showIcon message="Không tải được danh sách khách hàng." />}
      </Form>
    </Modal>
  </section>
}
