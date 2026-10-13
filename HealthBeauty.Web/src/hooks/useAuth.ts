import { useSyncExternalStore } from 'react'
import { getSession, subscribeSession } from '../api/session'

export function useAuth() {
  return useSyncExternalStore(subscribeSession, getSession, getSession)
}
