import { useQueryClient } from '@tanstack/react-query'
import { useEffect, useState } from 'react'
import { Alert, Button, Card, Form, Input, Modal, Space, Typography, message } from 'antd'
import { LockOutlined, MailOutlined, SafetyOutlined } from '@ant-design/icons'
import axios from 'axios'
import { useNavigate } from 'react-router-dom'
import { forgotPassword, login, resetPassword } from '../../api/auth'
import { saveAuthResponse } from '../../api/session'
import { isAuthResponse, isWebAccount } from '../../types/auth'
import { getApiErrorMessage } from '../../components/apiError'

interface LoginFields {
  email: string
  password: string
}
interface RecoveryFields {
  email: string
  otp: string
  newPassword: string
  confirmPassword: string
}

const forgotNotice = 'Nếu email thuộc tài khoản đang hoạt động, mã xác nhận sẽ được gửi đến email đó. Vui lòng kiểm tra hộp thư và thư rác.'

function getErrorMessage(error: unknown, fallback = 'Không thể đăng nhập. Vui lòng thử lại.'): string {
  if (axios.isAxiosError(error) && error.response?.status === 401) return 'Email hoặc mật khẩu không chính xác.'
  return getApiErrorMessage(error, fallback)
}

export default function LoginPage() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
  const [recoveryOpen, setRecoveryOpen] = useState(false)
  const [recoveryStep, setRecoveryStep] = useState<1 | 2>(1)
  const [recoveryEmail, setRecoveryEmail] = useState('')
  const [recoveryNotice, setRecoveryNotice] = useState('')
  const [recoveryError, setRecoveryError] = useState('')
  const [recoveryLoading, setRecoveryLoading] = useState(false)
  const [resendSeconds, setResendSeconds] = useState(0)
  const [recoveryForm] = Form.useForm<RecoveryFields>()

  useEffect(() => {
    if (!recoveryOpen || resendSeconds <= 0) return
    const timer = window.setTimeout(() => setResendSeconds((seconds) => Math.max(0, seconds - 1)), 1000)
    return () => window.clearTimeout(timer)
  }, [recoveryOpen, resendSeconds])

  function resetRecovery() {
    setRecoveryOpen(false)
    setRecoveryStep(1)
    setRecoveryEmail('')
    setRecoveryNotice('')
    setRecoveryError('')
    setRecoveryLoading(false)
    setResendSeconds(0)
    recoveryForm.resetFields()
  }

  async function sendOtp(emailValue?: string) {
    const email = (emailValue ?? recoveryForm.getFieldValue('email') ?? '').trim()
    try {
      await recoveryForm.validateFields(['email'])
      setRecoveryLoading(true)
      setRecoveryError('')
      await forgotPassword({ email })
      setRecoveryEmail(email)
      setRecoveryNotice(forgotNotice)
      setRecoveryStep(2)
      setResendSeconds(60)
    } catch (error: unknown) {
      if (axios.isAxiosError(error)) setRecoveryError(getErrorMessage(error, 'Không thể xử lý yêu cầu khôi phục mật khẩu. Vui lòng thử lại.'))
      else if (!(typeof error === 'object' && error !== null && 'errorFields' in error)) setRecoveryError(getErrorMessage(error, 'Không thể xử lý yêu cầu khôi phục mật khẩu. Vui lòng thử lại.'))
    } finally {
      setRecoveryLoading(false)
    }
  }

  async function submitRecovery(fields: RecoveryFields) {
    setRecoveryLoading(true)
    setRecoveryError('')
    try {
      await resetPassword({ email: recoveryEmail, otp: fields.otp, newPassword: fields.newPassword })
      message.success('Đặt lại mật khẩu thành công. Vui lòng đăng nhập bằng mật khẩu mới.')
      resetRecovery()
    } catch (error: unknown) {
      setRecoveryError(getErrorMessage(error, 'Không thể xử lý yêu cầu khôi phục mật khẩu. Vui lòng thử lại.'))
    } finally {
      setRecoveryLoading(false)
    }
  }

  async function handleSubmit(fields: LoginFields) {
    setLoading(true)
    setErrorMessage('')
    try {
      const response: unknown = await login(fields)
      if (!isAuthResponse(response)) throw new Error('Phản hồi đăng nhập không đúng định dạng.')
      if (!response.account) throw new Error('Phản hồi đăng nhập thiếu thông tin tài khoản.')
      if (!isWebAccount(response.account)) {
        message.info('Tài khoản này dùng cho ứng dụng di động')
        return
      }
      queryClient.clear()
      saveAuthResponse(response)
      navigate('/', { replace: true })
    } catch (error: unknown) {
      setErrorMessage(getErrorMessage(error))
    } finally {
      setLoading(false)
    }
  }

  return (
    <main className="login-page">
      <Card className="login-card" bordered={false}>
        <div className="sider-brand login-brand">
          <span className="brand-mark">
            <img className="brand-logo" src="/branding/logo.png" alt="Logo HealthBeauty Spa" width="40" height="40" />
          </span>
          <div className="brand-label">
            <span className="brand-title">HealthBeauty</span>
            <span className="brand-subtitle">Spa &amp; Clinic</span>
          </div>
        </div>
        <Typography.Title level={2}>Đăng nhập</Typography.Title>
        <Typography.Paragraph type="secondary">Đăng nhập vào hệ thống quản lý</Typography.Paragraph>
        {errorMessage && <Alert className="login-alert" type="error" showIcon message={errorMessage} />}
        <Form<LoginFields> layout="vertical" size="large" onFinish={handleSubmit} requiredMark={false}>
          <Form.Item name="email" label="Email" rules={[{ required: true, message: 'Vui lòng nhập email.' }, { type: 'email', message: 'Email không hợp lệ.' }]}>
            <Input prefix={<MailOutlined />} placeholder="Nhập email" autoComplete="username" />
          </Form.Item>
          <Form.Item name="password" label="Mật khẩu" rules={[{ required: true, message: 'Vui lòng nhập mật khẩu.' }]}>
            <Input.Password prefix={<LockOutlined />} placeholder="Nhập mật khẩu" autoComplete="current-password" />
          </Form.Item>
          <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: -16, marginBottom: 16 }}>
            <Button type="link" htmlType="button" style={{ paddingInline: 0 }} onClick={() => { setRecoveryError(''); setRecoveryOpen(true) }}>Quên mật khẩu?</Button>
          </div>
          <Button type="primary" htmlType="submit" block loading={loading}>Đăng nhập</Button>
        </Form>
      </Card>
      <Modal title="Khôi phục mật khẩu" open={recoveryOpen} onCancel={resetRecovery} footer={null} destroyOnClose>
        <Form<RecoveryFields> form={recoveryForm} layout="vertical" requiredMark={false} onFinish={(fields) => void submitRecovery(fields)}>
          {recoveryStep === 1 ? <>
            <Typography.Paragraph type="secondary">Nhập email tài khoản để nhận mã xác nhận đặt lại mật khẩu.</Typography.Paragraph>
            {recoveryError && <Alert type="error" showIcon message={recoveryError} style={{ marginBottom: 16 }} />}
            <Form.Item name="email" label="Email" rules={[{ required: true, message: 'Vui lòng nhập email.' }, { type: 'email', message: 'Email không hợp lệ.' }]}>
              <Input prefix={<MailOutlined />} placeholder="Nhập email" autoComplete="email" />
            </Form.Item>
            <Button type="primary" block loading={recoveryLoading} onClick={() => void sendOtp()}>Gửi mã xác nhận</Button>
          </> : <>
            {recoveryNotice && <Alert type="info" showIcon message={recoveryNotice} style={{ marginBottom: 16 }} />}
            <Typography.Paragraph>Email nhận mã: <Typography.Text strong>{recoveryEmail}</Typography.Text></Typography.Paragraph>
            {recoveryError && <Alert type="error" showIcon message={recoveryError} style={{ marginBottom: 16 }} />}
            <Form.Item name="otp" label="Mã xác nhận" rules={[{ required: true, message: 'Vui lòng nhập mã xác nhận.' }, { pattern: /^\d{6}$/, message: 'Mã xác nhận phải gồm đúng 6 chữ số.' }]}>
              <Input prefix={<SafetyOutlined />} maxLength={6} inputMode="numeric" autoComplete="one-time-code" placeholder="Nhập mã 6 chữ số" />
            </Form.Item>
            <Form.Item name="newPassword" label="Mật khẩu mới" rules={[{ required: true, message: 'Vui lòng nhập mật khẩu mới.' }, { min: 8, max: 128, message: 'Mật khẩu phải từ 8 đến 128 ký tự.' }]}>
              <Input.Password prefix={<LockOutlined />} autoComplete="new-password" placeholder="Nhập mật khẩu mới" />
            </Form.Item>
            <Form.Item name="confirmPassword" label="Xác nhận mật khẩu mới" dependencies={['newPassword']} rules={[{ required: true, message: 'Vui lòng xác nhận mật khẩu mới.' }, ({ getFieldValue }) => ({ validator(_, value: string | undefined) { return !value || getFieldValue('newPassword') === value ? Promise.resolve() : Promise.reject(new Error('Mật khẩu xác nhận không khớp.')) } })]}>
              <Input.Password prefix={<LockOutlined />} autoComplete="new-password" placeholder="Nhập lại mật khẩu mới" />
            </Form.Item>
            <Button type="primary" htmlType="submit" block loading={recoveryLoading}>Đặt lại mật khẩu</Button>
            <Space style={{ width: '100%', justifyContent: 'space-between', marginTop: 12 }} wrap>
              <Button type="link" onClick={() => { setRecoveryStep(1); setRecoveryError(''); recoveryForm.setFieldsValue({ email: recoveryEmail }) }}>Đổi email</Button>
              <Button type="link" disabled={resendSeconds > 0 || recoveryLoading} loading={recoveryLoading} onClick={() => { recoveryForm.setFieldsValue({ email: recoveryEmail }); void sendOtp() }}>{resendSeconds > 0 ? `Gửi lại mã OTP (${resendSeconds}s)` : 'Gửi lại mã OTP'}</Button>
            </Space>
          </>}
        </Form>
      </Modal>
    </main>
  )
}
