export interface PromotionResponse {
  khuyenMaiId: number
  tenKhuyenMai: string | null
  loaiGiam: string | null
  mucGiam: number
  dieuKienApDung: string | null
  ngayBatDauHieuLuc: string | null
  ngayKetThucHieuLuc: string | null
}

export interface Promotion {
  id: number
  name: string | null
  discountType: string | null
  discount: number
  condition: string | null
  startsAt: string | null
  endsAt: string | null
}

export interface PromotionRequest {
  name: string
  discountType: string
  discount: number
  condition: string | null
  startsAt: string | null
  endsAt: string | null
}

export interface CustomerVoucherResponse {
  voucherId: number
  maCode: string
  khuyenMaiId: number
  tenKhuyenMai: string | null
  giaTriGiam: number
  hanSuDung: string
  trangThai: number
}

export interface CustomerVoucher {
  id: number
  code: string
  promotionId: number
  promotionName: string | null
  discountValue: number
  expiresAt: string
  status: number
}

export interface VoucherRequest {
  code: string
  promotionId: number
  customerId: number | null
  discountValue: number
  expiresAt: string
  pointsCost?: number
}

export interface Voucher {
  id: number
  code: string
  promotionId: number
  promotionName: string
  customerId: number | null
  customerName: string | null
  discountValue: number
  expiresAt: string
  active: boolean
  pointsCost?: number
}

export function mapPromotion(response: PromotionResponse): Promotion {
  return {
    id: response.khuyenMaiId,
    name: response.tenKhuyenMai,
    discountType: response.loaiGiam,
    discount: response.mucGiam,
    condition: response.dieuKienApDung,
    startsAt: response.ngayBatDauHieuLuc,
    endsAt: response.ngayKetThucHieuLuc,
  }
}

export function mapPromotionList(value: unknown): Promotion[] {
  if (!Array.isArray(value)) return []
  return value.map((item) => mapPromotion(item as PromotionResponse))
}

export function mapPromotionRequest(body: PromotionRequest): PromotionRequest {
  return { ...body, name: body.name.trim(), discountType: body.discountType.trim(), condition: body.condition?.trim() || null }
}

export function mapCustomerVoucher(response: CustomerVoucherResponse): CustomerVoucher {
  return {
    id: response.voucherId,
    code: response.maCode,
    promotionId: response.khuyenMaiId,
    promotionName: response.tenKhuyenMai,
    discountValue: response.giaTriGiam,
    expiresAt: response.hanSuDung,
    status: response.trangThai,
  }
}

export const DISCOUNT_TYPE_OPTIONS: { value: string; label: string }[] = [{ value: 'PhanTram', label: 'Phần trăm' }, { value: 'SoTien', label: 'Số tiền' }]

export function promotionStatus(promotion: Promotion, now = new Date()): 'upcoming' | 'active' | 'expired' {
  if (promotion.startsAt && new Date(promotion.startsAt) > now) return 'upcoming'
  if (promotion.endsAt && new Date(promotion.endsAt) < now) return 'expired'
  return 'active'
}

export function isValidPromotionPeriod(startsAt: string, endsAt: string): boolean {
  return new Date(endsAt).getTime() >= new Date(startsAt).getTime()
}

export function voucherStatusLabel(voucher: CustomerVoucher, now = new Date()): string {
  if (voucher.status !== 1) return 'Đã dùng'
  return new Date(voucher.expiresAt) < now ? 'Hết hạn' : 'Chưa sử dụng'
}
