import axios, { type InternalAxiosRequestConfig } from 'axios'
import { isAuthResponse, type RefreshRequest } from '../types/auth'
import { clearSession, getRefreshToken, getSession, saveAuthResponse } from './session'

const api = axios.create({ baseURL: '/api/v1', headers: { 'Content-Type': 'application/json' } })
const refreshClient = axios.create({ baseURL: '/api/v1', headers: { 'Content-Type': 'application/json' } })

interface RetryConfig extends InternalAxiosRequestConfig {
  _retry?: boolean
}

let refreshPromise: Promise<string> | null = null

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
      if (!refreshPromise) {
        const body: RefreshRequest = { refreshToken: currentRefreshToken }
        refreshPromise = refreshClient.post<unknown>('/auth/refresh', body)
          .then(({ data }) => {
            if (!isAuthResponse(data) || !data.accessToken) {
              throw new Error('Phản hồi làm mới phiên không hợp lệ.')
            }
            saveAuthResponse(data)
            return data.accessToken
          })
          .finally(() => { refreshPromise = null })
      }
      const accessToken = await refreshPromise
      config.headers.Authorization = `Bearer ${accessToken}`
      return await api(config)
    } catch (refreshError: unknown) {
      clearSession()
      window.location.assign('/login')
      return Promise.reject(refreshError)
    }
  },
)

export default api
