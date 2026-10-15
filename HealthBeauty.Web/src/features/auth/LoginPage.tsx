import { useQueryClient } from '@tanstack/react-query'
import { useState } from 'react'
import { Alert, Button, Card, Form, Input, Typography, message } from 'antd'
import { LockOutlined, MailOutlined } from '@ant-design/icons'
import axios from 'axios'
import { useNavigate } from 'react-router-dom'
import { login } from '../../api/auth'
import { saveAuthResponse } from '../../api/session'
import { isAuthResponse, isWebAccount } from '../../types/auth'

interface LoginFields {
  email: string
  password: string
}

function getErrorMessage(error: unknown): string {
  if (axios.isAxiosError(error)) {
    const data: unknown = error.response?.data
    if (typeof data === 'object' && data !== null && 'message' in data && typeof data.message === 'string') {
      return data.message
    }
    if (error.response?.status === 401) return 'Email hoặc mật khẩu không chính xác.'
  }
  return 'Không thể đăng nhập. Vui lòng thử lại.'
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
            <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
              <path d="M12 2.5C12 2.5 10.5 7 10.5 10C10.5 12 11.2 13.5 12 13.5C12.8 13.5 13.5 12 13.5 10C13.5 7 12 2.5 12 2.5Z" />
              <path d="M9.8 14C8 13.2 5.5 11 4.5 7.5C4 11 5.8 15 9.2 16.5C9.5 15.5 9.7 14.7 9.8 14Z" opacity="0.85" />
              <path d="M14.2 14C16 13.2 18.5 11 19.5 7.5C20 11 18.2 15 14.8 16.5C14.5 15.5 14.3 14.7 14.2 14Z" opacity="0.85" />
              <path d="M12 18C7.5 18 4 19 2 21C6.5 21 17.5 21 22 21C20 19 16.5 18 12 18Z" opacity="0.9" />
            </svg>
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
