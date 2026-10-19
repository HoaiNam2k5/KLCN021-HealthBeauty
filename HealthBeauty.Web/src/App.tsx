import { lazy, Suspense, useEffect, useState } from 'react'
import { App as AntApp, Button, Result, Spin } from 'antd'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import viVN from 'antd/locale/vi_VN'
import dayjs from 'dayjs'
import 'dayjs/locale/vi'
import theme from './theme/theme'
import { refreshSession } from './api/client'
import { getRefreshToken, getSession } from './api/session'
import { useAuth } from './hooks/useAuth'
import LoginPage from './features/auth/LoginPage'
import MainLayout from './layouts/MainLayout'
import ProtectedRoute from './routes/ProtectedRoute'

const ServiceCategoriesPage = lazy(() => import('./features/services/ServiceCategoriesPage'))
const ServicesPage = lazy(() => import('./features/services/ServicesPage'))
const CombosPage = lazy(() => import('./features/services/CombosPage'))
const AppointmentsPage = lazy(() => import('./features/appointments/AppointmentsPage'))
const CustomersPage = lazy(() => import('./features/customers-staff/CustomersPage'))
const StaffPage = lazy(() => import('./features/customers-staff/StaffPage'))
const WorkSchedulesPage = lazy(() => import('./features/staff-schedules/WorkSchedulesPage'))
const BillingPage = lazy(() => import('./features/billing/BillingPage'))
const PromotionsPage = lazy(() => import('./features/promotions/PromotionsPage'))
const ReviewsPage = lazy(() => import('./features/reviews/ReviewsPage'))
const ReportsPage = lazy(() => import('./features/reports/ReportsPage'))
const AuditLogsPage = lazy(() => import('./features/audit-logs/AuditLogsPage'))
const AccountsPage = lazy(() => import('./features/accounts/AccountsPage'))
const PermissionsPage = lazy(() => import('./features/permissions/PermissionsPage'))

dayjs.locale('vi')

const queryClient = new QueryClient()
const pageTitles: Record<string, string> = {
  '/': 'Tổng quan',
  '/service-categories': 'Loại dịch vụ',
  '/services': 'Dịch vụ',
  '/combos': 'Combo',
  '/appointments': 'Lịch hẹn',
  '/customers': 'Khách hàng',
  '/staff': 'Nhân viên',
  '/staff-schedules': 'Lịch làm việc',
  '/billing': 'Hóa đơn và thanh toán',
  '/promotions': 'Khuyến mãi và voucher',
  '/reviews': 'Đánh giá',
  '/reports': 'Báo cáo',
  '/audit-logs': 'Nhật ký hoạt động',
  '/accounts': 'Tài khoản người dùng',
  '/permissions': 'Phân quyền',
  '/login': 'Đăng nhập',
}

function RouteTitle() {
  const location = useLocation()
  useEffect(() => {
    document.title = `${pageTitles[location.pathname] ?? 'Không tìm thấy trang'} | Healthbeauty`
  }, [location.pathname])
  return null
}

function CenteredSpinner() {
  return <div className="route-loading"><Spin size="large" /></div>
}

function ForbiddenPage() {
  return <Result status="403" title="403" subTitle="Bạn không có quyền truy cập trang này." extra={<Button type="primary" href="/">Về trang chủ</Button>} />
}

function NotFoundPage() {
  return <Result status="404" title="404" subTitle="Không tìm thấy trang bạn yêu cầu." extra={<Button type="primary" href="/">Về trang chủ</Button>} />
}

function HomePage() {
  return <ReportsPage home />
}

function ApplicationRoutes() {
  const session = useAuth()
  const [restoring, setRestoring] = useState(Boolean(getRefreshToken()) && !getSession())

  useEffect(() => {
    let active = true

    async function restore() {
      const refreshToken = getRefreshToken()
      if (!refreshToken || getSession()) {
        setRestoring(false)
        return
      }
      try {
        await refreshSession()
      } catch {
        // refreshSession clears only the failed session it started with.
      } finally {
        if (active) setRestoring(false)
      }
    }

    void restore()
    return () => { active = false }
  }, [])

  if (restoring) return <Spin fullscreen tip="Đang khôi phục phiên đăng nhập..." />

  return (
    <>
      <RouteTitle />
      <Suspense fallback={<CenteredSpinner />}>
        <Routes>
          <Route path="/login" element={session ? <Navigate to="/" replace /> : <LoginPage />} />
          <Route path="/403" element={<ForbiddenPage />} />
          <Route element={<ProtectedRoute />}>
            <Route element={<MainLayout />}>
              <Route path="/" element={<HomePage />} />
              <Route path="/service-categories" element={<ServiceCategoriesPage />} />
              <Route path="/services" element={<ServicesPage />} />
              <Route path="/combos" element={<CombosPage />} />
              <Route path="/appointments" element={<AppointmentsPage />} />
              <Route path="/customers" element={<CustomersPage />} />
              <Route path="/staff" element={<StaffPage />} />
              <Route path="/staff-schedules" element={<WorkSchedulesPage />} />
              <Route path="/billing" element={<BillingPage />} />
              <Route path="/promotions" element={<PromotionsPage />} />
              <Route path="/reviews" element={<ReviewsPage />} />
              <Route path="/reports" element={<ReportsPage />} />
              <Route path="/audit-logs" element={<AuditLogsPage />} />
              <Route path="/accounts" element={<AccountsPage />} />
              <Route path="/permissions" element={<PermissionsPage />} />
            </Route>
          </Route>
          <Route path="*" element={session ? <NotFoundPage /> : <Navigate to="/login" replace />} />
        </Routes>
      </Suspense>
    </>
  )
}

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <ConfigProvider locale={viVN} theme={theme}>
        <AntApp>
          <BrowserRouter><ApplicationRoutes /></BrowserRouter>
        </AntApp>
      </ConfigProvider>
    </QueryClientProvider>
  )
}
