import { useEffect } from 'react'
import { Alert, Button, Descriptions, Image, Modal, Result, Space, Spin, Typography } from 'antd'
import { useQuery, useQueryClient } from '@tanstack/react-query'
import * as billingApi from '../../api/billing'
import type { Invoice } from '../../types/billing'
import { getApiErrorMessage } from '../../components/apiError'
import { useAuth } from '../../hooks/useAuth'
import { matchesPayableInvoice } from './transferPresentation'

const money = (value: number) => `${new Intl.NumberFormat('vi-VN').format(value)} ₫`

export default function InvoiceCollection({ invoiceId, customerName, canPayCash, onClose, onCash, onPrint }: {
  invoiceId: number; customerName: string; canPayCash: boolean
  onClose: () => void; onCash: () => void; onPrint: (invoice: Invoice) => void
}) {
  const accountId = useAuth()?.account?.id
  const client = useQueryClient()
  const invoice = useQuery({
    queryKey: ['collection-invoice', accountId, invoiceId],
    queryFn: () => billingApi.getInvoice(invoiceId), enabled: accountId !== undefined,
    refetchInterval: 5000, refetchIntervalInBackground: false, refetchOnWindowFocus: 'always',
    refetchOnMount: 'always', retry: 1,
  })
  const current = invoice.data
  const transfer = useQuery({
    queryKey: ['collection-transfer', accountId, invoiceId, current?.total],
    queryFn: () => billingApi.getInvoiceBankTransfer(invoiceId),
    enabled: accountId !== undefined && !invoice.isError && current?.status === 'ChuaThanhToan' && current.total > 0,
    retry: false, staleTime: 0, refetchOnMount: 'always', refetchOnWindowFocus: 'always',
  })
  useEffect(() => {
    if (current?.status !== 'DaThanhToan') return
    client.setQueryData<Invoice[]>(['invoices'], rows => rows?.map(row => row.id === current.id ? current : row))
    client.setQueryData(['invoices', 'detail', current.id], current)
    void Promise.all(['invoices', 'customers', 'appointment-customers', 'appointments', 'reports'].map(key => client.invalidateQueries({ queryKey: [key] })))
  }, [client, current])
  const ready = !invoice.isError && !transfer.isError && matchesPayableInvoice(current, transfer.data)
  return <Modal title={`Thu tiền hóa đơn #${invoiceId}`} open width={740} onCancel={onClose} footer={null} destroyOnClose>
    {invoice.isPending ? <Spin /> : invoice.isError ? <Alert type="error" showIcon message={getApiErrorMessage(invoice.error, 'Không cập nhật được trạng thái hóa đơn.')} action={<Button onClick={() => void invoice.refetch()}>Thử lại</Button>} /> : current?.status === 'DaThanhToan' ?
      <Result status="success" title="Thanh toán thành công" subTitle={`${customerName} — ${money(current.total)}`} extra={<Space><Button onClick={onClose}>Đóng</Button><Button type="primary" onClick={() => onPrint(current)}>In hóa đơn</Button></Space>} /> : current?.status !== 'ChuaThanhToan' || current.total <= 0 ?
      <Alert type="info" message="Hóa đơn này không yêu cầu chuyển khoản." /> : <>
        <Typography.Title level={3} style={{ textAlign: 'center' }}>{customerName}</Typography.Title>
        <Typography.Title level={2} style={{ textAlign: 'center', marginTop: 0 }}>{money(current.total)}</Typography.Title>
        <Typography.Paragraph>{current.items.map(item => `${item.serviceName ?? item.comboName ?? 'Dịch vụ'} × ${item.quantity}`).join(' · ')}</Typography.Paragraph>
        {transfer.isPending ? <div style={{ textAlign: 'center' }}><Spin /></div> : transfer.isError ? <Alert type="warning" showIcon message={getApiErrorMessage(transfer.error, 'Chưa tải được mã chuyển khoản.')} action={<Button onClick={() => void transfer.refetch()}>Thử lại</Button>} /> : ready && transfer.data ? <>
          <div style={{ textAlign: 'center', marginBottom: 16 }}><Image src={transfer.data.qrImageUrl} width={320} preview={false} alt={`Mã QR thanh toán hóa đơn ${invoiceId}`} /></div>
          <Descriptions column={1} bordered size="small">
            <Descriptions.Item label="Ngân hàng">{transfer.data.bankName}</Descriptions.Item>
            <Descriptions.Item label="Số tài khoản">{transfer.data.accountNumber}</Descriptions.Item>
            <Descriptions.Item label="Chủ tài khoản">{transfer.data.accountName}</Descriptions.Item>
            <Descriptions.Item label="Nội dung chuyển khoản"><Typography.Text copyable>{transfer.data.transferContent}</Typography.Text></Descriptions.Item>
          </Descriptions>
          <Alert style={{ marginTop: 16 }} type="info" showIcon message="Khách mở ứng dụng ngân hàng để quét mã trên màn hình này." description="Hệ thống tự cập nhật khi nhận xác nhận giao dịch. Không cần bấm xác nhận đã chuyển tiền." />
        </> : <Alert type="warning" message="Số tiền hoặc trạng thái vừa thay đổi. Vui lòng cập nhật mã QR." action={<Button onClick={() => { void invoice.refetch(); void transfer.refetch() }}>Cập nhật</Button>} />}
        <Space wrap style={{ marginTop: 20 }}>
          <Button onClick={onClose}>Để thanh toán sau</Button>
          {canPayCash && <Button onClick={onCash}>Thu tiền mặt / thẻ</Button>}
          <Button loading={invoice.isFetching} onClick={() => void invoice.refetch()}>Kiểm tra thanh toán</Button>
        </Space>
      </>}
  </Modal>
}
