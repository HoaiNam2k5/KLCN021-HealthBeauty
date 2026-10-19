import api from './client'
import { mapPromotionList, mapPromotionRequest, type Promotion, type PromotionRequest, type Voucher, type VoucherRequest } from '../types/promotions'

export async function getPromotions(): Promise<Promotion[]> {
  const { data } = await api.get<unknown>('/promotions')
  return mapPromotionList(data)
}

export async function createPromotion(body: PromotionRequest): Promise<void> {
  await api.post('/promotions', mapPromotionRequest(body))
}

export async function updatePromotion(id: number, body: PromotionRequest): Promise<void> {
  await api.put(`/promotions/${id}`, mapPromotionRequest(body))
}

export async function deletePromotion(id: number): Promise<void> {
  await api.delete(`/promotions/${id}`)
}

export async function getVouchers(keyword = '', active?: boolean): Promise<Voucher[]> {
  const { data } = await api.get<Voucher[]>('/vouchers', { params: { keyword: keyword.trim() || undefined, active } })
  return Array.isArray(data) ? data : []
}

export async function saveVoucher(input: { id?: number; body: VoucherRequest }): Promise<void> {
  const body = { ...input.body, code: input.body.code.trim().toUpperCase() }
  if (input.id === undefined) await api.post('/promotions/vouchers', body)
  else await api.put(`/promotions/vouchers/${input.id}`, body)
}

export async function setVoucherStatus(input: { id: number; active: boolean }): Promise<void> {
  await api.patch(`/promotions/vouchers/${input.id}/status`, null, { params: { active: input.active } })
}

export async function deleteVoucher(id: number): Promise<void> {
  await api.delete(`/promotions/vouchers/${id}`)
}
