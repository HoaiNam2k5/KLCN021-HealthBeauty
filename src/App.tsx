import { useEffect, useState } from 'react'
import { App as AntApp, Spin } from 'antd'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { ConfigProvider } from 'antd'
import theme from './theme/theme'
import ServiceCategoriesPage from './features/services/ServiceCategoriesPage'
import ServicesPage from './features/services/ServicesPage'
import CombosPage from './features/services/CombosPage'
import AppointmentsPage from './features/appointments/AppointmentsPage'
import CustomersPage from './features/customers-staff/CustomersPage'
import StaffPage from './features/customers-staff/StaffPage'
import WorkSchedulesPage from './features/staff-schedules/WorkSchedulesPage'
import BillingPage from './features/billing/BillingPage'
import PromotionsPage from './features/promotions/PromotionsPage'
import ReviewsPage from './features/reviews/ReviewsPage'
import ReportsPage from './features/reports/ReportsPage'
import api from './api/client'
import { clearSession, getRefreshToken, getSession, saveAuthResponse } from './api/session'
import { useAuth } from './hooks/useAuth'
import LoginPage from './features/auth/LoginPage'
import MainLayout from './layouts/MainLayout'
import ProtectedRoute from './routes/ProtectedRoute'
import { isAuthResponse, isWebAccount } from './types/auth'

const queryClient = new QueryClient()

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
    <Routes>
      <Route path="/login" element={session ? <Navigate to="/" replace /> : <LoginPage />} />
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
        </Route>
      </Route>
      <Route path="*" element={<Navigate to={getSession() ? '/' : '/login'} replace />} />
    </Routes>
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

