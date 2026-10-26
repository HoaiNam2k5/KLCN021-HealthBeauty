import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'
import { QueryClient, QueryObserver } from '@tanstack/react-query'

const helperSource = await readFile(new URL('../src/features/billing/transferSafety.ts', import.meta.url), 'utf8')
const helperJs = ts.transpileModule(helperSource, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } }).outputText
const safety = await import(`data:text/javascript;base64,${Buffer.from(helperJs).toString('base64')}`)
const source = await readFile(new URL('../src/features/billing/BankTransferModal.tsx', import.meta.url), 'utf8')
const componentJs = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } }).outputText
const pending = (id = 1, total = 550000) => ({ id, customerId: 1, appointmentId: 3, createdAt: '2026-10-26', subtotal: total, total, status: 'ChuaThanhToan', items: [], payments: [] })
const paid = id => ({ ...pending(id), status: 'DaThanhToan', payments: [{ method: 'TienMat', amount: 550000, status: 'ThanhCong' }] })
const transfer = (id = 1, amount = 550000) => ({ invoiceId: id, amount, status: 'ChuaThanhToan', bankCode: 'MB', bankName: 'MBBank', accountNumber: '0971224228', accountName: 'NGUYEN HOAI NAM', transferContent: `HB${id}`, qrImageUrl: `https://vietqr.app/img?acc=0971224228&bank=MB&amount=${amount}&des=HB${id}` })
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no }); return { promise, resolve, reject } }
const tick = async () => { for (let i = 0; i < 12; i++) await Promise.resolve() }

function harness(extraProps = {}) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: Infinity } } })
  const invoiceReads = [], transfers = [], effects = [], refs = [], observers = [], callbacks = [], prints = []
  let hookIndex = 0, refIndex = 0, identity, session = { account: { id: 4 } }, tree
  const jsx = (type, props, key) => ({ type, props, key })
  const antd = new Proxy({ App: { useApp: () => ({ message: { success() {}, error() {} } }) } }, { get: (target, key) => target[key] || key })
  const imports = {
    'react/jsx-runtime': { jsx, jsxs: jsx }, antd,
    '@ant-design/icons': new Proxy({}, { get: (_, key) => key }),
    react: { useRef: initial => refs[refIndex++] ||= { current: initial }, useEffect: callback => effects.push(callback) },
    '@tanstack/react-query': { useQuery: options => {
      let observer = observers[hookIndex++]
      if (!observer) { observer = new QueryObserver(client, options); observers.push(observer); observer.subscribe(() => {}) }
      else observer.setOptions(options)
      return observer.getCurrentResult()
    } },
    '../../api/billing': {
      getInvoice: (id, signal) => { const result = deferred(); invoiceReads.push({ id, signal, ...result }); return result.promise },
      getBankTransferInstructions: (id, signal) => { const result = deferred(); transfers.push({ id, signal, ...result }); return result.promise },
    },
    '../../components/apiError': { getApiErrorMessage: (_error, fallback) => fallback },
    '../../hooks/useAuth': { useAuth: () => session }, '../../api/session': { getSession: () => session },
    './billingConstants': { INVOICE_STATUS: { UNPAID: 'ChuaThanhToan', PAID: 'DaThanhToan' } }, './transferSafety': safety,
  }
  const exports = {}
  new Function('require', 'exports', componentJs)(name => { assert.ok(name in imports, name); return imports[name] }, exports)
  function dispose() { observers.splice(0).forEach(observer => observer.destroy()); refs.length = 0 }
  return { client, invoiceReads, transfers, callbacks, prints,
    account(id) { session = id === null ? null : { account: { id } } },
    render(id = 1, open = true) {
      const element = exports.default({ open, invoiceId: id, onClose() {}, onPaymentSuccess: invoice => callbacks.push(invoice), onPrintReceipt: invoice => prints.push(invoice), ...extraProps })
      if (!element || element.key !== identity) { dispose(); identity = element?.key }
      if (!element) { tree = null; return tree }
      hookIndex = 0; refIndex = 0
      tree = element.type(element.props)
      effects.splice(0).forEach(effect => effect())
      return tree
    },
    refetch(id = 1, accountId = 4) { return client.refetchQueries({ queryKey: ['bank-transfer-invoice', accountId, id], exact: true }, { cancelRefetch: false }) },
    close() { dispose(); client.clear() },
  }
}
function nodes(tree, type) {
  if (Array.isArray(tree)) return tree.flatMap(child => nodes(child, type))
  if (!tree || typeof tree !== 'object') return []
  return [...(tree.type === type ? [tree] : []), ...nodes(tree.props?.children, type)]
}
function text(tree) {
  if (Array.isArray(tree)) return tree.map(text).join(' ')
  if (typeof tree === 'string' || typeof tree === 'number') return String(tree)
  return tree && typeof tree === 'object' ? text(tree.props?.children) : ''
}
async function ready(h, id = 1, amount = 550000) {
  h.render(id); h.invoiceReads.at(-1).resolve(pending(id, amount)); await tick()
  h.render(id); h.transfers.at(-1).resolve(transfer(id, amount)); await tick()
  return h.render(id)
}

test('late A instructions and paid polling cannot replace B QR or notify payment for B', async () => {
  const h = harness()
  try {
    h.render(1); h.invoiceReads.at(-1).resolve(pending()); await tick(); h.render(1)
    const oldInstructions = h.transfers.at(-1)
    const oldPoll = h.refetch(1); const oldRead = h.invoiceReads.at(-1)
    await ready(h, 2, 500000)
    oldInstructions.resolve(transfer()); oldRead.resolve(paid(1)); await oldPoll; await tick()
    assert.deepEqual(nodes(h.render(2), 'img').map(image => image.props.src), [transfer(2, 500000).qrImageUrl])
    assert.deepEqual(h.callbacks, [])
  } finally { h.close() }
})

test('account switch and close immediately remove the old QR and ignore late paid callbacks', async () => {
  const h = harness()
  try {
    await ready(h)
    const request = h.refetch(); const old = h.invoiceReads.at(-1)
    h.account(5)
    assert.equal(nodes(h.render(), 'img').length, 0)
    old.resolve(paid(1)); await request; await tick(); h.render()
    assert.equal(nodes(h.render(), 'img').length, 0)
    assert.deepEqual(h.callbacks, [])
    h.render(1, false)
    assert.equal(h.render(1, false), null)
  } finally { h.close() }
})

test('closing and reopening the same invoice aborts both old reads and QR requests', async () => {
  const h = harness()
  try {
    h.render()
    const oldRead = h.invoiceReads.at(-1)
    h.render(1, false)
    assert.equal(oldRead.signal.aborted, true)
    h.render()
    const newRead = h.invoiceReads.at(-1)
    assert.notEqual(oldRead, newRead)
    assert.equal(h.invoiceReads.length, 2)
    oldRead.resolve(pending()); await tick()
    assert.equal(nodes(h.render(), 'img').length, 0)
    assert.equal(h.transfers.length, 0)
    newRead.resolve(pending(1, 500000)); await tick(); h.render()
    const oldQr = h.transfers.at(-1)
    h.render(1, false)
    assert.equal(oldQr.signal.aborted, true)
    h.render()
    const finalRead = h.invoiceReads.at(-1)
    oldQr.resolve(transfer(1, 500000)); await tick()
    assert.equal(nodes(h.render(), 'img').length, 0)
    finalRead.resolve(pending(1, 450000)); await tick(); h.render()
    const newQr = h.transfers.at(-1)
    assert.notEqual(oldQr, newQr)
    newQr.resolve(transfer(1, 450000)); await tick()
    assert.deepEqual(nodes(h.render(), 'img').map(image => image.props.src), [transfer(1, 450000).qrImageUrl])
  } finally { h.close() }
})

test('amount changes hide stale QR until new instructions match; network errors hide it again', async () => {
  const h = harness()
  try {
    assert.equal(nodes(await ready(h), 'img').length, 1)
    const request = h.refetch(); h.invoiceReads.at(-1).resolve(pending(1, 500000)); await request
    assert.equal(nodes(h.render(), 'img').length, 0)
    h.transfers.at(-1).resolve(transfer(1, 500000)); await tick()
    assert.deepEqual(nodes(h.render(), 'img').map(image => image.props.src), [transfer(1, 500000).qrImageUrl])
    const failed = h.refetch(); h.invoiceReads.at(-1).reject(new Error('offline')); await failed
    assert.equal(nodes(h.render(), 'img').length, 0)
  } finally { h.close() }
})

test('polls share an in-flight read and cash payment uses neutral success with latest printable invoice', async () => {
  const h = harness()
  try {
    await ready(h)
    const count = h.invoiceReads.length
    const first = h.refetch(), second = h.refetch()
    assert.equal(h.invoiceReads.length, count + 1)
    const latest = paid(1); h.invoiceReads.at(-1).resolve(latest); await Promise.all([first, second])
    const tree = h.render()
    assert.deepEqual(h.callbacks[0], latest)
    const success = nodes(tree, 'Result')[0]
    assert.equal(success.props.title, 'Hóa đơn đã được thanh toán')
    const buttons = [...nodes(tree.props.footer, 'Button'), ...nodes(success.props.extra, 'Button')]
    buttons.find(button => text(button).includes('In phiếu')).props.onClick()
    assert.deepEqual(h.prints[0], latest)
  } finally { h.close() }
})

test('transfer identity, reference, amount and QR destination must match authoritative invoice', () => {
  assert.equal(safety.matchesPayableInvoice(pending(), transfer()), true)
  for (const invalid of [{ ...transfer(), invoiceId: 2 }, transfer(1, 500000), { ...transfer(), transferContent: 'HB2' }, { ...transfer(), qrImageUrl: 'https://vietqr.app.attacker.example/img' }, { ...transfer(), qrImageUrl: transfer().qrImageUrl.replace('amount=550000', 'amount=500000') }]) {
    assert.equal(safety.matchesPayableInvoice(pending(), invalid), false)
  }
  assert.equal(safety.matchesPayableInvoice(paid(1), transfer()), false)
})

test('cash/card handoff requires its write permission and an authoritative unpaid invoice', async () => {
  const calls = []
  const h = harness({ canPayCash: true, onCash: invoice => calls.push(invoice) })
  const readOnly = harness({ canPayCash: false, onCash: invoice => calls.push(invoice) })
  const cashButton = tree => nodes(tree.props.footer, 'Button').find(button => text(button).includes('Thu tiền mặt / thẻ'))
  try {
    const tree = await ready(h)
    assert.ok(cashButton(tree))
    cashButton(tree).props.onClick()
    assert.deepEqual(calls, [pending()])
    assert.equal(cashButton(await ready(readOnly)), undefined)
    const refresh = h.refetch()
    h.invoiceReads.at(-1).resolve(paid(1)); await refresh
    assert.equal(cashButton(h.render()), undefined)
  } finally { h.close(); readOnly.close() }
})

test('paid receipt cache cancels an older pending list response before seeding latest snapshot', async () => {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false, gcTime: Infinity } } })
  try {
    client.setQueryData(['invoices'], [pending()])
    const old = deferred()
    const fetch = client.fetchQuery({ queryKey: ['invoices'], queryFn: () => old.promise }).catch(() => {})
    const latest = paid(1)
    assert.equal(await safety.cacheVerifiedPaidInvoice(client, latest, () => true), true)
    old.resolve([pending()]); await fetch; await tick()
    assert.deepEqual(client.getQueryData(['invoices'])[0], latest)
    assert.deepEqual(client.getQueryData(['invoices', 'detail', 1]), latest)
  } finally { client.clear() }
})

test('receipt callback never seeds another session after cancellation awaited', async () => {
  let current = true, writes = 0
  const fake = { cancelQueries: async () => { current = false }, setQueryData: () => { writes++ } }
  assert.equal(await safety.cacheVerifiedPaidInvoice(fake, paid(1), () => current), false)
  assert.equal(writes, 0)
})

test('billing API forwards optional abort signals to both Axios requests without changing old calls', async () => {
  const apiSource = await readFile(new URL('../src/api/billing.ts', import.meta.url), 'utf8')
  const compiled = ts.transpileModule(apiSource, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS } }).outputText
  const calls = [], exports = {}
  const api = {
    get: async (...args) => { calls.push(['GET', ...args]); return { data: pending() } },
    post: async (...args) => { calls.push(['POST', ...args]); return { data: transfer() } },
  }
  new Function('require', 'exports', compiled)(name => {
    if (name === './client') return { __esModule: true, default: api }
    if (name === '../types/billing') return { asInvoices: value => value }
    throw new Error(name)
  }, exports)
  const signal = new AbortController().signal
  await exports.getInvoice(1, signal)
  await exports.getBankTransferInstructions(1, signal)
  assert.deepEqual(calls, [['GET', '/invoices/1', { signal }], ['POST', '/invoices/1/bank-transfer', undefined, { signal }]])
  await exports.getInvoice(1)
  await exports.getBankTransferInstructions(1)
  assert.equal(calls[2][2].signal, undefined)
  assert.equal(calls[3][3].signal, undefined)
})
