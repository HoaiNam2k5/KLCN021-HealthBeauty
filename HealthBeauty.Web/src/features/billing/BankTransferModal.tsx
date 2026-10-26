import { useEffect, useRef } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Alert, App, Button, Card, Descriptions, Modal, Result, Space, Spin, Tag, Typography } from 'antd'
import { CopyOutlined, PrinterOutlined, QrcodeOutlined, ReloadOutlined } from '@ant-design/icons'
import { getBankTransferInstructions, getInvoice } from '../../api/billing'
import { getApiErrorMessage } from '../../components/apiError'
import type { Invoice } from '../../types/billing'
import { INVOICE_STATUS } from './billingConstants'
import { useAuth } from '../../hooks/useAuth'
import { getSession } from '../../api/session'
import { matchesPayableInvoice } from './transferSafety'

interface BankTransferModalProps {
  open: boolean
  invoiceId: number | null
  onClose: () => void
  onPaymentSuccess?: (invoice: Invoice) => void
  onPrintReceipt?: (invoice: Invoice) => void
  canPayCash?: boolean
  onCash?: (invoice: Invoice) => void
}

const money = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

export default function BankTransferModal(props: BankTransferModalProps) {
  const session = useAuth()
  if (!props.open || props.invoiceId === null || !session?.account) return null
  return <TransferSession key={`${session.account.id}:${props.invoiceId}`} {...props} invoiceId={props.invoiceId} />
}

function TransferSession({
  invoiceId,
  onClose,
  onPaymentSuccess,
  onPrintReceipt,
  canPayCash = false,
  onCash,
}: BankTransferModalProps & { invoiceId: number }) {
  const { message } = App.useApp()
  const session = useAuth()
  const accountId = session?.account?.id
  const invoice = useQuery({
    queryKey: ['bank-transfer-invoice', accountId, invoiceId],
    queryFn: async ({ signal }) => {
      const latest = await getInvoice(invoiceId, signal)
      signal.throwIfAborted()
      if (latest.id !== invoiceId) throw new Error('Hóa đơn trả về không khớp yêu cầu.')
      return latest
    },
    enabled: accountId !== undefined,
    refetchInterval: query => query.state.data?.status === INVOICE_STATUS.PAID ? false : 3000,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: 'always', refetchOnMount: 'always', retry: false,
  })
  // A cache entry is not sufficient: every modal opening requires a successful
  // current read. Query keys isolate both invoice and authenticated account.
  const current = invoice.isFetchedAfterMount && !invoice.isError ? invoice.data : undefined
  const transfer = useQuery({
    queryKey: ['bank-transfer-instructions', accountId, invoiceId, current?.total],
    queryFn: async ({ signal }) => {
      const latest = await getBankTransferInstructions(invoiceId, signal)
      signal.throwIfAborted()
      return latest
    },
    enabled: accountId !== undefined && current?.status === INVOICE_STATUS.UNPAID && current.total > 0,
    refetchOnWindowFocus: 'always', refetchOnMount: 'always', retry: false,
  })
  const instructions = !invoice.isError && !transfer.isError && matchesPayableInvoice(current, transfer.data) ? transfer.data : null
  const paidInvoice = current?.status === INVOICE_STATUS.PAID ? current : null
  const loading = invoice.isPending || (current?.status === INVOICE_STATUS.UNPAID && transfer.isPending)
  const error = invoice.isError ? getApiErrorMessage(invoice.error, 'Không cập nhật được trạng thái hóa đơn. Mã QR đã được ẩn; vui lòng thử lại.')
    : transfer.isError ? getApiErrorMessage(transfer.error, 'Không tải được mã chuyển khoản. Vui lòng thử lại.') : null
  const notified = useRef(false)
  useEffect(() => {
    if (!paidInvoice || notified.current || !session || getSession() !== session) return
    notified.current = true
    onPaymentSuccess?.(paidInvoice)
  }, [paidInvoice, onPaymentSuccess, session])

  const reload = () => {
    void invoice.refetch()
    void transfer.refetch()
  }

  const copyToClipboard = async (text: string, label: string) => {
    try {
      await navigator.clipboard.writeText(text)
      message.success(`Đã sao chép ${label}`)
    } catch {
      message.error(`Không thể tự động sao chép. Vui lòng copy thủ công: ${text}`)
    }
  }

  const handlePrint = () => {
    if (paidInvoice && onPrintReceipt && session && getSession() === session) {
      onPrintReceipt(paidInvoice)
      onClose()
    }
  }

  return (
    <Modal
      className="responsive-modal"
      open
      title={
        <Space>
          <QrcodeOutlined style={{ color: '#8c4559' }} />
          <span>Thanh toán chuyển khoản SePay (VietQR)</span>
        </Space>
      }
      onCancel={onClose}
      footer={
        paidInvoice ? (
          <Space style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <Button onClick={onClose}>Đóng</Button>
            <Button type="primary" icon={<PrinterOutlined />} onClick={handlePrint}>
              In phiếu thanh toán ngay
            </Button>
          </Space>
        ) : (
          <Space style={{ display: 'flex', justifyContent: 'flex-end' }}>
            <Button onClick={onClose}>Để thanh toán sau</Button>
            {canPayCash && onCash && current?.status === INVOICE_STATUS.UNPAID && (
              <Button onClick={() => { if (session && getSession() === session) onCash(current) }}>Thu tiền mặt / thẻ</Button>
            )}
            {invoiceId && (
              <Button icon={<ReloadOutlined />} onClick={reload} loading={loading || invoice.isFetching || transfer.isFetching}>
                Tải lại mã
              </Button>
            )}
          </Space>
        )
      }
      width={680}
      destroyOnClose
    >
      {loading && !instructions && (
        <div style={{ padding: '40px 0', textAlign: 'center' }}>
          <Spin tip="Đang tạo mã VietQR SePay…" />
        </div>
      )}

      {error && (
        <Alert
          type="warning"
          showIcon
          message="Không thể thanh toán chuyển khoản"
          description={error}
          style={{ marginBottom: 16 }}
        />
      )}

      {paidInvoice && (
        <Result
          status="success"
          title="Hóa đơn đã được thanh toán"
          subTitle={`Hóa đơn #${paidInvoice.id} · Tổng tiền ${money(paidInvoice.total)}. Phương thức thu tiền được ghi nhận trên phiếu thanh toán.`}
          extra={[
            <Button type="primary" key="print" icon={<PrinterOutlined />} onClick={handlePrint}>
              In phiếu thanh toán
            </Button>,
            <Button key="close" onClick={onClose}>
              Đóng cửa sổ
            </Button>,
          ]}
        />
      )}

      {!loading && !error && !paidInvoice && !instructions && (
        <Alert type="warning" showIcon message="Hóa đơn hoặc số tiền đã thay đổi. Mã QR cũ đã được ẩn."
          description="Kiểm tra lại hóa đơn và tải mã mới trước khi khách chuyển khoản."
          action={<Button onClick={reload}>Cập nhật</Button>} />
      )}

      {!paidInvoice && instructions && (
        <div>
          <div
            style={{
              display: 'flex',
              flexDirection: 'row',
              flexWrap: 'wrap',
              gap: 24,
              alignItems: 'center',
              justifyContent: 'center',
              marginBottom: 16,
            }}
          >
            {/* QR Card */}
            <div style={{ textAlign: 'center', flexShrink: 0 }}>
              <Card
                size="small"
                style={{
                  padding: 8,
                  borderRadius: 12,
                  boxShadow: '0 4px 16px rgba(0,0,0,0.08)',
                  border: '1px solid #e8e0d9',
                  display: 'inline-block',
                }}
              >
                <img
                  src={instructions.qrImageUrl}
                  alt="VietQR SePay"
                  style={{
                    width: 220,
                    height: 220,
                    objectFit: 'contain',
                    display: 'block',
                    borderRadius: 8,
                  }}
                />
                <div style={{ marginTop: 8 }}>
                  <Tag color="volcano" style={{ fontWeight: 600 }}>VietQR Napas 24/7</Tag>
                </div>
              </Card>
            </div>

            {/* Transfer Details */}
            <div style={{ flex: 1, minWidth: 260 }}>
              <Descriptions column={1} bordered size="small" style={{ marginBottom: 12 }}>
                <Descriptions.Item label="Ngân hàng">
                  <strong>{instructions.bankName}</strong> ({instructions.bankCode})
                </Descriptions.Item>
                <Descriptions.Item label="Số tài khoản">
                  <Space>
                    <Typography.Text copyable={false} strong style={{ fontSize: 15, color: '#1677ff' }}>
                      {instructions.accountNumber}
                    </Typography.Text>
                    <Button
                      size="small"
                      icon={<CopyOutlined />}
                      onClick={() => copyToClipboard(instructions.accountNumber, 'Số tài khoản')}
                    >
                      Chép
                    </Button>
                  </Space>
                </Descriptions.Item>
                <Descriptions.Item label="Chủ tài khoản">
                  <strong>{instructions.accountName}</strong>
                </Descriptions.Item>
                <Descriptions.Item label="Số tiền cần chuyển">
                  <span style={{ fontSize: 17, fontWeight: 700, color: '#2F7D4F' }}>
                    {money(instructions.amount)}
                  </span>
                </Descriptions.Item>
                <Descriptions.Item label="Nội dung CK">
                  <Space>
                    <Tag color="magenta" style={{ fontSize: 13, padding: '2px 8px', fontWeight: 700 }}>
                      {instructions.transferContent}
                    </Tag>
                    <Button
                      size="small"
                      icon={<CopyOutlined />}
                      onClick={() => copyToClipboard(instructions.transferContent, 'Nội dung chuyển khoản')}
                    >
                      Chép
                    </Button>
                  </Space>
                </Descriptions.Item>
              </Descriptions>
            </div>
          </div>

          <Alert
            type="info"
            showIcon
            message={
              <span>
                Vui lòng <b>chuyển đúng số tiền</b> và <b>giữ nguyên nội dung chuyển khoản</b>. Hệ thống tự động ghi nhận ngay khi tiền vào tài khoản.
              </span>
            }
          />

          <div
            style={{
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              gap: 8,
              marginTop: 16,
              color: '#8c4559',
              fontSize: 13,
            }}
          >
            <Spin size="small" />
            <span>Đang chờ nhận thông báo giao dịch từ SePay…</span>
          </div>
        </div>
      )}
    </Modal>
  )
}
