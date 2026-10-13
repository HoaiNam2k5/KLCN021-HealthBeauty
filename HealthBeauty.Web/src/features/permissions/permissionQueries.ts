import { useQuery, useQueryClient } from '@tanstack/react-query'
import * as permissionsApi from '../../api/permissions'

export const permissionKeys = {
  roles: ['admin-roles'] as const,
  permissions: ['admin-permissions'] as const,
  rolePermissions: (roleId: number) => ['admin-role-permissions', roleId] as const,
}

export function useAdminRoles() {
  return useQuery({ queryKey: permissionKeys.roles, queryFn: permissionsApi.getRoles })
}

export function useAdminPermissions() {
  return useQuery({ queryKey: permissionKeys.permissions, queryFn: permissionsApi.getPermissions })
}

export function useRolePermissions(roleId: number | undefined) {
  return useQuery({
    queryKey: permissionKeys.rolePermissions(roleId ?? 0),
    queryFn: () => permissionsApi.getRolePermissions(roleId as number),
    enabled: roleId !== undefined,
  })
}

export function useReloadRolePermissions() {
  const queryClient = useQueryClient()
  return (roleId: number) => queryClient.invalidateQueries({ queryKey: permissionKeys.rolePermissions(roleId) })
}
