import { Alert } from 'antd'
import { Navigate, Outlet } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { isWebAccount } from '../types/auth'

export default function ProtectedRoute() {
  const session = useAuth()
  if (!session || !session.account) return <Navigate to="/login" replace />
  if (!isWebAccount(session.account)) {
    return <Alert type="error" showIcon message="Tài khoản này dùng cho ứng dụng di động" />
  }
  return <Outlet />
}
