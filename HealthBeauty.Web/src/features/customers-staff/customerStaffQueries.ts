import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as api from '../../api/customersStaff'
import type { StaffRequest, UpdateCustomerRequest } from '../../types/customersStaff'

export const customerStaffKeys = {
  customers: ['customers'] as const,
  staff: ['staff'] as const,
}

export function useCustomerPointHistory(id: number | null, page = 1, pageSize = 20, enabled = true) {
  return useQuery({
    queryKey: ['customers', id, 'points', page, pageSize],
    queryFn: () => api.getCustomerPointHistory(id!, page, pageSize),
    enabled: Boolean(id) && enabled,
  })
}

export function useCustomers(keyword: string, enabled = true) {
  return useQuery({ queryKey: [...customerStaffKeys.customers, keyword], queryFn: () => api.getCustomers(keyword), enabled })
}

export function useCreateCustomer() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: api.createCustomer,
    onSuccess: () => Promise.all([
      client.invalidateQueries({ queryKey: customerStaffKeys.customers }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
    ]),
  })
}

export function useUpdateCustomer() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; body: UpdateCustomerRequest }) => api.updateCustomer(input.id, input.body),
    onSuccess: () => Promise.all([
      client.invalidateQueries({ queryKey: customerStaffKeys.customers }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
    ]),
  })
}

export function useStaff() {
  return useQuery({ queryKey: customerStaffKeys.staff, queryFn: api.getStaff })
}

export function useSaveStaff() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id?: number; body: StaffRequest }) => api.saveStaff(input),
    onSuccess: () => Promise.all([client.invalidateQueries({ queryKey: customerStaffKeys.staff }), client.invalidateQueries({ queryKey: ['admin-accounts'] })]),
  })
}

export function useDeleteStaff() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: api.deleteStaff,
    onSuccess: () => client.invalidateQueries({ queryKey: customerStaffKeys.staff }),
  })
}
