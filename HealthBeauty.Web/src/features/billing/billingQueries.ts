import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as billingApi from '../../api/billing'
import type { CreateInvoiceRequest, PaymentRequest } from '../../types/billing'

export const billingKeys = { invoices: ['invoices'] as const }

export function useInvoices() {
  return useQuery({ queryKey: billingKeys.invoices, queryFn: billingApi.getInvoices })
}

export function useCreateInvoice() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (body: CreateInvoiceRequest) => billingApi.createInvoice(body),
    onSuccess: () => client.invalidateQueries({ queryKey: billingKeys.invoices }),
  })
}

export function useRecordInvoicePayment() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; body: PaymentRequest }) => billingApi.recordInvoicePayment(input.id, input.body),
    onSuccess: () => client.invalidateQueries({ queryKey: billingKeys.invoices }),
  })
}
