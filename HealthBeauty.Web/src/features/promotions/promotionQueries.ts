import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as promotionsApi from '../../api/promotions'
import type { PromotionRequest, VoucherRequest } from '../../types/promotions'

export const promotionKeys = { all: ['promotions'] as const, vouchers: ['vouchers'] as const }

export function usePromotions() {
  return useQuery({ queryKey: promotionKeys.all, queryFn: promotionsApi.getPromotions })
}

function usePromotionMutation<T>(mutationFn: (value: T) => Promise<void>) {
  const client = useQueryClient()
  return useMutation({ mutationFn, onSuccess: () => client.invalidateQueries({ queryKey: promotionKeys.all }) })
}

export function useSavePromotion() {
  return usePromotionMutation((input: { id?: number; body: PromotionRequest }) => input.id === undefined
    ? promotionsApi.createPromotion(input.body)
    : promotionsApi.updatePromotion(input.id, input.body))
}

export function useDeletePromotion() {
  return usePromotionMutation(promotionsApi.deletePromotion)
}

export function useVouchers(keyword: string, active?: boolean) {
  return useQuery({ queryKey: [...promotionKeys.vouchers, keyword, active], queryFn: () => promotionsApi.getVouchers(keyword, active) })
}

function useVoucherMutation<T>(mutationFn: (value: T) => Promise<void>) {
  const client = useQueryClient()
  return useMutation({ mutationFn, onSuccess: () => client.invalidateQueries({ queryKey: promotionKeys.vouchers }) })
}

export function useSaveVoucher() {
  return useVoucherMutation((input: { id?: number; body: VoucherRequest }) => promotionsApi.saveVoucher(input))
}

export function useSetVoucherStatus() {
  return useVoucherMutation(promotionsApi.setVoucherStatus)
}

export function useDeleteVoucher() {
  return useVoucherMutation(promotionsApi.deleteVoucher)
}
