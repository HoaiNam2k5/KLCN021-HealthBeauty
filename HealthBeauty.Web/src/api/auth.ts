import type { AuthResponse, LoginRequest } from '../types/auth'
import api from './client'

export async function login(credentials: LoginRequest): Promise<AuthResponse> {
  const { data } = await api.post<AuthResponse>('/auth/login', credentials)
  return data
}

export interface ForgotPasswordRequest {
  email: string
}
export interface ForgotPasswordResponse {
  message: string
}
export interface ResetPasswordRequest {
  email: string
  otp: string
  newPassword: string
}
export interface ResetPasswordResponse {
  message: string
}
export async function forgotPassword(body: ForgotPasswordRequest): Promise<ForgotPasswordResponse> {
  const { data } = await api.post<ForgotPasswordResponse>('/auth/forgot-password', body)
  return data
}
export async function resetPassword(body: ResetPasswordRequest): Promise<ResetPasswordResponse> {
  const { data } = await api.post<ResetPasswordResponse>('/auth/reset-password', body)
  return data
}
