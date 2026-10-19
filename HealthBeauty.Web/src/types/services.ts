export interface ServiceCategory {
  id: number
  name: string | null
  description: string | null
}

export interface CategoryRequest {
  name: string | null
  description: string | null
}

export interface Service {
  id: number
  categoryId: number
  name: string | null
  price: number
  durationMinutes: number
  description: string | null
  imageUrl?: string | null
}

export interface ServiceRequest {
  categoryId: number
  name: string | null
  price: number
  durationMinutes: number
  description: string | null
  imageUrl?: string | null
}

export interface ComboItemRequest {
  serviceId: number
  quantity: number
}

export interface ComboRequest {
  name: string | null
  price: number
  validFrom: string
  validTo: string
  items: ComboItemRequest[] | null
  imageUrl?: string | null
}

export interface ComboItemResponse {
  serviceId: number
  quantity: number
}

export interface Combo {
  id: number
  name: string | null
  price: number
  validFrom: string
  validTo: string
  items: ComboItemResponse[] | null
  imageUrl?: string | null
}

export interface PageQuery {
  page: number
  size: number
}

export interface PageResult<T> {
  items: T[]
  page: number
  size: number
  totalItems: number
  totalPages: number
}

export function asArray<T>(value: unknown): T[] {
  if (Array.isArray(value)) return value as T[]
  if (typeof value === 'object' && value !== null && 'items' in value) {
    const items: unknown = value.items
    if (Array.isArray(items)) return items as T[]
  }
  return []
}
