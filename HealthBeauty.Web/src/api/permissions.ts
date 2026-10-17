import api from './client'
import type { AdminPermission, AdminRole, RolePermission, RolePermissionRequest } from '../types/permissions'

interface RoleDto { vaiTroId: number; tenVaiTro: string }
interface PermissionDto { quyenId: number; tenQuyen: string; maQuyen: string; nhomQuyen: string; moTa?: string | null; trangThai?: boolean; granted?: boolean }
const mapPermission = (item: PermissionDto): AdminPermission => ({
  permissionId: item.quyenId, tenQuyen: item.tenQuyen, maQuyen: item.maQuyen,
  nhomQuyen: item.nhomQuyen, moTa: item.moTa ?? null, active: item.trangThai ?? true,
})

export async function getRoles(): Promise<AdminRole[]> {
  const { data } = await api.get<RoleDto[]>('/admin/roles')
  return data.map((item) => ({ roleId: item.vaiTroId, tenVaiTro: item.tenVaiTro }))
}

export async function getPermissions(): Promise<AdminPermission[]> {
  const { data } = await api.get<PermissionDto[]>('/admin/permissions')
  return data.map(mapPermission)
}

export async function getRolePermissions(roleId: number): Promise<RolePermission[]> {
  const { data } = await api.get<PermissionDto[]>(`/admin/roles/${roleId}/permissions`)
  return data.map((item) => ({ ...mapPermission(item), granted: item.granted ?? false }))
}

export async function updateRolePermission(roleId: number, body: RolePermissionRequest): Promise<void> {
  await api.put(`/admin/roles/${roleId}/permissions/${body.permissionId}`, body)
}
