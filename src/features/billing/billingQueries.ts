import { useQuery } from '@tanstack/react-query'
import * as billingApi from '../../api/billing'

export const billingKeys = { invoices: ['invoices'] as const }

export function useInvoices() {
  return useQuery({ queryKey: billingKeys.invoices, queryFn: billingApi.getInvoices })
}
