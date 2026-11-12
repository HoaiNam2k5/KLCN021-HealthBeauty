import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Alert, Button, Card, Form, Input, Typography, message } from 'antd'
import { LockOutlined, MailOutlined } from '@ant-design/icons'
import axios from 'axios'
import { useNavigate } from 'react-router-dom'
import { login } from '../../api/auth'
import { saveAuthResponse } from '../../api/session'
import { isAuthResponse, isWebAccount } from '../../types/auth'
import { getApiErrorMessage } from '../../components/apiError'

interface LoginFields {
  email: string
  password: string
}
function getErrorMessage(error: unknown, fallback = 'Không thể đăng nhập. Vui lòng thử lại.'): string {
  if (axios.isAxiosError(error) && error.response?.status === 401) return 'Email hoặc mật khẩu không chính xác.'
  return getApiErrorMessage(error, fallback)
}

export default function LoginPage() {
  const queryClient = useQueryClient()
  const navigate = useNavigate()
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')
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
          <Button type="primary" htmlType="submit" block loading={loading}>Đăng nhập</Button>
        </Form>
      </Card>
    </main>
  )
}
