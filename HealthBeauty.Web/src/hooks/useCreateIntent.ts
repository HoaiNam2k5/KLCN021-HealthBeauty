import { useState } from 'react'
import { useSearchParams } from 'react-router-dom'

// A URL intent remains declarative while permissions load. Closing consumes it,
// preserving the page's other query parameters and normal local create buttons.
export function useCreateIntent(canCreate: boolean) {
  const [params, setParams] = useSearchParams()
  const [localOpen, setLocalOpen] = useState(false)
  const requested = params.get('action') === 'create'
  const open = canCreate && (localOpen || requested)
  const setOpen = (next: boolean) => {
    if (next && !canCreate) return
    setLocalOpen(next)
    if (!next && requested) {
      const remaining = new URLSearchParams(params)
      remaining.delete('action')
      setParams(remaining, { replace: true })
    }
  }
  return [open, setOpen] as const
}
