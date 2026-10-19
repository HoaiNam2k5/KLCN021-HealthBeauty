import { useQuery } from '@tanstack/react-query'
import { getCurrentPermissions } from '../api/currentPermissions'
import { canVisitRoute, hasPermission, supportsPermission } from '../utils/permissionPolicy'
import { useAuth } from './useAuth'

export const currentPermissionKeys = { all: ['current-permissions'] as const }

export function usePermissions() {
  const session = useAuth()
  const accountId = session?.account?.id
  const query = useQuery({
    queryKey: [...currentPermissionKeys.all, accountId],
    queryFn: ({ signal }) => getCurrentPermissions(signal),
    enabled: accountId !== undefined,
    staleTime: 5000,
    refetchInterval: 30000,
    refetchOnWindowFocus: 'always',
    retry: 1,
  })
  // Failed reads and initial loading grant no access, including for Admin.
  const permissions: readonly string[] = query.isError ? [] : query.data?.permissions ?? []
  const role = query.isError ? null : query.data?.role ?? session?.account?.role ?? null
  return {
    role,
    permissions,
    has: (code: string) => supportsPermission(role, code) && hasPermission(permissions, code),
    canVisit: (path: string) => canVisitRoute(path, role, permissions),
    isLoading: accountId !== undefined && query.isPending,
    isError: query.isError,
    refetch: query.refetch,
  }
}
