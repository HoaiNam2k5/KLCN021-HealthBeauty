import { useState } from 'react'
import { App as AntApp, Button, Form, Input, Modal } from 'antd'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import { usePermissions } from '../../hooks/usePermissions'
import type { CategoryRequest, ServiceCategory } from '../../types/services'
import { useCategories, useDeleteCategory, useSaveCategory } from './serviceQueries'

export default function ServiceCategoriesPage() {
  const [form] = Form.useForm<CategoryRequest>()
  const [editing, setEditing] = useState<ServiceCategory | null>(null)
  const [open, setOpen] = useState(false)
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const { message } = AntApp.useApp()
  const { has } = usePermissions()
  const canManage = has('SERVICE.WRITE')
  const query = useCategories()
  const save = useSaveCategory()
  const remove = useDeleteCategory()
  const data = (query.data ?? []).filter((category) => (category.name ?? '').toLocaleLowerCase().includes(keyword.trim().toLocaleLowerCase()))

  function openForm(record?: ServiceCategory) {
    if (!canManage) return
    setEditing(record ?? null)
    form.setFieldsValue(record ? { name: record.name, description: record.description } : { name: null, description: null })
    setOpen(true)
  }

  async function submit(values: CategoryRequest) {
    if (!canManage) return
    try {
      await save.mutateAsync({ id: editing?.id, body: values })
      message.success(editing ? 'Cập nhật loại dịch vụ thành công.' : 'Thêm loại dịch vụ thành công.')
      setOpen(false)
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể lưu loại dịch vụ. Vui lòng thử lại.'))
    }
  }

  async function removeRecord(record: ServiceCategory) {
    if (!canManage) return
    try {
      await remove.mutateAsync(record.id)
      message.success('Xóa loại dịch vụ thành công.')
    } catch (error: unknown) {
      message.error(getApiErrorMessage(error, 'Không thể xóa loại dịch vụ. Vui lòng kiểm tra dữ liệu liên quan.'))
      throw error
    }
  }

  return <>
    <ManagementTable<ServiceCategory>
      title="Loại dịch vụ" columns={[
        { title: 'Tên loại', dataIndex: 'name', key: 'name' },
        { title: 'Mô tả', dataIndex: 'description', key: 'description', render: (value: string | null) => value || '—' },
      ]} data={data} searchFields={['name']} loading={query.isLoading} error={query.isError} page={page} pageSize={pageSize}
      onPageChange={(next, size) => { setPageSize(size); setPage(next) }} onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên loại dịch vụ" canManage={canManage} onEdit={openForm} onDelete={removeRecord}
      onDeleteForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')} onEditForbidden={() => message.error('Bạn không có quyền thực hiện thao tác này')}
      toolbar={canManage ? <Button type="primary" onClick={() => openForm()}>Thêm loại dịch vụ</Button> : undefined}
    />
    <Modal className="responsive-modal" title={editing ? 'Sửa loại dịch vụ' : 'Thêm loại dịch vụ'} open={open && canManage} onCancel={() => setOpen(false)} onOk={() => form.submit()} confirmLoading={save.isPending} okText="Lưu" cancelText="Hủy">
      <Form className="responsive-form" form={form} layout="vertical" onFinish={submit}>
        <Form.Item name="name" label="Tên loại" rules={[{ required: true, whitespace: true, message: 'Vui lòng nhập tên loại.' }]}><Input maxLength={150} /></Form.Item>
        <Form.Item name="description" label="Mô tả"><Input.TextArea rows={3} maxLength={500} /></Form.Item>
      </Form>
    </Modal>
  </>
}
