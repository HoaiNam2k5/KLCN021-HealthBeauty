import { useState } from 'react'
import { App as AntApp, Button, Form, Input, InputNumber, Modal, Select, Space } from 'antd'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Service, ServiceRequest } from '../../types/services'
import { useCategories, useDeleteService, useSaveService, useServices } from './serviceQueries'

const money = (value: number) => `${new Intl.NumberFormat('vi-VN').format(value)} ₫`

export default function ServicesPage() {
  const [form] = Form.useForm<ServiceRequest>()
  const [editing, setEditing] = useState<Service | null>(null)
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [categoryId, setCategoryId] = useState<number | undefined>()
  const { message } = AntApp.useApp()
  const { has } = usePermissions()
  const canManage = has('SERVICE.WRITE')
  const categories = useCategories()
  const query = useServices()
  const save = useSaveService()
  const remove = useDeleteService()
  const data = query.data ?? []

  function openForm(record?: Service) {
    if (!canManage) return
    setEditing(record ?? null)
    form.setFieldsValue(record ? { categoryId: record.categoryId, name: record.name, price: record.price, durationMinutes: record.durationMinutes, description: record.description } : { categoryId: undefined, name: null, price: 0, durationMinutes: 30, description: null })
    setOpen(true)
  }

  async function submit(values: ServiceRequest) {
    if (!canManage) return
    try {
      await save.mutateAsync({ id: editing?.id, body: values })
      message.success(editing ? 'Cập nhật dịch vụ thành công.' : 'Thêm dịch vụ thành công.')
      setOpen(false)
    } catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu dịch vụ. Vui lòng thử lại.')) }
  }

  async function removeRecord(record: Service) {
    if (!canManage) return
    try {
      await remove.mutateAsync(record.id)
      message.success('Xóa dịch vụ thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa dịch vụ. Vui lòng kiểm tra dữ liệu liên quan.'))
      throw error
    }
  }

  return <>
    <ManagementTable<Service>
      title="Dịch vụ" columns={[
        { title: 'Tên dịch vụ', dataIndex: 'name', key: 'name' },
        { title: 'Loại dịch vụ', dataIndex: 'categoryId', key: 'categoryId', render: (id: number) => categories.data?.find((item) => item.id === id)?.name ?? `#${id}` },
        { title: 'Giá', dataIndex: 'price', key: 'price', render: (value: number) => money(value) },
        { title: 'Thời lượng', dataIndex: 'durationMinutes', key: 'durationMinutes', render: (value: number) => `${value} phút` },
        { title: 'Mô tả', dataIndex: 'description', key: 'description', render: (value: string | null) => value || '—' },
      ]} data={data.filter((service) => categoryId === undefined || service.categoryId === categoryId)} searchFields={['name']} loading={query.isLoading} error={query.isError} page={page} pageSize={pageSize}
      onPageChange={(next, size) => { setPageSize(size); setPage(next) }} onSearch={() => setPage(1)} searchPlaceholder="Tìm theo tên dịch vụ" canManage={canManage} onEdit={openForm} onDelete={removeRecord}
      onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      toolbar={<Space className="filter-bar" wrap>
        <Select allowClear placeholder="Tất cả loại" style={{ width: 190, maxWidth: '100%' }} value={categoryId} onChange={(value) => { setCategoryId(value); setPage(1) }} options={(categories.data ?? []).map((item) => ({ value: item.id, label: item.name ?? `#${item.id}` }))} />
        {canManage && <Button type="primary" onClick={() => openForm()}>Thêm dịch vụ</Button>}
      </Space>}
    />
    <Modal className="responsive-modal" title={editing ? 'Sửa dịch vụ' : 'Thêm dịch vụ'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="name" label="Tên dịch vụ" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên dịch vụ.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="categoryId" label="Loại dịch vụ" rules={[{ required: true, message: 'Vui lòng chọn loại dịch vụ.' }]}><Select options={(categories.data ?? []).map((item) => ({ value: item.id, label: item.name ?? `#${item.id}` }))} /></Form.Item>
        <Form.Item name="price" label="Giá (₫)" rules={[{ required: true, message: 'Vui lòng nhập giá.' }]}><InputNumber min={0} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="durationMinutes" label="Thời lượng (phút)" rules={[{ required: true, message: 'Vui lòng nhập thời lượng.' }]}><InputNumber min={1} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="description" label="Mô tả"><Input.TextArea rows={3} maxLength={500} /></Form.Item>
      </Form>
    </Modal>
  </>
}
