import api from './client'
import type { AdminPermission, AdminRole, RolePermission, RolePermissionRequest } from '../types/permissions'

export async function getRoles(): Promise<AdminRole[]> {
  const { data } = await api.get<unknown>('/admin/roles')
  return Array.isArray(data) ? data as AdminRole[] : []
}

export async function getPermissions(): Promise<AdminPermission[]> {
  const { data } = await api.get<unknown>('/admin/permissions')
  return Array.isArray(data) ? data as AdminPermission[] : []
}

export async function getRolePermissions(roleId: number): Promise<RolePermission[]> {
  const { data } = await api.get<unknown>(`/admin/roles/${roleId}/permissions`)
  return Array.isArray(data) ? data as RolePermission[] : []
}

export async function updateRolePermission(roleId: number, body: RolePermissionRequest): Promise<void> {
  await api.put(`/admin/roles/${roleId}/permissions/${body.permissionId}`, body)
}
