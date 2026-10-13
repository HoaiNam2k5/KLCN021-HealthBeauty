import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as reviewsApi from '../../api/reviews'

export const reviewKeys = {
  reviews: ['reviews'] as const,
  invoices: ['review-invoices'] as const,
  appointments: ['review-appointments'] as const,
  customers: ['review-customers'] as const,
  staff: ['review-staff'] as const,
}

export function useReviews() {
  return useQuery({ queryKey: reviewKeys.reviews, queryFn: () => reviewsApi.getReviews() })
}

export function useReviewInvoices() {
  return useQuery({ queryKey: reviewKeys.invoices, queryFn: reviewsApi.getReviewInvoices })
}

export function useReviewAppointments() {
  return useQuery({ queryKey: reviewKeys.appointments, queryFn: reviewsApi.getReviewAppointments })
}

export function useReviewCustomers() {
  return useQuery({ queryKey: reviewKeys.customers, queryFn: reviewsApi.getReviewCustomers })
}

export function useReviewStaff() {
  return useQuery({ queryKey: reviewKeys.staff, queryFn: reviewsApi.getReviewStaff })
}

export function useSetReviewVisibility() {
  const client = useQueryClient()
  return useMutation({
    mutationFn: (input: { id: number; visible: boolean }) => reviewsApi.setReviewVisibility(input.id, input.visible),
    onSuccess: () => client.invalidateQueries({ queryKey: reviewKeys.reviews }),
  })
}
