import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const source = await readFile(new URL('../src/utils/permissionPolicy.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
const { parseCurrentPermissions, canVisitRoute, supportsPermission } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)

test('Reception management menus appear after granting their precise permissions', () => {
  for (const [path, code] of [['/services', 'SERVICE.WRITE'], ['/combos', 'SERVICE.WRITE'],
    ['/staff', 'STAFF.READ'], ['/staff-schedules', 'STAFF.READ'], ['/promotions', 'PROMOTION.WRITE'],
    ['/reviews', 'REVIEW.MODERATE'], ['/reports', 'REPORT.READ']]) {
    assert.equal(canVisitRoute(path, 'Reception', []), false)
    assert.equal(canVisitRoute(path, 'Reception', [code]), true)
  }
})

test('revoking read access removes appointment and invoice routes without inferring grants from writes', () => {
  assert.equal(canVisitRoute('/appointments', 'Reception', ['APPOINTMENT.WRITE']), false)
  assert.equal(canVisitRoute('/billing', 'Reception', ['INVOICE.WRITE', 'PAYMENT.WRITE']), false)
  assert.equal(canVisitRoute('/appointments', 'Reception', ['APPOINTMENT.READ']), true)
  assert.equal(canVisitRoute('/billing', 'Reception', ['INVOICE.READ']), true)
})

test('Admin role alone never grants a protected route', () => {
  assert.equal(canVisitRoute('/services', 'Admin', []), false)
  assert.equal(canVisitRoute('/permissions', 'Admin', []), false)
  assert.equal(canVisitRoute('/accounts', 'Admin', []), false)
  assert.equal(canVisitRoute('/accounts', 'Admin', ['ACCOUNT.READ']), true)
  assert.equal(canVisitRoute('/permissions', 'Admin', ['ROLE.READ']), true)
})

test('account and permission administration remain Admin-only despite raw grants', () => {
  for (const role of ['Reception', 'Manager', 'Staff', 'Customer']) {
    assert.equal(canVisitRoute('/accounts', role, ['ACCOUNT.READ']), false)
    assert.equal(canVisitRoute('/permissions', role, ['ROLE.READ']), false)
    assert.equal(supportsPermission(role, 'ACCOUNT.WRITE'), false)
    assert.equal(supportsPermission(role, 'ROLE.WRITE'), false)
  }
})

test('Staff read grants open own appointments/schedules without directory or management writes', () => {
  assert.equal(canVisitRoute('/appointments', 'Staff', ['APPOINTMENT.READ']), true)
  assert.equal(canVisitRoute('/staff-schedules', 'Staff', ['STAFF.READ']), true)
  assert.equal(canVisitRoute('/staff', 'Staff', ['STAFF.READ']), false)
  for (const code of ['STAFF.WRITE', 'SERVICE.WRITE', 'APPOINTMENT.WRITE', 'REPORT.READ', 'REVIEW.MODERATE'])
    assert.equal(supportsPermission('Staff', code), false)
  assert.equal(canVisitRoute('/services', 'Staff', ['SERVICE.WRITE']), false)
})

test('Customer grants do not expose management routes', () => {
  assert.equal(supportsPermission('Customer', 'SERVICE.READ'), true)
  assert.equal(supportsPermission('Customer', 'CUSTOMER.READ'), false)
  assert.equal(canVisitRoute('/customers', 'Customer', ['CUSTOMER.READ']), false)
})

test('permission response rejects malformed grants and deduplicates valid active codes', () => {
  assert.deepEqual(parseCurrentPermissions({ role: 'Reception', permissions: ['SERVICE.WRITE', 'SERVICE.WRITE'] }),
    { role: 'Reception', permissions: ['SERVICE.WRITE'] })
  for (const response of [null, {}, { role: 'Admin', permissions: [123] }, { role: 1, permissions: [] }])
    assert.throws(() => parseCurrentPermissions(response))
})

test('overview stays available while unknown routes and unsupported roles fail closed', () => {
  assert.equal(canVisitRoute('/', 'Reception', []), true)
  assert.equal(canVisitRoute('/services/', 'Reception', ['SERVICE.WRITE']), true)
  assert.equal(canVisitRoute('/missing', 'Admin', ['ROLE.READ']), false)
  assert.equal(canVisitRoute('/services', null, ['SERVICE.WRITE']), false)
})

test('catalog read grant opens read-only web catalog for Reception and Staff', () => {
  for (const role of ['Reception', 'Staff']) {
    for (const route of ['/services', '/service-categories', '/combos']) {
      assert.equal(canVisitRoute(route, role, ['SERVICE.READ']), true)
    }
  }
  assert.equal(supportsPermission('Staff', 'SERVICE.WRITE'), false)
  assert.equal(canVisitRoute('/services', 'Customer', ['SERVICE.READ']), false)
})

test('audit logs match the existing Admin-only ACCOUNT.READ API gate', () => {
  assert.equal(canVisitRoute('/audit-logs', 'Admin', ['ACCOUNT.READ']), true)
  assert.equal(canVisitRoute('/audit-logs', 'Admin', ['AUDIT.READ']), false)
  assert.equal(canVisitRoute('/audit-logs', 'Admin', []), false)
  for (const role of ['Reception', 'Manager', 'Staff', 'Customer']) {
    assert.equal(canVisitRoute('/audit-logs', role, ['ACCOUNT.READ', 'AUDIT.READ']), false)
  }
})
