import { useState } from 'react'
import { App as AntApp, Alert, Avatar, Button, Drawer, Dropdown, Grid, Layout, Menu } from 'antd'
import { AppstoreOutlined, CalendarOutlined, DashboardOutlined, LogoutOutlined, TagsOutlined, UserOutlined, TeamOutlined, ContactsOutlined, ClockCircleOutlined, DollarOutlined, StarOutlined, SafetyCertificateOutlined, MenuOutlined, MenuFoldOutlined, MenuUnfoldOutlined, DownOutlined } from '@ant-design/icons'
import { Outlet, useLocation, useNavigate } from 'react-router-dom'
import { useQueryClient } from '@tanstack/react-query'
import { clearSession, getRefreshToken } from '../api/session'
import api from '../api/client'
import { useAuth } from '../hooks/useAuth'
import { usePermissions } from '../hooks/usePermissions'
import type { RefreshRequest } from '../types/auth'
import { REPORTS_ROUTE, REPORT_MENU_LABEL } from '../types/reports'

const { Header, Sider, Content } = Layout

export default function MainLayout() {
  const queryClient = useQueryClient()
  const session = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const { message } = AntApp.useApp()
  const access = usePermissions()
  const screens = Grid.useBreakpoint()
  const mobile = !screens.lg
  const [menuOpen, setMenuOpen] = useState(false)
  const [collapsed, setCollapsed] = useState(false)
  const menuItems = [
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
    { key: REPORTS_ROUTE, icon: <DashboardOutlined />, label: REPORT_MENU_LABEL },
    { key: '/audit-logs', icon: <ClockCircleOutlined />, label: 'Nhật ký hoạt động' },
    { key: '/accounts', icon: <UserOutlined />, label: 'Tài khoản' },
    { key: '/permissions', icon: <SafetyCertificateOutlined />, label: 'Phân quyền' },
  ].filter((item) => access.canVisit(item.key))

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
      queryClient.clear()
      navigate('/login', { replace: true })
    }
  }

  const accountName = session?.account?.name || session?.account?.email || 'Tài khoản'
  const pageTitle = menuItems.find((item) => item.key === location.pathname)?.label || 'Healthbeauty'
  const brand = <div className="sider-brand"><span className="brand-mark">H</span><span className="brand-label">Healthbeauty</span></div>
  const navigation = <Menu theme="dark" mode="inline" selectedKeys={[location.pathname]} items={menuItems} onClick={({ key }) => { setMenuOpen(false); navigate(key) }} />

  return (
    <Layout className="app-layout">
      {!mobile && <Sider width={248} collapsedWidth={80} collapsed={collapsed} trigger={null} className="app-sider">
        <div className="sider-inner">
          {brand}
          <nav className="sider-navigation" aria-label="Điều hướng chính">{navigation}</nav>
          <div className="sider-footer"><span className="status-dot" /><span className="brand-label">{session?.account?.role}</span></div>
        </div>
      </Sider>}
      <Drawer title={brand} placement="left" size="min(320px, calc(100vw - 32px))" open={mobile && menuOpen} onClose={() => setMenuOpen(false)} className="mobile-navigation" styles={{ body: { padding: 0 } }}>
        <nav aria-label="Điều hướng di động">{navigation}</nav>
      </Drawer>
      <Layout className="app-main">
        <Header className="app-header">
          <div className="header-heading">
            <Button type="text" className="menu-toggle" icon={mobile ? <MenuOutlined /> : collapsed ? <MenuUnfoldOutlined /> : <MenuFoldOutlined />} aria-label={mobile ? 'Mở menu' : collapsed ? 'Mở rộng menu' : 'Thu gọn menu'} aria-expanded={mobile ? menuOpen : !collapsed} onClick={() => mobile ? setMenuOpen(true) : setCollapsed((value) => !value)} />
            <span className="header-page-title">{pageTitle}</span>
          </div>
          <Dropdown trigger={['click']} menu={{ items: [{ key: 'account-summary', disabled: true, label: <div className="account-dropdown-summary"><strong>{accountName}</strong><span>{session?.account?.role}</span></div> }, { type: 'divider' }, { key: 'logout', icon: <LogoutOutlined />, label: 'Đăng xuất' }], onClick: ({ key }) => { if (key === 'logout') void handleLogout() } }} placement="bottomRight">
            <Button type="text" className="account-menu" aria-label={`Tài khoản: ${accountName}`}>
              <Avatar size={34} icon={<UserOutlined />} />
              <span className="account-name">{accountName}</span>
              <DownOutlined className="account-chevron" />
            </Button>
          </Dropdown>
        </Header>
        <Content className="app-content">
          <div className="content-inner">
            {access.isError && <Alert type="warning" showIcon message="Không tải được quyền truy cập" action={<Button onClick={() => { void access.refetch() }}>Thử lại</Button>} style={{ marginBottom: 16 }} />}
            <Outlet />
          </div>
        </Content>
      </Layout>
    </Layout>
  )
}
