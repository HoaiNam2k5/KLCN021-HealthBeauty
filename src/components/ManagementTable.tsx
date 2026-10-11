import { Alert, Button, Empty, Input, Popconfirm, Space, Table, Typography } from 'antd'
import { useState } from 'react'
import type { TableProps } from 'antd'
import { SearchOutlined } from '@ant-design/icons'
import type { ReactNode } from 'react'
import type { ColumnsType } from 'antd/es/table'
import axios from 'axios'

interface ManagementTableProps<T extends { id: number }> {
  title: string
  columns: ColumnsType<T>
  data: T[]
  searchFields?: (keyof T)[]
  onSearch?: (value: string) => void
  searchPlaceholder?: string
  loading: boolean
  error: boolean
  page: number
  pageSize: number
  onPageChange: (page: number, pageSize: number) => void
  onDeleteForbidden?: () => void
  onEditForbidden?: () => void
  toolbar?: ReactNode
  canManage: boolean
  onEdit: (record: T) => void
  onDelete: (record: T) => void
}

export default function ManagementTable<T extends { id: number }>({
  title, columns, data, searchFields, loading, error, page, pageSize, onPageChange,
  onSearch, searchPlaceholder = 'Tìm kiếm', toolbar, canManage, onEdit, onDelete, onDeleteForbidden, onEditForbidden,
}: ManagementTableProps<T>) {
  const [searchText, setSearchText] = useState('')
  const [currentPageSize, setCurrentPageSize] = useState(pageSize)
  const filteredData = onSearch && searchText ? data.filter((record) => (searchFields ?? []).some((field) => String(record[field] ?? '').toLocaleLowerCase().includes(searchText.toLocaleLowerCase()))) : data
  const actions: ColumnsType<T> = canManage ? [{
    title: 'Thao tác', key: 'actions', width: 150, render: (_, record) => (
      <Space size="small">
        <Button type="link" onClick={() => { try { onEdit(record) } catch { onEditForbidden?.() } }}>Sửa</Button>
        <Popconfirm title="Xác nhận xóa mục này?" description="Thao tác này không thể hoàn tác." okText="Xóa" cancelText="Hủy" onConfirm={async () => { try { await onDelete(record) } catch (error: unknown) { if (axios.isAxiosError(error) && error.response?.status === 403) onDeleteForbidden?.() } }}>
          <Button type="link" danger>Xóa</Button>
        </Popconfirm>
      </Space>
    ),
  }] : []
  const tableColumns = [...columns, ...actions] as TableProps<T>['columns']

  return (
    <section>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 16, marginBottom: 20, flexWrap: 'wrap' }}>
        <Typography.Title level={4} style={{ margin: 0 }}>{title}</Typography.Title>
        <Space wrap>
          {onSearch && <Input allowClear prefix={<SearchOutlined />} placeholder={searchPlaceholder} value={searchText} onChange={(event) => { setSearchText(event.target.value); onSearch(event.target.value) }} style={{ width: 260 }} />}
          {toolbar}
        </Space>
      </div>
      {error ? <Alert type="error" showIcon message="Không tải được dữ liệu" description="Vui lòng thử lại sau." /> : (
        <div className="table-scroll-container">
        <Table<T>
          scroll={{ x: 'max-content' }}
          rowKey="id"
          columns={tableColumns}
          dataSource={filteredData}
          loading={loading}
          locale={{ emptyText: <Empty description="Chưa có dữ liệu" /> }}
          pagination={{ current: page, pageSize: currentPageSize, total: filteredData.length, showSizeChanger: true, pageSizeOptions: [10, 20, 50, 100], showTotal: (count) => `Tổng ${count} mục`, onChange: (next, filters) => { setCurrentPageSize(filters); onPageChange(next, filters) } }}
        />
        </div>
      )}
    </section>
  )
}
