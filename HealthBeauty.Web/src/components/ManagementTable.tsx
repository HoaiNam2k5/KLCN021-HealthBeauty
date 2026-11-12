import { Alert, Empty, Grid, Input, Modal, Pagination, Space, Spin, Table, Typography } from 'antd'
import { useState } from 'react'
import type { TableProps } from 'antd'
import { DeleteOutlined, EditOutlined, SearchOutlined } from '@ant-design/icons'
import type { ReactNode } from 'react'
import type { ColumnsType } from 'antd/es/table'
import axios from 'axios'
import { ActionButton, ActionGrid } from './ActionButton'

interface ManagementTableProps<T extends { id: number }> {
  title: string
  columns: ColumnsType<T>
  data: T[]
  total?: number
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
  deleteLabel?: string
  deleteConfirmation?: string
  className?: string
  scrollX?: number
  fitColumns?: boolean
  renderCard?: (record: T) => ReactNode
}

export default function ManagementTable<T extends { id: number }>({
  title, columns, data, total, searchFields, loading, error, page, pageSize, onPageChange,
  onSearch, searchPlaceholder = 'Tìm kiếm', toolbar, canManage, onEdit, onDelete, onDeleteForbidden, onEditForbidden,
  className = '', scrollX, fitColumns = false, renderCard, deleteLabel = 'Xóa', deleteConfirmation = 'Bạn có chắc chắn muốn thực hiện thao tác này?',
}: ManagementTableProps<T>) {
  const screens = Grid.useBreakpoint()
  const [searchText, setSearchText] = useState('')
  const currentPageSize = pageSize
  const filteredData = onSearch && searchFields?.length && searchText ? data.filter((record) => searchFields.some((field) => String(record[field] ?? '').toLocaleLowerCase().includes(searchText.toLocaleLowerCase()))) : data
  const actions: ColumnsType<T> = canManage ? [{
    title: 'Thao tác', key: 'actions', width: 150, render: (_, record) => (
      <ActionGrid>
        <ActionButton label="Sửa" tone="edit" icon={<EditOutlined />} onClick={() => { try { onEdit(record) } catch { onEditForbidden?.() } }} />
        <ActionButton label={deleteLabel} tone="delete" icon={<DeleteOutlined />} onClick={() => Modal.confirm({
          title: `Xác nhận ${deleteLabel.toLocaleLowerCase()}?`,
          content: deleteConfirmation,
          okText: deleteLabel,
          okType: 'danger',
          cancelText: 'Hủy',
          centered: true,
          async onOk() {
            try { await onDelete(record) }
            catch (error: unknown) {
              if (axios.isAxiosError(error) && error.response?.status === 403) onDeleteForbidden?.()
              throw error
            }
          },
        })} />
      </ActionGrid>
    ),
  }] : []
  const sttColumn: ColumnsType<T> = [{
    title: 'STT',
    key: 'stt',
    width: 65,
    align: 'center',
    render: (_value, _record, index) => (page - 1) * pageSize + index + 1,
  }]
  const tableColumns = [...sttColumn, ...columns, ...actions] as TableProps<T>['columns']

  return (
    <section className={`management-section ${className}`}>
      <div className="page-heading">
        <Typography.Title level={4} style={{ margin: 0 }}>{title}</Typography.Title>
      </div>
        <Space wrap size={10} align="center" className="page-toolbar admin-filter-row">
          {onSearch && <Input allowClear prefix={<SearchOutlined />} placeholder={searchPlaceholder} value={searchText} onChange={(event) => { setSearchText(event.target.value); onSearch(event.target.value) }} className="admin-search" aria-label={searchPlaceholder} />}
          {toolbar}
        </Space>
      {error ? <Alert type="error" showIcon message="Không tải được dữ liệu" description="Vui lòng thử lại sau." /> : renderCard && screens.md === false ? (
        <Spin spinning={loading}>
          <div className="management-card-list">
            {filteredData.length ? filteredData.map((record) => <div key={record.id}>{renderCard(record)}</div>) : <Empty description="Chưa có dữ liệu" />}
          </div>
          <Pagination className="management-card-pagination" current={page} pageSize={pageSize} total={total ?? filteredData.length} showSizeChanger pageSizeOptions={[10, 20, 50, 100]} showTotal={(count) => `Tổng ${count} mục`} onChange={onPageChange} />
        </Spin>
      ) : (
        <div className="table-scroll-container">
        <Table<T>
          scroll={fitColumns ? undefined : { x: scrollX ?? 'max-content' }}
          tableLayout={scrollX || fitColumns ? 'fixed' : undefined}
          rowKey="id"
          columns={tableColumns}
          dataSource={filteredData}
          loading={loading}
          locale={{ emptyText: <Empty description="Chưa có dữ liệu" /> }}
          pagination={{ current: page, pageSize: currentPageSize, total: total ?? filteredData.length, showSizeChanger: true, pageSizeOptions: [10, 20, 50, 100], showTotal: (count) => `Tổng ${count} mục`, onChange: (next, filters) => { onPageChange(next, filters) } }}
        />
        </div>
      )}
    </section>
  )
}
