import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const source = await readFile(new URL('../src/features/billing/packagePaymentSafety.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
const { parsePackagePurchaseId, canCollectPackagePayment, packagePaymentStatusLabel } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
const expected = { id: 7, status: 'Pending', price: 550000 }

test('package links accept positive safe integer IDs only', () => {
  assert.equal(parsePackagePurchaseId('7'), 7)
  for (const id of [null, '', '0', '-1', '1.5', 'Infinity', 'NaN', '9007199254740992', '1e2']) assert.equal(parsePackagePurchaseId(id), undefined)
})

test('package collection never charges a paid, cancelled, missing or mismatched purchase', () => {
  assert.equal(canCollectPackagePayment(expected, { ...expected }), true)
  for (const latest of [undefined, { ...expected, status: 'Paid' }, { ...expected, status: 'Cancelled' }, { ...expected, id: 8 }, { ...expected, price: 500000 }, { ...expected, price: NaN }]) assert.equal(canCollectPackagePayment(expected, latest), false)
  assert.equal(canCollectPackagePayment({ ...expected, status: 'Paid' }, expected), false)
})

test('unknown package payment status cannot be mislabeled as cancelled', () => {
  assert.equal(packagePaymentStatusLabel('Paid'), 'Đã thanh toán')
  assert.equal(packagePaymentStatusLabel('Pending'), 'Chờ thanh toán')
  assert.equal(packagePaymentStatusLabel('Cancelled'), 'Đã hủy')
  assert.equal(packagePaymentStatusLabel('Unexpected'), 'Chưa xác định')
})
