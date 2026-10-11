import { App as AntApp, Avatar, Button, Layout, Menu, Space, Typography } from 'antd'
import { AppstoreOutlined, CalendarOutlined, DashboardOutlined, LogoutOutlined, TagsOutlined, UserOutlined, TeamOutlined, ContactsOutlined, ClockCircleOutlined, DollarOutlined, StarOutlined } from '@ant-design/icons'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { clearSession, getRefreshToken } from '../api/session'
import api from '../api/client'
import { useAuth } from '../hooks/useAuth'
import type { RefreshRequest } from '../types/auth'

const { Header, Sider, Content } = Layout

export default function MainLayout() {
  const session = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const { message } = AntApp.useApp()

  async function handleLogout() {
    const refreshToken = getRefreshToken()
    try {
      if (refreshToken) {
        const body: RefreshRequest = { refreshToken }
        await api.post('/auth/logout', body)
      }
    } catch {
      message.warning('Không thể xác nhận thu hồi phiên trên máy chủ.')
    } finally {
      clearSession()
      navigate('/login', { replace: true })
    }
  }

  return (
    <Layout className="app-layout">
      <Sider breakpoint="lg" collapsedWidth="0" className="app-sider">
        <div className="sider-brand"><span className="brand-mark">S</span><span>SeoulSpa.Vn</span></div>
        <Menu theme="dark" mode="inline" selectedKeys={[location.pathname]} items={[
          { key: '/', icon: <DashboardOutlined />, label: 'Tổng quan' },
          { key: '/service-categories', icon: <TagsOutlined />, label: 'Loại dịch vụ' },
          { key: '/services', icon: <AppstoreOutlined />, label: 'Dịch vụ' },
          { key: '/combos', icon: <AppstoreOutlined />, label: 'Combo' },
          { key: '/appointments', icon: <CalendarOutlined />, label: 'Lịch hẹn' },
          { key: '/customers', icon: <ContactsOutlined />, label: 'Khách hàng' },
          { key: '/staff', icon: <TeamOutlined />, label: 'Nhân viên' },
          { key: '/staff-schedules', icon: <ClockCircleOutlined />, label: 'Lịch làm việc' },
          { key: '/billing', icon: <DollarOutlined />, label: 'Hóa đơn và thanh toán' },
          { key: '/promotions', icon: <TagsOutlined />, label: 'Khuyến mãi và voucher' },
          { key: '/reviews', icon: <StarOutlined />, label: 'Đánh giá' },
        ]} onClick={({ key }) => navigate(key)} />
      </Sider>
      <Layout>
        <Header className="app-header">
          <Typography.Title level={5}>Hệ thống quản lý</Typography.Title>
          <Space>
            <Avatar icon={<UserOutlined />} />
            <span className="account-name">{session?.account?.name || session?.account?.email || 'Tài khoản'}</span>
            <Button type="text" icon={<LogoutOutlined />} onClick={handleLogout}>Đăng xuất</Button>
          </Space>
        </Header>
        <Content className="app-content"><Outlet /></Content>
      </Layout>
    </Layout>
  )
}
