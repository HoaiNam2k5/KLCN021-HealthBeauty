import { useState } from 'react'
import { Button, Modal, Typography } from 'antd'

export default function DescriptionDetails({ value }: { value: string | null | undefined }) {
  const [open, setOpen] = useState(false)
  if (!value?.trim()) return <span>—</span>
  return <>
    <Button type="link" className="description-detail-button" onClick={() => setOpen(true)}>Xem chi tiết</Button>
    <Modal title="Mô tả" open={open} onCancel={() => setOpen(false)} footer={<Button type="primary" onClick={() => setOpen(false)}>Đóng</Button>}>
      <Typography.Paragraph style={{ whiteSpace: 'pre-wrap', overflowWrap: 'anywhere', marginBottom: 0 }}>{value}</Typography.Paragraph>
    </Modal>
  </>
}
