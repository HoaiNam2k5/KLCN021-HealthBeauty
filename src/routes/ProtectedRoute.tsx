import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { isWebAccount } from '../types/auth'
import { REPORT_ADMIN_ROLES } from '../types/reports'

export default function ProtectedRoute() {
  const session = useAuth()
  const location = useLocation()

  if (!session || !session.account) return <Navigate to="/login" replace />
  if (!isWebAccount(session.account)) return <Navigate to="/403" replace />

  const requiresAdminRole = location.pathname === '/reports'
  const isAdmin = (REPORT_ADMIN_ROLES as readonly string[]).includes(session.account.role ?? '')
  if (requiresAdminRole && !isAdmin) return <Navigate to="/403" replace />

  return <Outlet />
}
