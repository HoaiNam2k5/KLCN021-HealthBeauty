import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { useAuth } from '../hooks/useAuth'
import { isWebAccount } from '../types/auth'
import { Alert, Button, Spin } from 'antd'
import { usePermissions } from '../hooks/usePermissions'

export default function ProtectedRoute() {
  const session = useAuth()
  const location = useLocation()
  const access = usePermissions()

  if (!session || !session.account) return <Navigate to="/login" replace />
  if (!isWebAccount(session.account)) return <Navigate to="/403" replace />

  if (location.pathname !== '/') {
    if (access.isLoading) return <div className="route-loading"><Spin size="large" /></div>
    if (access.isError) return <Alert type="error" showIcon message="Không tải được quyền truy cập" action={<Button onClick={() => { void access.refetch() }}>Thử lại</Button>} />
    if (!access.canVisit(location.pathname)) return <Navigate to="/403" replace />
  }

  return <Outlet />
}
