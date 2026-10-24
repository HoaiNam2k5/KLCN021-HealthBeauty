import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const toModuleUrl = (source) => {
  const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
  return `data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`
}
const readSource = (path) => readFile(new URL(path, import.meta.url), 'utf8')
const labels = await import(toModuleUrl(await readSource('../src/utils/displayLabels.ts')))
const messageUrl = toModuleUrl(await readSource('../src/utils/apiMessages.ts'))
const { translateApiMessage } = await import(messageUrl)
const errorSource = (await readSource('../src/components/apiError.ts'))
  .replace("from 'axios'", `from '${import.meta.resolve('axios')}'`)
  .replace("from '../utils/apiMessages'", `from '${messageUrl}'`)
const { getApiErrorMessage } = await import(toModuleUrl(errorSource))
const fallback = 'Không thể thực hiện thao tác. Vui lòng thử lại.'
const apiError = (data, status = 400) => ({ isAxiosError: true, response: { status, data } })

test('audit activities, including password and staff account events, have Vietnamese labels', () => {
  for (const action of ['AccountCreated', 'AccountRoleChanged', 'AccountActivated', 'AccountDeactivated',
    'PermissionGranted', 'PermissionRevoked', 'StaffAccountCreated', 'PasswordReset']) {
    assert.match(labels.getAuditActionLabel(action), /[À-ỹĐđ]/u)
  }
  assert.equal(labels.getAuditActionLabel('PermissionGranted'), 'Cấp quyền')
  assert.equal(labels.getAuditEntityLabel('VAITRO_QUYEN'), 'Quyền của vai trò')
  assert.equal(labels.getAuditActionLabel('FutureEnglishAction'), 'Hoạt động khác')
  assert.equal(labels.getAuditEntityLabel(null), '—')
})

test('roles, permission groups, package states and point transactions never show raw API codes', () => {
  assert.deepEqual(['Admin', 'Manager', 'Reception', 'Staff', 'Customer'].map(labels.getRoleLabel),
    ['Quản trị viên', 'Quản lý', 'Lễ tân', 'Nhân viên', 'Khách hàng'])
  assert.equal(labels.getPermissionGroupLabel('AUTHORIZATION'), 'Phân quyền')
  assert.equal(labels.getPackageStatusLabel('Pending'), 'Chờ thu tiền')
  assert.equal(labels.getPackageStatusLabel('Paid'), 'Đã thanh toán')
  assert.equal(labels.getPackageStatusLabel('Cancelled'), 'Đã hủy')
  assert.equal(labels.getPointTransactionLabel('DoiVoucher'), 'Đổi điểm lấy phiếu giảm giá')
  assert.equal(labels.getRoleLabel('NewRole'), 'Vai trò chưa xác định')
  assert.equal(labels.getPackageStatusLabel('UnknownStatus'), 'Trạng thái chưa xác định')
})

test('package payment and voucher conflicts are translated with actionable messages', () => {
  assert.equal(getApiErrorMessage(apiError('Purchase is already paid or cancelled.', 409), fallback), 'Phiếu mua đã được thanh toán hoặc đã hủy.')
  assert.equal(getApiErrorMessage(apiError('Assigned voucher ownership and point cost cannot be changed.', 409), fallback),
    'Không thể đổi chủ sở hữu hoặc số điểm đổi của phiếu giảm giá đã cấp.')
  assert.equal(getApiErrorMessage(apiError('Package session balance changed. Reload availability.', 409), fallback),
    'Số lượt còn lại trong gói đã thay đổi. Vui lòng tải lại.')
})

test('validation details take precedence over generic English problem titles', () => {
  assert.equal(getApiErrorMessage(apiError({ title: 'One or more validation errors occurred.', errors: {
    name: ['Tên gói không được để trống.'], price: ['Giá bán phải lớn hơn 0.'],
  } }), fallback), 'Tên gói không được để trống. Giá bán phải lớn hơn 0.')
  assert.equal(getApiErrorMessage(apiError({ title: 'Bad Request', detail: 'Services must exist and be active.' }), fallback), 'Dịch vụ phải tồn tại và đang hoạt động.')
  assert.equal(getApiErrorMessage(apiError({ errors: { name: ['The Name field is required.'] } }), fallback), fallback)
})

test('unmapped English and network/authentication errors stay in Vietnamese', () => {
  assert.equal(translateApiMessage('Unexpected backend failure', fallback), fallback)
  assert.equal(translateApiMessage('  Lịch hẹn đã có hóa đơn.  ', fallback), 'Lịch hẹn đã có hóa đơn.')
  assert.equal(getApiErrorMessage(apiError({ message: 'Unknown server error' }), fallback), fallback)
  assert.match(getApiErrorMessage({ isAxiosError: true }, fallback), /Không thể kết nối máy chủ/)
  assert.match(getApiErrorMessage(apiError('', 401), fallback), /đăng nhập lại/)
  assert.match(getApiErrorMessage(apiError('', 403), fallback), /không có quyền/)
  assert.match(getApiErrorMessage(apiError('', 429), fallback), /thao tác quá nhanh/)
})
