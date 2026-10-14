import axios, { type InternalAxiosRequestConfig } from 'axios'
import { isAuthResponse, isWebAccount, type RefreshRequest } from '../types/auth'
import { clearSession, getRefreshToken, getSession, saveAuthResponse } from './session'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || '/api/v1'
const api = axios.create({ baseURL: apiBaseUrl, headers: { 'Content-Type': 'application/json' } })
const refreshClient = axios.create({ baseURL: apiBaseUrl, headers: { 'Content-Type': 'application/json' } })

interface RetryConfig extends InternalAxiosRequestConfig {
  _retry?: boolean
}

let refreshPromise: Promise<string> | null = null

// Startup restoration and concurrent 401 retries share one rotating refresh request.
export function refreshSession(): Promise<string> {
  if (refreshPromise) return refreshPromise
  const token = getRefreshToken()
  if (!token) return Promise.reject(new Error('Không có phiên để khôi phục.'))
  const body: RefreshRequest = { refreshToken: token }
  refreshPromise = refreshClient.post<unknown>('/auth/refresh', body)
    .then(async ({ data }) => {
      if (!isAuthResponse(data) || !data.account || !isWebAccount(data.account) || !data.accessToken) {
        throw new Error('Phản hồi làm mới phiên không hợp lệ.')
      }
      // An old refresh must not restore a logged-out or newly logged-in account.
      if (getRefreshToken() !== token) {
        try {
          await refreshClient.post('/auth/logout', { refreshToken: data.refreshToken }, {
            headers: { Authorization: `Bearer ${data.accessToken}` },
          })
        } catch {
          // Best-effort revocation must never restore the discarded session.
        }
        throw new Error('Phiên đăng nhập đã thay đổi.')
      }
      saveAuthResponse(data)
      return data.accessToken
    })
    .catch((error: unknown) => {
      if (getRefreshToken() === token) clearSession()
      throw error
    })
    .finally(() => { refreshPromise = null })
  return refreshPromise
}

api.interceptors.request.use((config) => {
  const token = getSession()?.accessToken
  if (token) config.headers.Authorization = `Bearer ${token}`
  return config
})

api.interceptors.response.use(
  (response) => response,
  async (error: unknown) => {
    if (!axios.isAxiosError(error) || error.response?.status !== 401) return Promise.reject(error)
    const config = error.config as RetryConfig | undefined
    if (!config || config._retry || config.url?.includes('/auth/login') || config.url?.includes('/auth/refresh')) {
      return Promise.reject(error)
    }

    const currentRefreshToken = getRefreshToken()
    if (!currentRefreshToken) {
      clearSession()
      window.location.assign('/login')
      return Promise.reject(error)
    }

    config._retry = true
    try {
      const accessToken = await refreshSession()
      config.headers.Authorization = `Bearer ${accessToken}`
      // Refresh rotates the token; logout must revoke the replacement, not the old token.
      if (config.url === '/auth/logout') {
        config.data = { refreshToken: getRefreshToken() }
      }
      return await api(config)
    } catch (refreshError: unknown) {
      if (!getSession()) window.location.assign('/login')
      return Promise.reject(refreshError)
    }
  },
)

export default api
