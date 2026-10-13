import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as promotionsApi from '../../api/promotions'
import type { PromotionRequest } from '../../types/promotions'

export const promotionKeys = { all: ['promotions'] as const }

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
