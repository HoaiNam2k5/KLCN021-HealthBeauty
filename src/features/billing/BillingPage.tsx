import { useMemo, useState } from 'react'
import { Alert, DatePicker, Empty, Input, Select, Space, Table, Tag, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import dayjs, { type Dayjs } from 'dayjs'
import type { Invoice } from '../../types/billing'
import { getApiErrorMessage } from '../../components/apiError'
import { useInvoices } from './billingQueries'

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`
const statusLabels: Record<string, string> = { ChuaThanhToan: 'Chưa thanh toán', DaThanhToan: 'Đã thanh toán' }

export default function BillingPage() {
  const invoices = useInvoices()
  const [keyword, setKeyword] = useState('')
  const [status, setStatus] = useState<string>()
  const [range, setRange] = useState<[Dayjs | null, Dayjs | null] | null>(null)

  const filtered = useMemo(() => (invoices.data ?? []).filter((invoice) => {
    const matchesCustomer = !keyword || String(invoice.customerId).includes(keyword.trim())
    const matchesStatus = !status || invoice.status === status
    const date = dayjs(invoice.createdAt)
    const matchesDate = !range || (!range[0] || !date.isBefore(range[0].startOf('day'))) && (!range[1] || !date.isAfter(range[1].endOf('day')))
    return matchesCustomer && matchesStatus && matchesDate
  }), [invoices.data, keyword, status, range])

  const columns: ColumnsType<Invoice> = [
    { title: 'Mã hóa đơn', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Mã lịch hẹn', dataIndex: 'appointmentId', key: 'appointmentId', render: (id: number) => `#${id}` },
    { title: 'Mã khách hàng', dataIndex: 'customerId', key: 'customerId', render: (id: number) => `#${id}` },
    { title: 'Ngày tạo', dataIndex: 'createdAt', key: 'createdAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Tạm tính', dataIndex: 'subtotal', key: 'subtotal', align: 'right', render: (value: number) => money(value) },
    { title: 'Tổng tiền', dataIndex: 'total', key: 'total', align: 'right', render: (value: number) => money(value) },
    { title: 'Thanh toán', dataIndex: 'status', key: 'status', render: (value: string) => <Tag color={value === 'DaThanhToan' ? 'success' : 'warning'}>{statusLabels[value] ?? value}</Tag> },
    { title: 'Phương thức', key: 'method', render: (_, invoice) => invoice.payments.length ? invoice.payments.map((payment) => payment.method).join(', ') : '—' },
  ]

  return <section>
    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16, flexWrap: 'wrap', marginBottom: 20 }}>
      <Typography.Title level={4} style={{ margin: 0 }}>Hóa đơn và thanh toán</Typography.Title>
      <Space wrap>
        <Input allowClear value={keyword} onChange={(event) => setKeyword(event.target.value)} placeholder="Tìm theo mã khách hàng" style={{ width: 220 }} />
        <Select allowClear value={status} onChange={setStatus} placeholder="Trạng thái thanh toán" style={{ width: 210 }} options={[{ value: 'ChuaThanhToan', label: 'Chưa thanh toán' }, { value: 'DaThanhToan', label: 'Đã thanh toán' }]} />
        <DatePicker.RangePicker value={range} onChange={(value) => setRange(value)} format="DD/MM/YYYY" />
      </Space>
    </div>
    {invoices.isError && <Alert type="error" showIcon message="Không tải được danh sách hóa đơn" description={getApiErrorMessage(invoices.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    <Table<Invoice>
      rowKey="id"
      columns={columns}
      dataSource={filtered}
      loading={invoices.isLoading}
      locale={{ emptyText: <Empty description={invoices.isError ? 'Không có dữ liệu để hiển thị' : 'Chưa có hóa đơn'} /> }}
      pagination={{ pageSize: 10, showSizeChanger: true, pageSizeOptions: [10, 20, 50], showTotal: (count) => `Tổng ${count} hóa đơn` }}
    />
  </section>
}
