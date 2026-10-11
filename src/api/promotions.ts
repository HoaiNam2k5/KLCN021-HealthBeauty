import api from './client'
import { mapPromotionList, mapPromotionRequest, type Promotion, type PromotionRequest } from '../types/promotions'

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

// Swagger không khai báo GET danh sách voucher quản trị; chưa triển khai CRUD UI voucher.
// GET /customers/me/vouchers dành cho customer và trả 404 với tài khoản admin thử nghiệm.
// POST /promotions/vouchers/validate nhận query `code`; chưa gọi endpoint này.
// Không có API cộng/đổi điểm riêng; rewardPoints đã hiển thị trong trang Khách hàng.