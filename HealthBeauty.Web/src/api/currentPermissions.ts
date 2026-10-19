import api from './client'
import { parseCurrentPermissions, type CurrentPermissions } from '../utils/permissionPolicy'

export async function getCurrentPermissions(signal?: AbortSignal): Promise<CurrentPermissions> {
  const { data } = await api.get<unknown>('/auth/permissions', { signal })
  return parseCurrentPermissions(data)
}
