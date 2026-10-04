import { useState } from 'react'
import { App as AntApp, Button, DatePicker, Form, Input, InputNumber, Modal, Select, Space, Tag } from 'antd'
import dayjs, { type Dayjs } from 'dayjs'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { useAuth } from '../../hooks/useAuth'
import { ACCOUNT_ROLES } from '../../constants/roles'
import type { Combo, ComboRequest } from '../../types/services'
import { useCombos, useDeleteCombo, useSaveCombo, useServices } from './serviceQueries'

const money = (value: number) => `${new Intl.NumberFormat('vi-VN').format(value)} ₫`
interface ComboForm { name: string; price: number; validity: [Dayjs, Dayjs]; items: { serviceId: number; quantity: number }[] }

export default function CombosPage() {
  const [form] = Form.useForm<ComboForm>()
  const [editing, setEditing] = useState<Combo | null>(null)
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const { message } = AntApp.useApp()
  const role = useAuth()?.account?.role
  const canManage = role === ACCOUNT_ROLES.ADMIN || role === ACCOUNT_ROLES.MANAGER
  const query = useCombos()
  const services = useServices()
  const save = useSaveCombo()
  const remove = useDeleteCombo()
  const data = query.data ?? []
  const serviceName = (id: number) => services.data?.find((service) => service.id === id)?.name ?? `Dịch vụ #${id}`

  function openForm(record?: Combo) {
    setEditing(record ?? null)
    const validity = record ? [dayjs(record.validFrom), dayjs(record.validTo)] as [Dayjs, Dayjs] : [dayjs(), dayjs().add(1, 'month')] as [Dayjs, Dayjs]
    form.setFieldsValue({ name: record?.name ?? '', price: record?.price ?? 0, validity, items: record?.items?.map((item) => ({ ...item })) ?? [{ serviceId: 0, quantity: 1 }] })
    setOpen(true)
  }

  async function submit(values: ComboForm) {
    const body: ComboRequest = {
      name: values.name,
      price: values.price,
      validFrom: values.validity[0].format('YYYY-MM-DD'),
      validTo: values.validity[1].format('YYYY-MM-DD'),
      items: values.items,
    }
    try {
      await save.mutateAsync({ id: editing?.id, body })
      message.success(editing ? 'Cập nhật combo thành công.' : 'Thêm combo thành công.')
      setOpen(false)
    } catch (error: unknown) { message.error(getApiErrorMessage(error, 'Không thể lưu combo. Vui lòng thử lại.')) }
  }

  async function removeRecord(record: Combo) {
    try {
      await remove.mutateAsync(record.id)
      message.success('Xóa combo thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa combo. Vui lòng kiểm tra dữ liệu liên quan.'))
      throw error
    }
  }

  return <>
    <ManagementTable<Combo>
      title="Combo" columns={[
        { title: 'Tên combo', dataIndex: 'name', key: 'name' },
        { title: 'Giá', dataIndex: 'price', key: 'price', render: (value: number) => money(value) },
        { title: 'Hiệu lực', key: 'validity', render: (_, record) => `${record.validFrom} – ${record.validTo}` },
        { title: 'Dịch vụ thành phần', key: 'items', render: (_, record) => <Space wrap>{(record.items ?? []).map((item) => <Tag key={item.serviceId}>{serviceName(item.serviceId)} × {item.quantity}</Tag>)}</Space> },
      ]} data={data} searchFields={['name']} loading={query.isLoading} error={query.isError} page={page} pageSize={pageSize}
      onPageChange={(next, size) => { setPageSize(size); setPage(next) }} canManage={canManage} onEdit={openForm} onDelete={removeRecord}
      onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      toolbar={canManage ? <Button type="primary" onClick={() => openForm()}>Thêm combo</Button> : undefined}
    />
    <Modal title={editing ? 'Sửa combo' : 'Thêm combo'} open={open} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy" width={680}>
      <Form form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="name" label="Tên combo" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên combo.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="price" label="Giá (₫)" rules={[{ required: true, message: 'Vui lòng nhập giá.' }]}><InputNumber min={0} precision={0} style={{ width: '100%' }} /></Form.Item>
        <Form.Item name="validity" label="Thời gian hiệu lực" rules={[{ required: true, message: 'Vui lòng chọn thời gian hiệu lực.' }]}><DatePicker.RangePicker style={{ width: '100%' }} format="DD/MM/YYYY" /></Form.Item>
        <Form.List name="items" rules={[{ validator: async (_, items: ComboForm['items'] | undefined) => { if (!items?.length) throw new Error('Combo cần ít nhất một dịch vụ.') } }]}>
          {(fields, { add, remove: removeItem }, { errors }) => <>
            <Space direction="vertical" style={{ width: '100%' }}>
              {fields.map(({ key, name, ...restField }) => <Space key={key} align="baseline" style={{ width: '100%' }}>
                <Form.Item {...restField} name={[name, 'serviceId']} label="Dịch vụ" rules={[{ required: true, message: 'Chọn dịch vụ.' }]}>
                  <Select style={{ width: 360 }} placeholder="Chọn dịch vụ" options={(services.data ?? []).map((service) => ({ value: service.id, label: service.name ?? `#${service.id}` }))} />
                </Form.Item>
                <Form.Item {...restField} name={[name, 'quantity']} label="Số lượng" rules={[{ required: true, message: 'Nhập số lượng.' }]}><InputNumber min={1} precision={0} /></Form.Item>
                <Button danger onClick={() => removeItem(name)}>Xóa</Button>
              </Space>)}
            </Space>
            <Form.ErrorList errors={errors} />
            <Button onClick={() => add({ serviceId: undefined, quantity: 1 })}>Thêm dịch vụ thành phần</Button>
          </>}
        </Form.List>
      </Form>
    </Modal>
  </>
}
