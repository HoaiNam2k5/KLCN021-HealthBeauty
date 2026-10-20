import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query'
import * as api from '../../api/servicePackages'
import type { PackagePaymentRequest, PackagePurchaseRequest, ServicePackageRequest } from '../../types/servicePackages'

export const packageKeys = { all: ['service-packages'] as const, catalog: (management = false) => [...packageKeys.all, 'catalog', management] as const, customer: (id?: number) => [...packageKeys.all, 'customer', id] as const, detail: (id?: number) => [...packageKeys.all, 'purchase', id] as const, sales: (from: string, to: string) => [...packageKeys.all, 'sales', from, to] as const }
export function useServicePackages(management = false) { return useQuery({ queryKey: packageKeys.catalog(management), queryFn: () => api.getServicePackages(management) }) }
export function useCustomerPackages(customerId?: number) { return useQuery({ queryKey: packageKeys.customer(customerId), queryFn: () => api.getCustomerPackages(customerId!), enabled: customerId !== undefined }) }
export function usePackagePurchaseDetail(id?: number) { return useQuery({ queryKey: packageKeys.detail(id), queryFn: () => api.getPackagePurchaseDetail(id!), enabled: id !== undefined }) }
export function usePackageSales(from: string, to: string, enabled = true) { return useQuery({ queryKey: packageKeys.sales(from, to), queryFn: () => api.getPackageSales(from, to), enabled }) }
export function useSaveServicePackage() {
 const client = useQueryClient()
 return useMutation({ mutationFn: ({ id, body }: { id?: number; body: ServicePackageRequest }) => id === undefined ? api.createServicePackage(body) : api.updateServicePackage(id, body), onSuccess: () => client.invalidateQueries({ queryKey: packageKeys.all }) })
}
export function usePurchasePackage() {
 const client = useQueryClient()
 return useMutation({ mutationFn: (body: PackagePurchaseRequest) => api.purchasePackage(body), onSuccess: (_data, body) => Promise.all([client.invalidateQueries({ queryKey: packageKeys.customer(body.customerId) }), client.invalidateQueries({ queryKey: packageKeys.all })]) })
}
export function usePayPackage() {
 const client = useQueryClient()
 return useMutation({ mutationFn: ({ id, method }: { id: number; method: PackagePaymentRequest['method'] }) => api.payPackage(id, method), onSuccess: async (pkg) => { await Promise.all([client.invalidateQueries({ queryKey: packageKeys.all }), client.invalidateQueries({ queryKey: packageKeys.customer(pkg.customerId) }), client.invalidateQueries({ queryKey: ['customers'] }), client.invalidateQueries({ queryKey: ['customer-points'] }), client.invalidateQueries({ queryKey: ['invoices'] })]) } })
}
export function useCancelPackagePurchase() {
 const client = useQueryClient()
 return useMutation({ mutationFn: api.cancelPurchase, onSuccess: () => client.invalidateQueries({ queryKey: packageKeys.all }) })
}
