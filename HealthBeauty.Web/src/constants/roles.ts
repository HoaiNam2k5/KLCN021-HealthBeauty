export const ACCOUNT_ROLES = {
  ADMIN: 'Admin',
  MANAGER: 'Manager',
  RECEPTION: 'Reception',
  STAFF: 'Staff',
  CUSTOMER: 'Customer',
} as const

export type AccountRole = (typeof ACCOUNT_ROLES)[keyof typeof ACCOUNT_ROLES]

export const WEB_ROLES: AccountRole[] = [
  ACCOUNT_ROLES.ADMIN,
  ACCOUNT_ROLES.MANAGER,
  ACCOUNT_ROLES.RECEPTION,
  ACCOUNT_ROLES.STAFF,
]

export function isAccountRole(role: string | null): role is AccountRole {
  return Object.values(ACCOUNT_ROLES).some((accountRole) => accountRole === role)
}

export function isWebRole(role: string | null): role is Exclude<AccountRole, typeof ACCOUNT_ROLES.CUSTOMER> {
  return WEB_ROLES.some((webRole) => webRole === role)
}
