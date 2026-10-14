import { isWebRole } from '../constants/roles'

export type { AccountRole } from '../constants/roles'

export interface LoginRequest {
  email: string | null
  password: string | null
}

export interface RefreshRequest {
  refreshToken: string | null
}

export interface AccountResponse {
  id: number
  email: string | null
  name: string | null
  role: string | null
}

export interface AuthResponse {
  accessToken: string | null
  refreshToken: string | null
  accessTokenExpiresAt: string
  account: AccountResponse | null
}

export interface AuthSession {
  accessToken: string
  account: AccountResponse | null
}

export function isAuthResponse(value: unknown): value is AuthResponse {
  if (typeof value !== 'object' || value === null) return false
  const response = value as Record<string, unknown>
  if (typeof response.accessToken !== 'string' || typeof response.refreshToken !== 'string') return false
  if (typeof response.accessTokenExpiresAt !== 'string') return false
  if (response.account === null) return true
  if (typeof response.account !== 'object') return false

  const account = response.account as Record<string, unknown>
  return typeof account.id === 'number'
    && (typeof account.email === 'string' || account.email === null)
    && (typeof account.name === 'string' || account.name === null)
    && (typeof account.role === 'string' || account.role === null)
}

export function isWebAccount(account: AccountResponse): boolean {
  return isWebRole(account.role)
}
