import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as servicesApi from '../../api/services'
import type { CategoryRequest, ComboRequest, ServiceRequest } from '../../types/services'

export const serviceKeys = {
  categories: ['service-categories'] as const,
  services: ['services'] as const,
  combos: ['combos'] as const,
}

export function useCategories() {
  return useQuery({ queryKey: serviceKeys.categories, queryFn: servicesApi.getCategories })
}

export function useServices(filters: { categoryId?: number; keyword?: string } = {}) {
  return useQuery({ queryKey: [...serviceKeys.services, filters], queryFn: () => servicesApi.getServices(filters) })
}

export function useCombos() {
  return useQuery({ queryKey: serviceKeys.combos, queryFn: servicesApi.getCombos })
}

function useServiceMutation<TVariables>(mutationFn: (variables: TVariables) => Promise<void>, key: readonly unknown[]) {
  const queryClient = useQueryClient()
  return useMutation({ mutationFn, onSuccess: () => queryClient.invalidateQueries({ queryKey: key }) })
}

export function useSaveCategory() {
  return useServiceMutation((input: { id?: number; body: CategoryRequest }) => input.id === undefined
    ? servicesApi.createCategory(input.body)
    : servicesApi.updateCategory(input.id, input.body), serviceKeys.categories)
}
export function useDeleteCategory() {
  return useServiceMutation(servicesApi.deleteCategory, serviceKeys.categories)
}
export function useSaveService() {
  return useServiceMutation((input: { id?: number; body: ServiceRequest }) => input.id === undefined
    ? servicesApi.createService(input.body)
    : servicesApi.updateService(input.id, input.body), serviceKeys.services)
}
export function useDeleteService() {
  return useServiceMutation(servicesApi.deleteService, serviceKeys.services)
}
export function useSaveCombo() {
  return useServiceMutation((input: { id?: number; body: ComboRequest }) => input.id === undefined
    ? servicesApi.createCombo(input.body)
    : servicesApi.updateCombo(input.id, input.body), serviceKeys.combos)
}
export function useDeleteCombo() {
  return useServiceMutation(servicesApi.deleteCombo, serviceKeys.combos)
}
