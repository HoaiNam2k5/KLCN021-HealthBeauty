import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as reviewsApi from '../../api/reviews'

export const reviewKeys = {
  reviews: ['reviews'] as const,
  pending: ['reviews', 'pending'] as const,
  invoices: ['review-invoices'] as const,
  appointments: ['review-appointments'] as const,
  customers: ['review-customers'] as const,
  staff: ['review-staff'] as const,
}

export function useReviews() {
  return useQuery({ queryKey: reviewKeys.reviews, queryFn: () => reviewsApi.getReviews() })
}

export function usePendingReviews(enabled: boolean) {
  return useQuery({ queryKey: reviewKeys.pending, queryFn: reviewsApi.getPendingReviews, enabled })
}

export function useReviewInvoices(enabled = true) {
  return useQuery({ queryKey: reviewKeys.invoices, queryFn: reviewsApi.getReviewInvoices, enabled })
}

export function useReviewAppointments(enabled = true) {
  return useQuery({ queryKey: reviewKeys.appointments, queryFn: reviewsApi.getReviewAppointments, enabled })
}

export function useReviewCustomers(enabled = true) {
  return useQuery({ queryKey: reviewKeys.customers, queryFn: reviewsApi.getReviewCustomers, enabled })
}

export function useReviewStaff(enabled = true) {
  return useQuery({ queryKey: reviewKeys.staff, queryFn: reviewsApi.getReviewStaff, enabled })
}

export function useSetReviewVisibility() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; visible: boolean }) => reviewsApi.setReviewVisibility(input.id, input.visible),
    onSuccess: () => client.invalidateQueries({ queryKey: reviewKeys.reviews }),
  })
}
