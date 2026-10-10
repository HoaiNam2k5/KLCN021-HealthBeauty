import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as api from '../../api/customersStaff'
import type { StaffRequest } from '../../types/customersStaff'

export const customerStaffKeys = {
  customers: ['customers'] as const,
  staff: ['staff'] as const,
}

export function useCustomers(keyword: string) {
  return useQuery({ queryKey: [...customerStaffKeys.customers, keyword], queryFn: () => api.getCustomers(keyword) })
}

export function useStaff() {
  return useQuery({ queryKey: customerStaffKeys.staff, queryFn: api.getStaff })
}

export function useSaveStaff() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id?: number; body: StaffRequest }) => api.saveStaff(input),
    onSuccess: () => client.invalidateQueries({ queryKey: customerStaffKeys.staff }),
  })
}

export function useDeleteStaff() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: api.deleteStaff,
    onSuccess: () => client.invalidateQueries({ queryKey: customerStaffKeys.staff }),
  })
}
