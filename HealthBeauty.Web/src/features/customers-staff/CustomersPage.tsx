import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Descriptions, Drawer, Empty, Form, Input, Modal, Radio, Select, Space, Statistic, Table, Tabs, Tag, Typography } from 'antd'
import dayjs from 'dayjs'
import type { Appointment } from '../../types/appointments'
import type { Invoice } from '../../types/billing'
import { APPOINTMENT_STATUS, getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import { useAllAppointments } from '../appointments/appointmentQueries'
import { getPackageStatusLabel, getPointTransactionLabel } from '../../utils/displayLabels'
import { INVOICE_STATUS, INVOICE_STATUS_LABELS, PAYMENT_METHOD_LABELS } from '../billing/billingConstants'
import { useInvoices } from '../billing/billingQueries'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Customer, UpdateCustomerRequest } from '../../types/customersStaff'
import type { CreateCustomerInput } from '../../api/customersStaff'
import { useCreateCustomer, useCustomerPointHistory, useCustomers, useUpdateCustomer } from './customerStaffQueries'
import type { PointTransaction } from '../../api/customersStaff'
import { useCustomerPackages, usePayPackage, usePackagePurchaseDetail } from '../service-packages/packageQueries'
import type { CustomerPackage, PackagePaymentRequest, PackagePurchaseDetail } from '../../types/servicePackages'

function membership(points: number) {
  if (points >= 2000) return { label: 'Kim Cương', color: 'purple' }
  if (points >= 1000) return { label: 'Vàng', color: 'gold' }
  if (points >= 300) return { label: 'Bạc', color: 'blue' }
  return { label: 'Đồng', color: 'default' }
}

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

export default function CustomersPage() {
  const [selectedCustomer, setSelectedCustomer] = useState<Customer | null>(null)
  const [pointPage, setPointPage] = useState(1)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const [editing, setEditing] = useState<Customer | null>(null)
  const [creating, setCreating] = useState(false)
  const [form] = Form.useForm<UpdateCustomerRequest>()
  const [createForm] = Form.useForm<CreateCustomerInput>()
  const { message } = App.useApp()
  const { has } = usePermissions()
  const canEdit = has('CUSTOMER.WRITE')
  const query = useCustomers(keyword)
  const update = useUpdateCustomer()
  const createMutation = useCreateCustomer()
  const appointmentsQuery = useAllAppointments()
  const invoicesQuery = useInvoices()
  const pointsQuery = useCustomerPointHistory(selectedCustomer?.id ?? null, pointPage, 10, has('CUSTOMER.READ'))
  const customerPackagesQuery = useCustomerPackages(selectedCustomer?.id)
  const packagePay = usePayPackage()
  const [detailId, setDetailId] = useState<number>()
  const packageDetail = usePackagePurchaseDetail(detailId)
  const [payTarget, setPayTarget] = useState<CustomerPackage | null>(null)
  const [packagePayMethod, setPackagePayMethod] = useState<PackagePaymentRequest['method']>('TienMat')
  const paySelectedPackage = async () => { if (!payTarget) return; try { await packagePay.mutateAsync({ id: payTarget.id, method: packagePayMethod }); message.success('Thu tiền và kích hoạt gói thành công.'); setPayTarget(null) } catch (error) { message.error(getApiErrorMessage(error, 'Không thể thu tiền gói.')) } }
  const detail: PackagePurchaseDetail | undefined = packageDetail.data
  const customerAppointments = useMemo(() => (appointmentsQuery.data ?? []).filter((item: Appointment) => item.customerId === selectedCustomer?.id).sort((a, b) => dayjs(b.appointmentAt).valueOf() - dayjs(a.appointmentAt).valueOf()), [appointmentsQuery.data, selectedCustomer?.id])
  const customerInvoices = useMemo(() => (invoicesQuery.data ?? []).filter((item: Invoice) => item.customerId === selectedCustomer?.id).sort((a, b) => dayjs(b.createdAt).valueOf() - dayjs(a.createdAt).valueOf()), [invoicesQuery.data, selectedCustomer?.id])
  const spent = customerInvoices.filter((invoice) => invoice.status === INVOICE_STATUS.PAID).reduce((total, invoice) => total + invoice.total, 0)
  const appointmentColumns = [
    { title: 'Mã lịch', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Ngày thực hiện', dataIndex: 'appointmentAt', key: 'appointmentAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Dịch vụ / Combo', dataIndex: 'items', key: 'items', render: (items: Appointment['items']) => items.map((item) => item.comboId ? `Combo: ${item.serviceName}` : item.serviceName).join(', ') || '—' },
    { title: 'Trạng thái', dataIndex: 'status', key: 'status', render: (status: string) => { const presentation = getAppointmentStatusPresentation(status); return <Tag style={{ color: presentation.color, background: presentation.background, borderColor: 'transparent' }}>{presentation.label}</Tag> } },
  ]
  const invoiceColumns = [
    { title: 'Mã HĐ', dataIndex: 'id', key: 'id', render: (id: number) => `#${id}` },
    { title: 'Ngày lập', dataIndex: 'createdAt', key: 'createdAt', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Tạm tính', dataIndex: 'subtotal', key: 'subtotal', render: (value: number) => money(value) },
    { title: 'Tổng tiền', dataIndex: 'total', key: 'total', render: (value: number) => money(value) },
    { title: 'Thanh toán', dataIndex: 'status', key: 'status', render: (status: string) => <Tag color={status === INVOICE_STATUS.PAID ? 'success' : 'warning'}>{INVOICE_STATUS_LABELS[status] ?? 'Trạng thái chưa xác định'}</Tag> },
  ]
  const pointColumns = [
    { title: 'Ngày giao dịch', dataIndex: 'ngayGiaoDich', key: 'ngayGiaoDich', render: (value: string) => dayjs(value).format('DD/MM/YYYY HH:mm') },
    { title: 'Thay đổi điểm', dataIndex: 'soDiem', key: 'soDiem', render: (value: number) => value > 0 ? <Tag color="success">+{value.toLocaleString('vi-VN')}</Tag> : value < 0 ? <Tag color="error">{value.toLocaleString('vi-VN')}</Tag> : <Tag>0</Tag> },
    { title: 'Loại giao dịch', dataIndex: 'loaiGiaoDich', key: 'loaiGiaoDich', render: getPointTransactionLabel },
    { title: 'Ghi chú', dataIndex: 'ghiChu', key: 'ghiChu', render: (value: string | null) => value || '—' },
    { title: 'Mã HĐ liên quan', dataIndex: 'hoaDonId', key: 'hoaDonId', render: (value: number | null) => value ? `#${value}` : '—' },
    { title: 'Mã Voucher liên quan', dataIndex: 'voucherId', key: 'voucherId', render: (value: number | null) => value ? `#${value}` : '—' },
  ]
  const historyTabs = selectedCustomer ? [
    { key: 'overview', label: 'Tổng quan', children: <Space direction="vertical" size="middle" style={{ width: '100%' }}><Card><Descriptions column={2} title={selectedCustomer.fullName || 'Hồ sơ khách hàng'}><Descriptions.Item label="Số điện thoại">{selectedCustomer.phone || '—'}</Descriptions.Item><Descriptions.Item label="Giới tính">{selectedCustomer.gender || '—'}</Descriptions.Item><Descriptions.Item label="Hạng thành viên"><Tag color={membership(selectedCustomer.rewardPoints).color} style={{ fontSize: 16, padding: '4px 12px' }}>{membership(selectedCustomer.rewardPoints).label}</Tag></Descriptions.Item><Descriptions.Item label="Điểm thưởng">{selectedCustomer.rewardPoints.toLocaleString('vi-VN')}</Descriptions.Item></Descriptions></Card><Space wrap style={{ width: '100%' }}><Card><Statistic title="Tổng lịch hẹn" value={customerAppointments.length} /></Card><Card><Statistic title="Đã hoàn thành" value={customerAppointments.filter((item) => item.status === APPOINTMENT_STATUS.COMPLETED).length} /></Card><Card><Statistic title="Tổng chi tiêu" value={money(spent)} /></Card></Space></Space> },
    { key: 'appointments', label: 'Lịch sử Lịch hẹn', children: customerAppointments.length ? <Table<Appointment> rowKey="id" size="small" scroll={{ x: 'max-content' }} pagination={{ pageSize: 5 }} dataSource={customerAppointments} columns={appointmentColumns} /> : <Empty description="Chưa có lịch sử" /> },
    { key: 'invoices', label: 'Lịch sử Hóa đơn', children: customerInvoices.length ? <Table<Invoice> rowKey="id" size="small" scroll={{ x: 'max-content' }} pagination={{ pageSize: 5 }} dataSource={customerInvoices} columns={invoiceColumns} /> : <Empty description="Chưa có lịch sử" /> },
    { key: 'packages', label: 'Gói dịch vụ đã mua', children: <Space direction="vertical" style={{width:'100%'}}>{customerPackagesQuery.isLoading&&<Typography.Text>Đang tải gói...</Typography.Text>}{(customerPackagesQuery.data??[]).map((pkg:CustomerPackage)=><Card key={pkg.id} size="small" title={<Space>{pkg.name}{pkg.status==='Pending'?<Tag color="orange">Chờ thu tiền</Tag>:pkg.status==='Cancelled'?<Tag>Đã hủy</Tag>:<Tag color={pkg.expiresAt&&dayjs(pkg.expiresAt).isBefore(dayjs())?'red':'green'}>{pkg.expiresAt&&dayjs(pkg.expiresAt).isBefore(dayjs())?'Hết hạn':'Đã thanh toán'}</Tag>}</Space>} extra={<Space><Button type="link" onClick={()=>setDetailId(pkg.id)}>Lịch sử sử dụng</Button>{pkg.status==='Pending'&&has('PAYMENT.WRITE')&&<Button type="primary" size="small" onClick={()=>{setPackagePayMethod('TienMat');setPayTarget(pkg)}}>Thu tiền & Kích hoạt</Button>}</Space>}><Table rowKey="id" size="small" pagination={false} dataSource={pkg.items} columns={[{title:'Dịch vụ',dataIndex:'serviceName'},{title:'Được cấp',dataIndex:'granted'},{title:'Đã dùng',dataIndex:'used'},{title:'Đang giữ',dataIndex:'reserved'},{title:'Khả dụng',dataIndex:'available'}]}/></Card>)}</Space> },
    { key: 'points', label: 'Lịch sử Điểm thưởng', children: <><Space style={{ marginBottom: 12 }}><Typography.Text strong>Điểm thưởng hiện tại:</Typography.Text><Typography.Text>{(pointsQuery.data?.diemThuong ?? selectedCustomer.rewardPoints).toLocaleString('vi-VN')}</Typography.Text></Space><Table<PointTransaction> rowKey="giaoDichId" size="small" scroll={{ x: 'max-content' }} loading={pointsQuery.isLoading} dataSource={pointsQuery.data?.transactions ?? []} columns={pointColumns} pagination={{ current: pointPage, pageSize: 10, total: pointsQuery.data?.totalCount ?? 0, showSizeChanger: false, onChange: (nextPage) => setPointPage(nextPage) }} /></> },
  ] : []

  function edit(customer: Customer) {
    if (!canEdit) return
    form.setFieldsValue({ fullName: customer.fullName ?? '', phone: customer.phone, gender: customer.gender })
    setEditing(customer)
  }

  async function submit(body: UpdateCustomerRequest) {
    if (!canEdit || !editing) return
    try {
      await update.mutateAsync({ id: editing.id, body })
      message.success('Cập nhật khách hàng thành công.')
      setEditing(null)
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể cập nhật khách hàng.')) }
  }

  async function submitCreate(body: CreateCustomerInput) {
    if (!canEdit) return
    try {
      await createMutation.mutateAsync(body)
      message.success('Thêm khách hàng mới thành công.')
      setCreating(false)
      createForm.resetFields()
    } catch (error) { message.error(getApiErrorMessage(error, 'Không thể thêm khách hàng mới.')) }
  }

  return <>
    {query.isError && <Alert type="error" showIcon message="Không tải được danh sách khách hàng" description={getApiErrorMessage(query.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    <ManagementTable<Customer>
      title="Khách hàng"
      columns={[
        { title: 'Họ tên', dataIndex: 'fullName', key: 'fullName', render: (value: string | null) => value || '—' },
        { title: 'Số điện thoại', dataIndex: 'phone', key: 'phone', render: (value: string | null) => value || '—' },
        { title: 'Giới tính', dataIndex: 'gender', key: 'gender', render: (value: string | null) => value || '—' },
        { title: 'Điểm thưởng', dataIndex: 'rewardPoints', key: 'rewardPoints', render: (value: number) => value.toLocaleString('vi-VN') },
        { title: 'Hạng thành viên', key: 'membership', render: (_: unknown, customer: Customer) => <Tag color={membership(customer.rewardPoints).color}>{membership(customer.rewardPoints).label}</Tag> },
        { title: 'Thao tác', key: 'actions', render: (_: unknown, customer: Customer) => <Space><Button type="link" onClick={() => { setPointPage(1); setSelectedCustomer(customer) }}>Lịch sử</Button>{canEdit && <Button type="link" onClick={() => edit(customer)}>Sửa</Button>}</Space> },
      ]}
      data={query.data ?? []} searchFields={['fullName', 'phone']} loading={query.isLoading} error={query.isError}
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên hoặc số điện thoại"
      canManage={false} onEdit={edit} onDelete={() => undefined}
      toolbar={canEdit && <Button type="primary" onClick={() => setCreating(true)}>Thêm khách hàng</Button>}
    />
    <Modal className="responsive-modal" title="Thêm khách hàng mới" open={creating && canEdit} onCancel={() => { setCreating(false); createForm.resetFields() }} onOk={() => createForm.submit()} confirmLoading={createMutation.isPending} okText="Tạo khách hàng" cancelText="Hủy">
      <Form className="responsive-form" form={createForm} layout="vertical" onFinish={(body) => void submitCreate(body)}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập họ tên.' }]}><Input /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ required: true, message: 'Vui lòng nhập số điện thoại.' }, { pattern: /^\\+?[0-9][0-9\\s().-]*$/, message: 'Số điện thoại không hợp lệ.' }]}><Input /></Form.Item>
        <Form.Item name="gender" label="Giới tính"><Select allowClear options={[{ value: 'Nam', label: 'Nam' }, { value: 'Nữ', label: 'Nữ' }, { value: 'Khác', label: 'Khác' }]} /></Form.Item>
        <Form.Item name="email" label="Email"><Input type="email" placeholder="Ví dụ: khachhang@gmail.com (để trống sẽ tự tạo)" /></Form.Item>
      </Form>
    </Modal>
    <Drawer title="Hồ sơ & Lịch sử khách hàng" open={selectedCustomer !== null} onClose={() => setSelectedCustomer(null)} width={680} size="large">
      {selectedCustomer && <Tabs items={historyTabs} />}
    </Drawer>
    <Modal title="Chi tiết phiếu mua & lịch sử sử dụng gói" open={detailId!==undefined} onCancel={()=>setDetailId(undefined)} footer={null} width={760} loading={packageDetail.isLoading}>{detail&&<Space direction="vertical" size="large" style={{width:'100%'}}><section><Typography.Title level={5}>Thông tin phiếu mua</Typography.Title><Descriptions bordered size="small" column={2}><Descriptions.Item label="Mã phiếu">#{detail.package.id}</Descriptions.Item><Descriptions.Item label="Tên gói">{detail.package.name}</Descriptions.Item><Descriptions.Item label="Giá tiền">{money(detail.package.price)}</Descriptions.Item><Descriptions.Item label="Trạng thái">{detail.package.status==='Paid'&&detail.package.expiresAt&&dayjs(detail.package.expiresAt).isBefore(dayjs())?<Tag color="red">Hết hạn</Tag>:<Tag color={detail.package.status==='Paid'?'green':'orange'}>{getPackageStatusLabel(detail.package.status)}</Tag>}</Descriptions.Item><Descriptions.Item label="Hạn dùng">{detail.package.expiresAt?dayjs(detail.package.expiresAt).format('DD/MM/YYYY HH:mm'):'—'}</Descriptions.Item><Descriptions.Item label="Phương thức">{detail.package.paymentMethod ? PAYMENT_METHOD_LABELS[detail.package.paymentMethod] ?? 'Phương thức khác' : '—'}</Descriptions.Item><Descriptions.Item label="Ngày thanh toán">{detail.package.paidAt?dayjs(detail.package.paidAt).format('DD/MM/YYYY HH:mm'):'—'}</Descriptions.Item></Descriptions></section><section><Typography.Title level={5}>Dịch vụ và số lượt</Typography.Title><Table size="small" rowKey="id" pagination={false} dataSource={detail.package.items} columns={[{title:'Dịch vụ',dataIndex:'serviceName'},{title:'Được cấp',dataIndex:'granted'},{title:'Đang giữ',dataIndex:'reserved'},{title:'Đã dùng',dataIndex:'used'},{title:'Khả dụng',dataIndex:'available'}]}/></section><section><Typography.Title level={5}>Lịch sử giao dịch lượt</Typography.Title><Table size="small" rowKey="id" pagination={{pageSize:5}} dataSource={detail.history} columns={[{title:'Mã lịch hẹn',render:(_:unknown,h:typeof detail.history[number])=>`#${h.appointmentId}`},{title:'Dịch vụ',render:(_:unknown,h:typeof detail.history[number])=>detail.package.items.find(i=>i.id===h.customerPackageItemId)?.serviceName??'—'},{title:'Số lượt',dataIndex:'quantity'},{title:'Trạng thái',dataIndex:'status',render:(status:string)=>status==='Reserved'?<Tag color="orange">Giữ chỗ</Tag>:status==='Consumed'?<Tag color="green">Đã thực hiện</Tag>:<Tag color="default">Hoàn trả</Tag>},{title:'Ngày giao dịch',dataIndex:'createdAt',render:(date:string)=>dayjs(date).format('DD/MM/YYYY HH:mm')}]}/></section></Space>}</Modal><Modal title="Thu tiền & Kích hoạt gói dịch vụ" open={payTarget!==null} onCancel={()=>setPayTarget(null)} onOk={()=>void paySelectedPackage()} confirmLoading={packagePay.isPending} okText="Xác nhận thu tiền" cancelText="Để sau">{payTarget&&<Space direction="vertical" style={{width:'100%'}}><Typography.Paragraph>Khách hàng: <strong>{payTarget.customerName??selectedCustomer?.fullName??`#${payTarget.customerId}`}</strong> — Gói: <strong>{payTarget.name}</strong></Typography.Paragraph><Typography.Paragraph>Số tiền thu: <strong style={{color:'#2F7D4F'}}>{money(payTarget.price)}</strong></Typography.Paragraph><Typography.Paragraph type="secondary">Điểm thưởng tích lũy cho khách: +{Math.floor(payTarget.price/10000)} điểm</Typography.Paragraph><Form.Item label="Phương thức thanh toán"><Radio.Group value={packagePayMethod} onChange={e=>setPackagePayMethod(e.target.value)}><Radio value="TienMat">Tiền mặt</Radio><Radio value="ChuyenKhoan">Chuyển khoản</Radio><Radio value="The">Thẻ</Radio></Radio.Group></Form.Item></Space>}</Modal>
    <Modal className="responsive-modal" title="Sửa khách hàng" open={editing !== null && canEdit} onCancel={() => setEditing(null)} onOk={() => form.submit()} confirmLoading={update.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={(body) => void submit(body)}>
        <Form.Item name="fullName" label="Họ tên" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập họ tên.' }, { max: 100 }]}><Input maxLength={100} /></Form.Item>
        <Form.Item name="phone" label="Số điện thoại" rules={[{ max: 15 }, { pattern: /^\+?[0-9][0-9\s().-]*$/, message: 'Số điện thoại không hợp lệ.' }]}><Input maxLength={15} /></Form.Item>
        <Form.Item name="gender" label="Giới tính"><Select allowClear options={[{ value: 'Nam', label: 'Nam' }, { value: 'Nữ', label: 'Nữ' }, { value: 'Khác', label: 'Khác' }]} /></Form.Item>
      </Form>
    </Modal>
  </>
}
