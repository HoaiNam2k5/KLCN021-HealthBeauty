import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import ts from 'typescript'
import axios from 'axios'

async function loadClient(state) {
  const source = await readFile(new URL('../src/api/client.ts', import.meta.url), 'utf8')
  const key = `__healthbeautySessionTest${Date.now()}`
  globalThis[key] = state
  const sessionModule = `const state = globalThis[${JSON.stringify(key)}];
    export const getRefreshToken = () => state.refresh;
    export const getSession = () => state.session;
    export const clearSession = () => { state.session = null; state.refresh = null };
    export const saveAuthResponse = data => { state.refresh = data.refreshToken; state.session = data };`
  const sessionUrl = `data:text/javascript;base64,${Buffer.from(sessionModule).toString('base64')}`
  const guardUrl = `data:text/javascript;base64,${Buffer.from('export const isAuthResponse = () => true; export const isWebAccount = () => true;').toString('base64')}`
  const { outputText } = ts.transpileModule(source, { compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ES2022 } })
  const compiled = outputText.replace("from 'axios'", `from '${import.meta.resolve('axios')}'`)
    .replace(/from ['"]\.\.\/types\/auth['"]/, `from '${guardUrl}'`)
    .replace(/from ['"]\.\/session['"]/, `from '${sessionUrl}'`)
    .replace('import.meta.env.VITE_API_BASE_URL', "''")
  return { ...(await import(`data:text/javascript;base64,${Buffer.from(compiled).toString('base64')}`)), cleanup: () => { delete globalThis[key] } }
}

test('logout after an expired access token revokes the rotated refresh token', async () => {
  const state = { refresh: 'old-refresh', session: { accessToken: 'expired-access' } }
  const requests = []
  let client
  const originalAdapter = axios.defaults.adapter
  axios.defaults.adapter = async config => {
    requests.push({ url: config.url, authorization: config.headers.Authorization, body: JSON.parse(config.data ?? '{}') })
    if (config.url === '/auth/logout' && !config._retry) {
      throw new axios.AxiosError('Expired access token', 'ERR_BAD_REQUEST', config, {}, { status: 401, data: {}, config, headers: {} })
    }
    const data = config.url === '/auth/refresh'
      ? { accessToken: 'new-access', refreshToken: 'new-refresh', account: { id: 1, role: 'Staff' } }
      : null
    return { status: config.url === '/auth/refresh' ? 200 : 204, statusText: 'OK', data, headers: {}, config }
  }
  try {
    client = await loadClient(state)
    const api = client.default
    await api.post('/auth/logout', { refreshToken: 'old-refresh' })
    assert.deepEqual(requests.map(request => request.url), ['/auth/logout', '/auth/refresh', '/auth/logout'])
    assert.equal(requests[2].authorization, 'Bearer new-access')
    assert.deepEqual(requests[2].body, { refreshToken: 'new-refresh' })
  } finally {
    axios.defaults.adapter = originalAdapter
    client?.cleanup()
  }
})

for (const replacement of [null, { accessToken: 'another-access', refreshToken: 'another-refresh' }]) {
  test(`late refresh revokes discarded credentials without changing ${replacement ? 'a new login' : 'a logged-out session'}`, async () => {
    const state = { refresh: 'original-refresh', session: { accessToken: 'original-access' } }
    const originalAdapter = axios.defaults.adapter
    let completeRefresh
    let startedRefresh
    const started = new Promise(resolve => { startedRefresh = resolve })
    const pending = new Promise(resolve => { completeRefresh = resolve })
    const requests = []
    axios.defaults.adapter = async config => {
      requests.push({ url: config.url, authorization: config.headers.Authorization, body: JSON.parse(config.data ?? '{}') })
      if (config.url === '/auth/refresh') {
        startedRefresh()
        return pending
      }
      return { status: 204, statusText: 'OK', data: null, headers: {}, config }
    }
    let client
    try {
      client = await loadClient(state)
      const refresh = client.refreshSession()
      const rejected = assert.rejects(refresh, /Phiên đăng nhập đã thay đổi/)
      await started
      state.refresh = replacement?.refreshToken ?? null
      state.session = replacement
      completeRefresh({ status: 200, statusText: 'OK', headers: {}, config: {},
        data: { accessToken: 'discarded-access', refreshToken: 'discarded-refresh', account: { id: 1, role: 'Staff' } } })
      await rejected
      assert.deepEqual(requests.map(request => request.url), ['/auth/refresh', '/auth/logout'])
      assert.deepEqual(requests[1].body, { refreshToken: 'discarded-refresh' })
      assert.equal(requests[1].authorization, 'Bearer discarded-access')
      assert.equal(state.session, replacement)
      assert.equal(state.refresh, replacement?.refreshToken ?? null)
    } finally {
      axios.defaults.adapter = originalAdapter
      client?.cleanup()
    }
  })
}
