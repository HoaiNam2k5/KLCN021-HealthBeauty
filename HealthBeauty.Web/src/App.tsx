import { lazy, Suspense, useEffect, useState } from 'react'
import { App as AntApp, Button, Result, Spin } from 'antd'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes, useLocation } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import theme from './theme/theme'
import api from './api/client'
import { clearSession, getRefreshToken, getSession, saveAuthResponse } from './api/session'
import { useAuth } from './hooks/useAuth'
import LoginPage from './features/auth/LoginPage'
import MainLayout from './layouts/MainLayout'
import ProtectedRoute from './routes/ProtectedRoute'
import { isAuthResponse, isWebAccount } from './types/auth'

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
const PermissionsPage = lazy(() => import('./features/permissions/PermissionsPage'))

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
  '/permissions': 'Phân quyền',
  '/login': 'Đăng nhập',
}

function RouteTitle() {
  const location = useLocation()
  useEffect(() => {
    document.title = `${pageTitles[location.pathname] ?? 'Không tìm thấy trang'} | HealthBeauty`
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
        const { data }: { data: unknown } = await api.post('/auth/refresh', { refreshToken })
        if (!isAuthResponse(data)) throw new Error('Phản hồi làm mới phiên không hợp lệ.')
        if (data.account && isWebAccount(data.account)) saveAuthResponse(data)
        else clearSession()
      } catch {
        clearSession()
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
      <ConfigProvider theme={theme}>
        <AntApp>
          <BrowserRouter><ApplicationRoutes /></BrowserRouter>
        </AntApp>
      </ConfigProvider>
    </QueryClientProvider>
  )
}

