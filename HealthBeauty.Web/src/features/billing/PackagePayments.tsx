import { useState } from 'react'
import { Alert, App, Button, Descriptions, Drawer, Input, Modal, Select, Space, Table, Tag } from 'antd'
import { DollarOutlined, EyeOutlined, ReloadOutlined, SearchOutlined } from '@ant-design/icons'
import { useQuery } from '@tanstack/react-query'
import dayjs from 'dayjs'
import { useSearchParams } from 'react-router-dom'
import { getPackagePayments, type PackagePaymentRow } from '../../api/servicePackages'
import { getSession } from '../../api/session'
import { ActionButton, ActionGrid } from '../../components/ActionButton'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import { usePayPackage, packageKeys } from '../service-packages/packageQueries'
import { PAYMENT_METHOD_LABELS } from './billingConstants'
import { canCollectPackagePayment, packagePaymentStatusLabel as stateLabel, parsePackagePurchaseId } from './packagePaymentSafety'

const money = (amount: number) => `${amount.toLocaleString('vi-VN')} ₫`

export default function PackagePayments() {
  const [params, setParams] = useSearchParams()
  const id = parsePackagePurchaseId(params.get('packageId'))
  const [page, setPage] = useState(1)
  const [search, setSearch] = useState('')
  const [status, setStatus] = useState<string>()
  const [selected, setSelected] = useState<number>()
  const [target, setTarget] = useState<PackagePaymentRow>()
  const [method, setMethod] = useState<'TienMat' | 'The'>('TienMat')
  const [checking, setChecking] = useState(false)
  const { has } = usePermissions()
  const { message } = App.useApp()
  const pay = usePayPackage()
  const filters = { page, pageSize: 20, search, status, id }
  const query = useQuery({ queryKey: [...packageKeys.all, 'payments', filters], queryFn: () => getPackagePayments(filters), refetchInterval: 5000 })
  const detail = useQuery({
    queryKey: [...packageKeys.all, 'payment-detail', selected],
    queryFn: () => getPackagePayments({ id: selected }),
    enabled: selected !== undefined,
    refetchInterval: 5000,
  })
  const row = detail.data?.items.find(item => item.id === selected)
  async function confirmPayment() {
    if (!target || checking || pay.isPending) return
    const session = getSession()
    setChecking(true)
    try {
      const latest = (await getPackagePayments({ id: target.id })).items[0]
      if (getSession() !== session) return
      if (!latest || latest.status !== 'Pending') {
        setTarget(undefined)
        await query.refetch()
        message.info('Phiếu đã được cập nhật. Không cần thu thêm tiền.')
        return
      }
      if (!canCollectPackagePayment(target, latest)) { setTarget(undefined); await query.refetch(); message.warning('Thông tin phiếu đã thay đổi. Vui lòng kiểm tra lại.'); return }
      await pay.mutateAsync({ id: latest.id, method })
      if (getSession() !== session) return
      setTarget(undefined)
      await query.refetch()
      message.success('Đã ghi nhận thanh toán và kích hoạt gói.')
    } catch (error) { message.error(getApiErrorMessage(error, 'Chưa ghi nhận được thanh toán. Vui lòng tải lại để kiểm tra.')) }
    finally { setChecking(false) }
  }
  return <>
    <Alert type="info" showIcon message="Khách chuyển khoản qua SePay: hệ thống tự ghi nhận và kích hoạt gói khi nhận được xác nhận. Không thu tiền lần nữa." style={{ marginBottom: 16 }} />
    <Space className="admin-filter-row" wrap>
      <Input className="admin-search" prefix={<SearchOutlined />} allowClear placeholder="Tìm khách hàng hoặc tên gói" value={search} onChange={event => { setSearch(event.target.value); setPage(1) }} />
      <Select allowClear placeholder="Trạng thái thanh toán" style={{ width: 200 }} value={status} onChange={value => { setStatus(value); setPage(1) }} options={['Pending', 'Paid', 'Cancelled'].map(value => ({ value, label: stateLabel(value) }))} />
      {id && <Button onClick={() => { const next = new URLSearchParams(params); next.delete('packageId'); setParams(next); setPage(1) }}>Xem tất cả phiếu mua</Button>}
      <Button icon={<ReloadOutlined />} loading={query.isFetching} onClick={() => void query.refetch()}>Làm mới</Button>
    </Space>
    {query.isError && <Alert type="error" showIcon message={getApiErrorMessage(query.error, 'Chưa tải được thanh toán gói dịch vụ.')} />}
    <Table<PackagePaymentRow> rowKey="id" loading={query.isLoading} dataSource={query.data?.items ?? []} pagination={{ current: page, pageSize: 20, total: query.data?.totalCount ?? 0, showSizeChanger: false, onChange: setPage }} columns={[
      { title: 'Phiếu mua', render: (_, item) => `#G${item.id}` },
      { title: 'Khách hàng', dataIndex: 'customerName' }, { title: 'Gói dịch vụ', dataIndex: 'name' },
      { title: 'Số tiền', dataIndex: 'price', render: money },
      { title: 'Trạng thái', dataIndex: 'status', render: value => <Tag color={value === 'Paid' ? 'green' : value === 'Pending' ? 'orange' : 'red'}>{stateLabel(value)}</Tag> },
      { title: 'Ngày thanh toán', dataIndex: 'paidAt', render: value => value ? dayjs(value).format('DD/MM/YYYY HH:mm') : '—' },
      { title: 'Phương thức', dataIndex: 'paymentMethod', render: value => value ? PAYMENT_METHOD_LABELS[value] ?? 'Phương thức khác' : '—' },
      { title: 'Thao tác', render: (_, item) => <ActionGrid><ActionButton label="Xem phiếu mua" icon={<EyeOutlined />} onClick={() => setSelected(item.id)} />{item.status === 'Pending' && has('PAYMENT.WRITE') && <ActionButton label="Thu tiền mặt hoặc thẻ tại quầy" tone="confirm" icon={<DollarOutlined />} onClick={() => { setMethod('TienMat'); setTarget(item) }} />}</ActionGrid> },
    ]} />
    <Drawer title="Phiếu thanh toán gói dịch vụ" open={selected !== undefined} onClose={() => setSelected(undefined)} width={560}>
      {detail.isError && <Alert type="error" showIcon message="Chưa tải được phiếu mua. Vui lòng thử lại." action={<Button onClick={() => void detail.refetch()}>Thử lại</Button>} />}
      {detail.isLoading && <p>Đang tải phiếu mua…</p>}
      {!detail.isLoading && !detail.isError && !row && <Alert type="info" message="Không tìm thấy phiếu mua." />}
      {row && <Descriptions column={1} bordered items={[
        { key: 'code', label: 'Mã phiếu', children: `#G${row.id}` }, { key: 'customer', label: 'Khách hàng', children: row.customerName },
        { key: 'name', label: 'Gói dịch vụ', children: row.name }, { key: 'price', label: 'Số tiền', children: money(row.price) },
        { key: 'status', label: 'Trạng thái', children: stateLabel(row.status) },
        { key: 'date', label: 'Ngày thanh toán', children: row.paidAt ? dayjs(row.paidAt).format('DD/MM/YYYY HH:mm') : '—' },
        { key: 'method', label: 'Phương thức', children: row.paymentMethod ? PAYMENT_METHOD_LABELS[row.paymentMethod] ?? 'Phương thức khác' : '—' },
      ]} />}
    </Drawer>
    <Modal title="Ghi nhận thanh toán tại quầy" open={!!target} onCancel={() => { if (!checking && !pay.isPending) setTarget(undefined) }} onOk={() => void confirmPayment()} confirmLoading={checking || pay.isPending} okText="Xác nhận đã thu tiền" cancelText="Đóng">
      <p>{target?.customerName} · {target?.name} · {target && money(target.price)}</p>
      <Select style={{ width: '100%' }} value={method} onChange={setMethod} options={[{ value: 'TienMat', label: 'Tiền mặt' }, { value: 'The', label: 'Thẻ' }]} />
    </Modal>
  </>
}
