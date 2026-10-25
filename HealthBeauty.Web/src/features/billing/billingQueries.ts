import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import { useEffect } from 'react'
import * as billingApi from '../../api/billing'
import type { ApplyInvoiceDiscountRequest, CreateInvoiceRequest, PaymentRequest } from '../../types/billing'
import { INVOICE_REFRESH_INTERVAL, recordPendingPayment } from './invoiceSync'

export const billingKeys = { invoices: ['invoices'] as const, detail: (id: number | null) => ['invoices', 'detail', id] as const }

export function useInvoices() {
  const client = useQueryClient()
  const query = useQuery({
    queryKey: billingKeys.invoices,
    queryFn: billingApi.getInvoices,
    refetchInterval: INVOICE_REFRESH_INTERVAL,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: 'always',
    refetchOnMount: 'always',
  })
  useEffect(() => {
    if (!query.data) return
    // Structural sharing keeps this stable when a poll returns identical data.
    // A webhook can change the invoice outside this browser's mutations.
    void Promise.all([
      client.invalidateQueries({ queryKey: ['customers'] }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
      client.invalidateQueries({ queryKey: ['appointments'] }),
      client.invalidateQueries({ queryKey: ['reports'] }),
    ])
  }, [client, query.data])
  return query
}

export function useInvoiceDetail(id: number | null, enabled: boolean) {
  return useQuery({
    queryKey: billingKeys.detail(id),
    queryFn: () => billingApi.getInvoice(id!),
    enabled: enabled && id !== null,
    refetchInterval: INVOICE_REFRESH_INTERVAL,
    refetchIntervalInBackground: false,
    refetchOnWindowFocus: 'always',
    refetchOnMount: 'always',
  })
}

export function useCreateInvoice() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (body: CreateInvoiceRequest) => billingApi.createInvoice(body),
    onSuccess: () => Promise.all([
      client.invalidateQueries({ queryKey: billingKeys.invoices }),
      client.invalidateQueries({ queryKey: ['customers'] }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
      client.invalidateQueries({ queryKey: ['appointments'] }),
      client.invalidateQueries({ queryKey: ['reports'] }),
    ]),
  })
}

export function useRecordInvoicePayment() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; body: PaymentRequest; expectedTotal: number }) => recordPendingPayment(input.id, input.body, billingApi, input.expectedTotal),
    onSuccess: () => Promise.all([
      client.invalidateQueries({ queryKey: billingKeys.invoices }),
      client.invalidateQueries({ queryKey: ['customers'] }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
      client.invalidateQueries({ queryKey: ['appointments'] }),
      client.invalidateQueries({ queryKey: ['reports'] }),
    ]),
  })
}

export function useApplyInvoiceDiscount() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; body: ApplyInvoiceDiscountRequest }) => billingApi.applyInvoiceDiscount(input.id, input.body),
    onSuccess: () => Promise.all([
      client.invalidateQueries({ queryKey: billingKeys.invoices }),
      client.invalidateQueries({ queryKey: ['customers'] }),
      client.invalidateQueries({ queryKey: ['appointment-customers'] }),
      client.invalidateQueries({ queryKey: ['appointments'] }),
      client.invalidateQueries({ queryKey: ['reports'] }),
    ]),
  })
}
