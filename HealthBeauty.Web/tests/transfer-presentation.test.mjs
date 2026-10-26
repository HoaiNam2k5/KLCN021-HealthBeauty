import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

const source = await readFile(new URL('../src/features/billing/transferPresentation.ts', import.meta.url), 'utf8')
const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
const { matchesPayableInvoice } = await import(`data:text/javascript;base64,${Buffer.from(outputText).toString('base64')}`)
const invoice = { id: 9, status: 'ChuaThanhToan', total: 550000 }
const transfer = { invoiceId: 9, status: 'ChuaThanhToan', amount: 550000, transferContent: 'HB9', qrImageUrl: 'https://vietqr.app/img?acc=example' }

test('cashier QR matches exact current invoice, amount and bank reference', () => {
  assert.equal(matchesPayableInvoice(invoice, transfer), true)
  for (const patch of [{ invoiceId: 10 }, { amount: 549999 }, { transferContent: 'HP9' }, { transferContent: 'HB10' }, { status: 'DaThanhToan' }, { qrImageUrl: 'http://untrusted.example/qr' }]) {
    assert.equal(matchesPayableInvoice(invoice, { ...transfer, ...patch }), false)
  }
})

test('paid, cancelled, changed totals or absent invoice cannot retain a payable QR', () => {
  for (const patch of [{ status: 'DaThanhToan' }, { status: 'DaHuy' }, { total: 500000 }, { total: 0 }, { total: 550000.5 }]) {
    assert.equal(matchesPayableInvoice({ ...invoice, ...patch }, transfer), false)
  }
  assert.equal(matchesPayableInvoice(undefined, transfer), false)
  assert.equal(matchesPayableInvoice(invoice, undefined), false)
})
