import { useState } from 'react'
import { Alert, Button } from 'antd'
import ManagementTable from '../../components/ManagementTable'
import { getApiErrorMessage } from '../../components/apiError'
import type { Customer } from '../../types/customersStaff'
import { useCustomers } from './customerStaffQueries'

export default function CustomersPage() {
  const [page, setPage] = useState(1)
  const [pageSize, setPageSize] = useState(10)
  const [keyword, setKeyword] = useState('')
  const query = useCustomers(keyword)

  return <>
    {query.isError && <Alert type="error" showIcon message="Không tải được danh sách khách hàng" description={getApiErrorMessage(query.error, 'Vui lòng thử lại sau.')} style={{ marginBottom: 16 }} />}
    <ManagementTable<Customer>
      title="Khách hàng"
      columns={[
        { title: 'Họ tên', dataIndex: 'fullName', key: 'fullName', render: (value: string | null) => value || '—' },
        { title: 'Số điện thoại', dataIndex: 'phone', key: 'phone', render: (value: string | null) => value || '—' },
        { title: 'Giới tính', dataIndex: 'gender', key: 'gender', render: (value: string | null) => value || '—' },
        { title: 'Điểm thưởng', dataIndex: 'rewardPoints', key: 'rewardPoints', render: (value: number) => value.toLocaleString('vi-VN') },
      ]}
      data={query.data ?? []} searchFields={['fullName', 'phone']} loading={query.isLoading} error={query.isError}
      page={page} pageSize={pageSize} onPageChange={(next, size) => { setPage(next); setPageSize(size) }}
      onSearch={(value) => { setKeyword(value); setPage(1) }} searchPlaceholder="Tìm theo tên hoặc số điện thoại"
      // TODO: chờ backend thêm PUT /customers/{id} trước khi gắn nút Sửa.
      canManage={false} onEdit={() => undefined} onDelete={() => undefined}
      toolbar={<Button disabled title="TODO: chờ backend thêm PUT /customers/{id}">Sửa khách hàng</Button>}
    />
  </>
}
