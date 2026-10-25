import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

async function loadModule(path) {
  const source = await readFile(new URL(path, import.meta.url), 'utf8')
  const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
  return import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
}
const { canApplyInvoiceDiscount, currentInvoice, recordPendingPayment } = await loadModule('../src/features/billing/invoiceSync.ts')
const { eligibleInvoiceAppointments } = await loadModule('../src/features/billing/invoiceDraft.ts')
const pending = { id: 9, appointmentId: 3, subtotal: 550000, total: 550000, status: 'ChuaThanhToan', items: [], payments: [] }
const paid = { ...pending, status: 'DaThanhToan', payments: [{ id: 100, method: 'ChuyenKhoan', amount: 550000, status: 'ThanhCong' }] }

test('automatic pending invoices retain a first-time voucher/points action only before payment', () => {
  assert.equal(canApplyInvoiceDiscount(pending), true)
  assert.equal(canApplyInvoiceDiscount(paid), false)
  assert.equal(canApplyInvoiceDiscount({ ...pending, total: 500000 }), false)
  assert.equal(canApplyInvoiceDiscount({ ...pending, total: 0, subtotal: 0 }), false)
  assert.equal(canApplyInvoiceDiscount({ ...pending, payments: paid.payments }), false)
})

test('open invoice detail and receipt resolve the latest paid server snapshot', () => {
  assert.equal(currentInvoice(9, [pending]), pending)
  assert.equal(currentInvoice(9, [paid]), paid)
  assert.equal(currentInvoice(9, [paid]).payments[0].method, 'ChuyenKhoan')
  assert.equal(currentInvoice(9, [paid]).status, 'DaThanhToan')
})

test('an older open invoice can refresh through detail when outside the current list', () => {
  assert.equal(currentInvoice(9, [], paid), paid)
  assert.equal(currentInvoice(9, [], { ...paid, id: 10 }), null)
  assert.equal(currentInvoice(null, [paid], paid), null)
})

test('a completed appointment already linked to an invoice cannot create a second one', () => {
  const appointments = [
    { id: 3, status: 'HoanThanh', invoiceId: 9 },
    { id: 4, status: 'HoanThanh', invoiceId: null },
    { id: 5, status: 'HoanThanh', fundingSource: 'ServicePackage', invoiceId: null },
    { id: 6, status: 'DaXacNhan', invoiceId: null },
  ]
  assert.deepEqual(eligibleInvoiceAppointments(appointments, []).map((item) => item.id), [4])
})

test('manual payment fresh-reads invoice and skips POST after SePay has settled', async () => {
  const calls = []
  const result = await recordPendingPayment(9, { method: 'TienMat', status: 'ThanhCong' }, {
    getInvoice: async (id) => { calls.push(['GET', id]); return paid },
    recordInvoicePayment: async () => { calls.push(['POST']) },
  }, 550000)
  assert.equal(result, false)
  assert.deepEqual(calls, [['GET', 9]])
})

test('manual payment stops when amount changed or invoice ID does not match', async () => {
  for (const invoice of [{ ...pending, total: 500000 }, { ...pending, id: 10 }]) {
    let posts = 0
    const result = await recordPendingPayment(9, { method: 'TienMat', status: 'ThanhCong' }, {
      getInvoice: async () => invoice,
      recordInvoicePayment: async () => { posts++ },
    }, 550000)
    assert.equal(result, false)
    assert.equal(posts, 0)
  }
})

test('manual payment records once only after a fresh matching pending invoice', async () => {
  const calls = []
  const body = { method: 'TienMat', status: 'ThanhCong' }
  const result = await recordPendingPayment(9, body, {
    getInvoice: async (id) => { calls.push(['GET', id]); return pending },
    recordInvoicePayment: async (id, request) => { calls.push(['POST', id, request]) },
  }, 550000)
  assert.equal(result, true)
  assert.deepEqual(calls, [['GET', 9], ['POST', 9, body]])
})

test('network errors during freshness check cannot submit a manual payment', async () => {
  let posts = 0
  await assert.rejects(recordPendingPayment(9, { method: 'TienMat', status: 'ThanhCong' }, {
    getInvoice: async () => { throw new Error('offline') },
    recordInvoicePayment: async () => { posts++ },
  }, 550000), /offline/)
  assert.equal(posts, 0)
})
