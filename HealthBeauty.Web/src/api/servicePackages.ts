import api from './client'
import type { CustomerPackage, PackagePaymentRequest, PackagePurchaseDetail, PackagePurchaseRequest, PackageSalesResponse, ServicePackage, ServicePackageRequest } from '../types/servicePackages'

export async function getServicePackages(management = false): Promise<ServicePackage[]> {
  const { data } = await api.get<ServicePackage[]>(management ? '/service-packages/management' : '/service-packages')
  return data
}
export async function createServicePackage(data: ServicePackageRequest): Promise<void> { await api.post('/service-packages', data) }
export async function updateServicePackage(id: number, data: ServicePackageRequest): Promise<void> { await api.put(`/service-packages/${id}`, data) }
export async function purchasePackage(data: PackagePurchaseRequest): Promise<CustomerPackage> { const { data: result } = await api.post<CustomerPackage>('/service-packages/purchases', data); return result }
export async function payPackage(id: number, method: PackagePaymentRequest['method']): Promise<CustomerPackage> { const { data } = await api.post<CustomerPackage>(`/service-packages/purchases/${id}/pay`, { method } satisfies PackagePaymentRequest); return data }
export async function getCustomerPackages(customerId: number): Promise<CustomerPackage[]> { const { data } = await api.get<CustomerPackage[]>(`/service-packages/customers/${customerId}`); return data }
export async function getPackagePurchaseDetail(id: number): Promise<PackagePurchaseDetail> { const { data } = await api.get<PackagePurchaseDetail>(`/service-packages/purchases/${id}`); return data }
export async function cancelPurchase(id: number): Promise<void> { await api.delete(`/service-packages/purchases/${id}`) }
export async function getPackageSales(from: string, to: string): Promise<PackageSalesResponse> { const { data } = await api.get<PackageSalesResponse>('/service-packages/sales', { params: { from, to } }); return data }
