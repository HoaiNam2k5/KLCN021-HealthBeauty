import type { AuthResponse, LoginRequest } from '../types/auth'
import api from './client'

export async function login(credentials: LoginRequest): Promise<AuthResponse> {
  const { data } = await api.post<AuthResponse>('/auth/login', credentials)
  return data
}
