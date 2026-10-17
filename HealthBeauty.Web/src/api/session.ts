import type { AccountResponse, AuthResponse, AuthSession } from '../types/auth'

const REFRESH_TOKEN_KEY = 'healthbeauty.refreshToken'

let currentSession: AuthSession | null = null
let refreshToken = localStorage.getItem(REFRESH_TOKEN_KEY)
const listeners = new Set<() => void>()

function notify(): void {
  listeners.forEach((listener) => listener())
}

export function getSession(): AuthSession | null {
  return currentSession
}

export function subscribeSession(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function getRefreshToken(): string | null {
  return refreshToken
}

export function saveAuthResponse(response: AuthResponse): void {
  if (!response.accessToken || !response.refreshToken || !response.account) {
    throw new Error('Phản hồi xác thực thiếu token hoặc thông tin tài khoản.')
  }
  currentSession = { accessToken: response.accessToken, account: response.account }
  refreshToken = response.refreshToken
  localStorage.setItem(REFRESH_TOKEN_KEY, response.refreshToken)
  notify()
}

export function restoreSession(accessToken: string, account: AccountResponse): void {
  currentSession = { accessToken, account }
  notify()
}

export function clearSession(): void {
  currentSession = null
  refreshToken = null
  localStorage.removeItem(REFRESH_TOKEN_KEY)
  notify()
}
