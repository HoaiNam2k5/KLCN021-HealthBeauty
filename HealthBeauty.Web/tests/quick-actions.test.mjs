import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'

async function load(path, imports = {}) {
  const source = await readFile(new URL(path, import.meta.url), 'utf8')
  const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX } })
  const exports = {}
  new Function('require', 'exports', outputText)(name => { assert.ok(name in imports, `Unexpected import ${name}`); return imports[name] }, exports)
  return exports
}
const { quickActions } = await load('../src/features/reports/quickActions.ts')

test('reception create shortcuts work without report access and use create intents', () => {
  const grants = ['APPOINTMENT.WRITE', 'CUSTOMER.READ', 'INVOICE.WRITE', 'APPOINTMENT.READ', 'CUSTOMER.WRITE']
  const actions = quickActions({ canVisit: () => true, has: code => grants.includes(code) })
  assert.deepEqual(actions.map(action => action.destination), ['/appointments?action=create', '/billing?action=create', '/customers?action=create', '/staff-schedules'])
  assert.equal(grants.includes('REPORT.READ'), false)
})

test('read-only grants never advertise create actions and route access is also required', () => {
  assert.deepEqual(quickActions({ canVisit: () => true, has: () => false }).map(action => action.key), ['schedule'])
  assert.deepEqual(quickActions({ canVisit: () => false, has: () => true }), [])
  assert.equal(quickActions({ canVisit: () => true, has: code => code === 'APPOINTMENT.WRITE' }).some(action => action.key === 'appointment'), false)
  assert.equal(quickActions({ canVisit: () => true, has: code => code === 'INVOICE.WRITE' }).some(action => action.key === 'invoice'), false)
})

test('create intent waits for permission, opens, consumes on close and keeps other filters', async () => {
  let params = new URLSearchParams('action=create&date=2026-10-28')
  let local = false
  let replaced = false
  const { useCreateIntent } = await load('../src/hooks/useCreateIntent.ts', {
    react: { useState: () => [local, next => { local = next }] },
    'react-router-dom': { useSearchParams: () => [params, (next, options) => { params = next; replaced = options.replace }] },
  })
  assert.equal(useCreateIntent(false)[0], false)
  assert.equal(useCreateIntent(true)[0], true)
  useCreateIntent(true)[1](false)
  assert.equal(params.get('action'), null)
  assert.equal(params.get('date'), '2026-10-28')
  assert.equal(replaced, true)
  assert.equal(useCreateIntent(true)[0], false)
  useCreateIntent(false)[1](true)
  assert.equal(useCreateIntent(false)[0], false)
  useCreateIntent(true)[1](true)
  assert.equal(useCreateIntent(true)[0], true)
  assert.equal(useCreateIntent(false)[0], false)
})

test('home actually renders shortcuts without REPORT.READ and never mounts report queries', async () => {
  const jsx = (type, props) => ({ type, props })
  const { default: ReportsPage } = await load('../src/features/reports/ReportsPage.tsx', {
    react: {}, 'react/jsx-runtime': { jsx, jsxs: jsx, Fragment: 'Fragment' }, antd: { Result: 'Result' },
    '@ant-design/icons': {}, dayjs: {}, 'react-router-dom': {}, recharts: {},
    '../../hooks/usePermissions': { usePermissions: () => ({ has: () => false }) },
    '../../components/apiError': {}, '../../api/reports': {},
    './reportQueries': new Proxy({ __esModule: true }, { get: (target, key) => target[key] ?? (() => { throw new Error('Report query mounted without permission') }) }),
    '../../types/reports': { REPORT_HOME_GREETING: 'Welcome', REPORT_ACCESS_DENIED: 'Denied' },
    '../appointments/appointmentStatus': {}, './QuickActionsBar': { __esModule: true, default: 'QuickActionsBar' },
  })
  const home = ReportsPage({ home: true })
  assert.ok(home.props.children.some(child => child.type === 'QuickActionsBar'))
  assert.equal(ReportsPage({ home: false }).props.status, '403')
})
