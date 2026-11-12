import { Button } from 'antd'
import type { ButtonProps } from 'antd'
import { forwardRef, type ReactNode } from 'react'

type ActionTone = 'edit' | 'delete' | 'view' | 'confirm' | 'toggle' | 'print'

export function ActionGrid({ children }: { children: ReactNode }) {
  return <div className="action-grid">{children}</div>
}

export const ActionButton = forwardRef<HTMLButtonElement, ButtonProps & { label: string; tone?: ActionTone }>(function ActionButton({ label, tone = 'view', ...props }, ref) {
  return <Button {...props} ref={ref} className={`action-icon action-icon--${tone} ${props.className ?? ''}`} aria-label={label} title={label} />
})
