import { useState } from 'react'
import { App, Button, Col, DatePicker, Form, Image, Input, InputNumber, Modal, Row, Select, Space, Tag, Typography, Upload } from 'antd'
import type { UploadProps } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { uploadImage } from '../../api/services'
import { usePermissions } from '../../hooks/usePermissions'
import type { Combo, ComboRequest } from '../../types/services'
import { useCombos, useDeleteCombo, useSaveCombo, useServices } from './serviceQueries'

const money = (value: number) => `${new Intl.NumberFormat('vi-VN').format(value)} ₫`
const defaultComboImage = 'https://images.unsplash.com/photo-1519823551278-64ac92734fb1?auto=format&fit=crop&w=256&h=192&q=85'
const acceptedTypes = ['image/png', 'image/jpeg', 'image/webp']
interface ComboForm { name: string; price: number; validity: [Dayjs, Dayjs]; items: { serviceId: number; quantity: number }[]; imageUrl?: string | null }

export default function CombosPage() {
  const [form] = Form.useForm<ComboForm>()
  const imageUrl = Form.useWatch('imageUrl', form)
  const [editing, setEditing] = useState<Combo | null>(null)
  const [open, setOpen] = useState(false)
  const [uploading, setUploading] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const { message } = App.useApp()
  const { has } = usePermissions()
  const canManage = has('SERVICE.WRITE')
  const query = useCombos()
  const services = useServices()
  const save = useSaveCombo()
  const remove = useDeleteCombo()
  const data = (query.data ?? []).filter((combo) => (combo.name ?? '').toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase()))
  const serviceName = (id: number) => services.data?.find((service) => service.id === id)?.name ?? `Dịch vụ #${id}`

  function openForm(record?: Combo) {
    if (!canManage) return
    setEditing(record ?? null)
    const validity: [Dayjs, Dayjs] = record ? [dayjs(record.validFrom), dayjs(record.validTo)] : [dayjs(), dayjs().add(1, 'month')]
    form.setFieldsValue({ name: record?.name ?? '', price: record?.price ?? 0, validity, items: record?.items?.map((item) => ({ ...item })) ?? [{ serviceId: undefined as unknown as number, quantity: 1 }], imageUrl: record?.imageUrl ?? '' })
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

  async function submit(values: ComboForm) {
    if (!canManage) return
    const body: ComboRequest = {
      name: values.name, price: values.price,
      validFrom: values.validity[0].format('YYYY-MM-DD'), validTo: values.validity[1].format('YYYY-MM-DD'),
      items: values.items,
      imageUrl: values.imageUrl !== undefined ? (values.imageUrl?.trim() || '') : undefined,
    }
    try { await save.mutateAsync({ id: editing?.id, body }); message.success(editing ? 'Cập nhật combo thành công.' : 'Thêm combo thành công.'); setOpen(false) }
    catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu combo. Vui lòng thử lại.')) }
  }

  async function removeRecord(record: Combo) {
    if (!canManage) return
    try { await remove.mutateAsync(record.id); message.success('Xóa combo thành công.') }
    catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể xóa combo. Vui lòng kiểm tra dữ liệu liên quan.')); throw error }
  }

  return <>
    <ManagementTable<Combo> title="Combo" columns={[
      { title: 'Hình ảnh', key: 'image', render: (_, record) => <Image width={64} height={48} src={record.imageUrl || defaultComboImage} style={{ borderRadius: 8, objectFit: 'cover' }} preview={{ mask: 'Xem' }} alt={record.name ?? 'Combo'} /> },
      { title: 'Tên combo', dataIndex: 'name', key: 'name' },
      { title: 'Giá', dataIndex: 'price', key: 'price', render: money },
      { title: 'Hiệu lực', key: 'validity', render: (_, record) => `${record.validFrom} – ${record.validTo}` },
      { title: 'Dịch vụ thành phần', key: 'items', render: (_, record) => <Space wrap>{(record.items ?? []).map((item) => <Tag key={item.serviceId}>{serviceName(item.serviceId)} × {item.quantity}</Tag>)}</Space> },
    ]} data={data} searchFields={['name']} loading={query.isLoading} error={query.isError} page={page} pageSize={pageSize} onPageChange={(next, size) => { setPageSize(size); setPage(next) }} onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên combo" canManage={canManage} onEdit={openForm} onDelete={removeRecord} onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} toolbar={canManage ? <Button type="primary" onClick={() => openForm()}>Thêm combo</Button> : undefined} />
    <Modal className="responsive-modal" title={editing ? 'Sửa combo' : 'Thêm combo'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending || uploading} okText="Lưu" cancelText="Hủy" width={680}>
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="name" label="Tên combo" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên combo.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="price" label="Giá (₫)" rules={[{ required: true, message: 'Vui lòng nhập giá.' }]}><InputNumber min={0} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="validity" label="Thời gian hiệu lực" rules={[{ required: true, message: 'Vui lòng chọn thời gian hiệu lực.' }]}><DatePicker.RangePicker style={{ width: '100%' }} format="DD/MM/YYYY" /></Form.Item>
        <Form.Item name="imageUrl" label="Link ảnh đại diện combo"><Input placeholder="Dán URL ảnh hoặc tải ảnh lên" /></Form.Item>
        <Upload accept="image/png,image/jpeg,image/webp" showUploadList={false} beforeUpload={beforeUpload as UploadProps['beforeUpload']}><Button loading={uploading}>Tải ảnh lên (Cloudinary)</Button></Upload>
        {imageUrl && <div style={{ marginTop: 12 }}><Space><Typography.Text type="secondary">Xem trước</Typography.Text><Button danger onClick={() => form.setFieldValue('imageUrl', '')}>Xóa ảnh</Button></Space><br /><Image src={imageUrl} width={128} height={96} style={{ objectFit: 'cover', borderRadius: 8 }} fallback={defaultComboImage} /></div>}
        <Form.List name="items" rules={[{ validator: async (_, items: ComboForm['items'] | undefined) => { if (!items?.length) throw new Error('Combo cần ít nhất một dịch vụ.') } }]}>
          {(fields, { add, remove: removeItem }, { errors }) => <><Space direction="vertical" style={{ width: '100%' }}>{fields.map(({ key, name, ...restField }) => <Row key={key} gutter={[12, 0]} align="bottom" className="combo-component-row"><Col xs={24} md={16}><Form.Item {...restField} name={[name, 'serviceId']} label="Dịch vụ" rules={[{ required: true, message: 'Chọn dịch vụ.' }]}><Select style={{ width: '100%' }} placeholder="Chọn dịch vụ" options={(services.data ?? []).map((service) => ({ value: service.id, label: service.name ?? `#${service.id}` }))} /></Form.Item></Col><Col xs={16} md={5}><Form.Item {...restField} name={[name, 'quantity']} label="Số lượng" rules={[{ required: true, message: 'Nhập số lượng.' }]}><InputNumber min={1} precision={0} style={{ width: '100%' }} /></Form.Item></Col><Col xs={8} md={3}><Button danger block style={{ marginBottom: 24 }} onClick={() => removeItem(name)}>Xóa</Button></Col></Row>)}</Space><Form.ErrorList errors={errors} /><Button onClick={() => add({ serviceId: undefined, quantity: 1 })}>Thêm dịch vụ thành phần</Button></>}
        </Form.List>
      </Form>
    </Modal>
  </>
}
