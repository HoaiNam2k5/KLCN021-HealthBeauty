import api from './client'
import { getAllAppointments } from './appointments'
import { asReviewArray, asReviewRelatedArray, type Review, type ReviewAppointment, type ReviewCustomer, type ReviewInvoice, type ReviewStaff } from '../types/reviews'

export async function getReviews(serviceId?: number): Promise<Review[]> {
  const { data } = await api.get<unknown>('/reviews', { params: serviceId === undefined ? {} : { serviceId } })
  return asReviewArray(data)
}

export async function getReviewInvoices(): Promise<ReviewInvoice[]> {
  const { data } = await api.get<unknown>('/invoices')
  return asReviewRelatedArray<ReviewInvoice>(data)
}

export async function getReviewAppointments(): Promise<ReviewAppointment[]> {
  return getAllAppointments()
}

export async function getReviewCustomers(): Promise<ReviewCustomer[]> {
  const { data } = await api.get<unknown>('/customers')
  return asReviewRelatedArray<ReviewCustomer>(data)
}

export async function getReviewStaff(): Promise<ReviewStaff[]> {
  const { data } = await api.get<unknown>('/staff')
  return asReviewRelatedArray<ReviewStaff>(data)
}

export async function setReviewVisibility(id: number, visible: boolean): Promise<void> {
  await api.patch(`/reviews/${id}/moderation`, null, { params: { visible } })
}
