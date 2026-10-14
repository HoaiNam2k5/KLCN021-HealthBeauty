export interface CurrentPermissions {
  role: string
  permissions: string[]
}

export function parseCurrentPermissions(value: unknown): CurrentPermissions {
  if (typeof value !== 'object' || value === null || !('role' in value) || typeof value.role !== 'string'
    || !('permissions' in value) || !Array.isArray(value.permissions)
    || !value.permissions.every((code: unknown) => typeof code === 'string')) {
    throw new Error('Phản hồi quyền truy cập không hợp lệ.')
  }
  return { role: value.role, permissions: [...new Set(value.permissions as string[])] }
}

export function hasPermission(permissions: readonly string[], code: string): boolean {
  return permissions.includes(code)
}

const managementPermissions = [
  'CUSTOMER.READ', 'CUSTOMER.WRITE', 'STAFF.READ', 'STAFF.WRITE', 'SERVICE.READ', 'SERVICE.WRITE',
  'APPOINTMENT.READ', 'APPOINTMENT.WRITE', 'INVOICE.READ', 'INVOICE.WRITE', 'PAYMENT.WRITE',
  'PROMOTION.WRITE', 'REVIEW.MODERATE', 'REPORT.READ',
] as const

export function supportsPermission(role: string | null, code: string): boolean {
  if (role === 'Admin') return [...managementPermissions, 'ACCOUNT.READ', 'ACCOUNT.WRITE', 'ROLE.READ', 'ROLE.WRITE', 'AUDIT.READ'].some((permission) => permission === code)
  if (role === 'Manager' || role === 'Reception') return managementPermissions.some((permission) => permission === code)
  if (role === 'Staff') return ['APPOINTMENT.READ', 'STAFF.READ', 'SERVICE.READ'].includes(code)
  return role === 'Customer' && code === 'SERVICE.READ'
}

export function canVisitRoute(path: string, role: string | null, permissions: readonly string[]): boolean {
  const route = path.length > 1 ? path.replace(/\/+$/, '') : path
  if (route === '/') return true
  if (role === 'Customer') return false
  if (route === '/permissions') return role === 'Admin' && hasPermission(permissions, 'ROLE.READ')
  if (route === '/audit-logs') return role === 'Admin' && hasPermission(permissions, 'ACCOUNT.READ')
  if (route === '/accounts') return role === 'Admin' && hasPermission(permissions, 'ACCOUNT.READ')
  if (route === '/staff' && role === 'Staff') return false
  const requirements: Record<string, readonly string[]> = {
    '/service-categories': ['SERVICE.READ', 'SERVICE.WRITE'], '/services': ['SERVICE.READ', 'SERVICE.WRITE'], '/combos': ['SERVICE.READ', 'SERVICE.WRITE'],
    '/appointments': ['APPOINTMENT.READ'], '/customers': ['CUSTOMER.READ'], '/staff': ['STAFF.READ'],
    '/staff-schedules': ['STAFF.READ'], '/billing': ['INVOICE.READ'],
    '/promotions': ['PROMOTION.WRITE'], '/reviews': ['REVIEW.MODERATE'], '/reports': ['REPORT.READ'],
  }
  return requirements[route]?.some((code) => supportsPermission(role, code) && hasPermission(permissions, code)) ?? false
}
