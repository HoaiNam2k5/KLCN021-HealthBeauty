import { useState } from 'react'
import { App, Button, Form, Image, Input, InputNumber, Modal, Select, Space, Typography, Upload } from 'antd'
import type { UploadProps } from 'antd'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { Service, ServiceRequest } from '../../types/services'
import { uploadImage } from '../../api/services'
import { useCategories, useDeleteService, useSaveService, useServices } from './serviceQueries'

const money = (value: number) => `${new Intl.NumberFormat('vi-VN').format(value)} ₫`
const defaultServiceImage = (name: string, category: string) => {
  const text = `${category} ${name}`.toLocaleLowerCase()
  const photo = /massage|body|relax|thư giãn/.test(text) ? 'photo-1540555700478-4be289fbecef' : /nail|móng/.test(text) ? 'photo-1604654894610-df63bc536371' : /gội|hair|tóc/.test(text) ? 'photo-1522337360788-8b13dee7a37e' : /combo/.test(text) ? 'photo-1519823551278-64ac92734fb1' : 'photo-1570172619644-dfd03ed5d881'
  return `https://images.unsplash.com/${photo}?auto=format&fit=crop&w=240&h=240&q=85`
}
const acceptedTypes = ['image/png', 'image/jpeg', 'image/webp']

export default function ServicesPage() {
  const [form] = Form.useForm<ServiceRequest>()
  const imageUrl = Form.useWatch('imageUrl', form)
  const [editing, setEditing] = useState<Service | null>(null)
  const [open, setOpen] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [categoryId, setCategoryId] = useState<number | undefined>()
  const { message } = App.useApp()
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
    form.setFieldsValue(record ? { categoryId: record.categoryId, name: record.name, price: record.price, durationMinutes: record.durationMinutes, description: record.description, imageUrl: record.imageUrl ?? '' } : { categoryId: undefined as unknown as number, name: null, price: 0, durationMinutes: 30, description: null, imageUrl: '' })
    setOpen(true)
  }

  async function beforeUpload(file: File) {
    if (!acceptedTypes.includes(file.type)) { message.error('Chỉ hỗ trợ ảnh PNG, JPEG hoặc WebP.'); return false }
    if (file.size > 5 * 1024 * 1024) { message.error('Kích thước ảnh tối đa là 5MB.'); return false }
    setUploading(true)
    try { const uploaded = await uploadImage(file); form.setFieldValue('imageUrl', uploaded.imageUrl); message.success('Tải ảnh lên Cloudinary thành công.') }
    catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể tải ảnh lên.')) }
    finally { setUploading(false) }
    return false
  }

  async function submit(values: ServiceRequest) {
    if (!canManage) return
    try {
      const body: ServiceRequest = { ...values, imageUrl: values.imageUrl !== undefined ? (values.imageUrl?.trim() || '') : undefined }
      await save.mutateAsync({ id: editing?.id, body })
      message.success(editing ? 'Cập nhật dịch vụ thành công.' : 'Thêm dịch vụ thành công.')
      setOpen(false)
    } catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu dịch vụ. Vui lòng thử lại.')) }
  }

  async function removeRecord(record: Service) {
    if (!canManage) return
    try { await remove.mutateAsync(record.id); message.success('Xóa dịch vụ thành công.') }
    catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể xóa dịch vụ. Vui lòng kiểm tra dữ liệu liên quan.')); throw error }
  }

  return <>
    <ManagementTable<Service> title="Dịch vụ" columns={[
      { title: 'Hình ảnh', key: 'image', render: (_, record) => { const category = categories.data?.find((item) => item.id === record.categoryId)?.name ?? ''; return <Image width={64} height={48} src={record.imageUrl || defaultServiceImage(record.name ?? '', category)} style={{ borderRadius: 8, objectFit: 'cover' }} preview={{ mask: 'Xem' }} alt={record.name ?? 'Dịch vụ'} /> } },
      { title: 'Tên dịch vụ', dataIndex: 'name', key: 'name' },
      { title: 'Danh mục', key: 'category', render: (_, record) => categories.data?.find((item) => item.id === record.categoryId)?.name ?? `#${record.categoryId}` },
      { title: 'Giá', dataIndex: 'price', key: 'price', render: money },
      { title: 'Thời lượng', dataIndex: 'durationMinutes', key: 'durationMinutes', render: (value: number) => `${value} phút` },
      { title: 'Mô tả', dataIndex: 'description', key: 'description' },
    ]} data={data.filter((item) => categoryId === undefined || item.categoryId === categoryId)} searchFields={['name', 'description']} loading={query.isLoading} error={query.isError} page={page} pageSize={pageSize} onPageChange={(next, size) => { setPageSize(size); setPage(next) }} onSearch={() => setPage(1)} canManage={canManage} onEdit={openForm} onDelete={removeRecord} toolbar={canManage ? <><Select allowClear placeholder="Danh mục" value={categoryId} onChange={(value) => { setCategoryId(value); setPage(1) }} options={(categories.data ?? []).map((item) => ({ value: item.id, label: item.name ?? `#${item.id}` }))} style={{ minWidth: 180 }} /><Button type="primary" onClick={() => openForm()}>Thêm dịch vụ</Button></> : undefined} />
    <Modal className="responsive-modal" title={editing ? 'Sửa dịch vụ' : 'Thêm dịch vụ'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending || uploading} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="name" label="Tên dịch vụ" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên dịch vụ.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="categoryId" label="Danh mục" rules={[{ required: true, message: 'Vui lòng chọn danh mục.' }]}><Select options={(categories.data ?? []).map((item) => ({ value: item.id, label: item.name ?? `#${item.id}` }))} /></Form.Item>
        <Form.Item name="price" label="Giá (₫)" rules={[{ required: true }]}><InputNumber min={0} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="durationMinutes" label="Thời lượng (phút)" rules={[{ required: true }]}><InputNumber min={1} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="description" label="Mô tả"><Input.TextArea rows={3} /></Form.Item>
        <Form.Item name="imageUrl" label="Link ảnh đại diện"><Input placeholder="Dán URL ảnh hoặc tải ảnh lên" /></Form.Item>
        <Upload accept="image/png,image/jpeg,image/webp" showUploadList={false} beforeUpload={beforeUpload as UploadProps['beforeUpload']}><Button loading={uploading}>Tải ảnh lên (Cloudinary)</Button></Upload>
        {imageUrl && <div style={{ marginTop: 12 }}><Space><Typography.Text type="secondary">Xem trước</Typography.Text><Button danger onClick={() => form.setFieldValue('imageUrl', '')}>Xóa ảnh</Button></Space><br /><Image src={imageUrl} width={128} height={96} style={{ objectFit: 'cover', borderRadius: 8 }} /></div>}
      </Form>
    </Modal>
  </>
}
