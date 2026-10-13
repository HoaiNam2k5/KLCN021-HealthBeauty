import api from './client'
import { asArray, type CategoryRequest, type Combo, type ComboRequest, type Service, type ServiceCategory, type ServiceRequest } from '../types/services'

export async function getCategories(): Promise<ServiceCategory[]> {
  const { data } = await api.get<unknown>('/service-categories')
  return asArray<ServiceCategory>(data)
}

export async function getServices(filters: { categoryId?: number; keyword?: string } = {}): Promise<Service[]> {
  const params: Record<string, number | string> = {}
  if (filters.categoryId !== undefined) params.categoryId = filters.categoryId
  if (filters.keyword) params.keyword = filters.keyword
  const { data } = await api.get<unknown>('/services', { params })
  return asArray<Service>(data)
}

export async function getCombos(): Promise<Combo[]> {
  const { data } = await api.get<unknown>('/combos')
  return asArray<Combo>(data)
}

export async function createCategory(body: CategoryRequest): Promise<void> {
  await api.post('/service-categories', body)
}
export async function updateCategory(id: number, body: CategoryRequest): Promise<void> {
  await api.put(`/service-categories/${id}`, body)
}
export async function deleteCategory(id: number): Promise<void> {
  await api.delete(`/service-categories/${id}`)
}
export async function createService(body: ServiceRequest): Promise<void> {
  await api.post('/services', body)
}
export async function updateService(id: number, body: ServiceRequest): Promise<void> {
  await api.put(`/services/${id}`, body)
}
export async function deleteService(id: number): Promise<void> {
  await api.delete(`/services/${id}`)
}
export async function createCombo(body: ComboRequest): Promise<void> {
  await api.post('/combos', body)
}
export async function updateCombo(id: number, body: ComboRequest): Promise<void> {
  await api.put(`/combos/${id}`, body)
}
export async function deleteCombo(id: number): Promise<void> {
  await api.delete(`/combos/${id}`)
}
