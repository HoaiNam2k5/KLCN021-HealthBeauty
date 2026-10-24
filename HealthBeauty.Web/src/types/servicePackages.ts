export interface ServicePackageItem { id?: number; serviceId: number; serviceName?: string; sessions: number }
export interface ServicePackage { id: number; name: string; price: number; validityDays: number; active: boolean; imageUrl?: string | null; items: ServicePackageItem[] }
export interface ServicePackageRequest { name: string; price: number; validityDays: number; active?: boolean; imageUrl?: string | null; items: { serviceId: number; sessions: number }[] }
export interface CustomerPackageItem { id: number; serviceId: number; serviceName: string; granted: number; reserved: number; used: number; remaining: number; available: number }
export interface CustomerPackage { id: number; servicePackageId: number; customerId: number; customerName?: string; name: string; price: number; status: 'Pending' | 'Paid' | 'Cancelled'; purchasedAt: string; paidAt?: string | null; expiresAt?: string | null; paymentMethod?: string | null; items: CustomerPackageItem[] }
export interface PackageUsageHistoryItem { id: number; appointmentId: number; customerPackageItemId: number; quantity: number; status: 'Reserved' | 'Consumed' | 'Released'; createdAt: string; settledAt?: string | null }
export interface PackagePurchaseRequest { packageId: number; customerId?: number }
export interface PackagePaymentRequest { method: 'TienMat' | 'ChuyenKhoan' | 'The' }
export interface PackagePurchaseDetail { package: CustomerPackage; history: PackageUsageHistoryItem[] }
export interface PackageSalesResponse { from: string; to: string; count: number; revenue: number; items: CustomerPackage[] }
