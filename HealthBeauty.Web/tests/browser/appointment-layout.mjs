// Run after npm run build and vite preview on 127.0.0.1:5178.
// Set PW_MODULE to a locally installed Playwright package if it is not on NODE_PATH.
// Every API response is isolated; non-local network requests are blocked.
import { createRequire } from 'node:module'
import assert from 'node:assert/strict'
import { mkdir, writeFile } from 'node:fs/promises'
import { fileURLToPath } from 'node:url'
const require = createRequire(import.meta.url)
const { chromium } = require(process.env.PW_MODULE || 'playwright')
const base = process.env.LAYOUT_BASE_URL || 'http://127.0.0.1:5178'
const output = process.env.LAYOUT_OUTPUT || fileURLToPath(new URL('./artifacts/', import.meta.url))
await mkdir(output, { recursive: true })
const browser = await chromium.launch({ headless: true, ...(process.env.PW_EXECUTABLE ? { executablePath: process.env.PW_EXECUTABLE } : {}) })
const errors = [], results = []
const customerName = 'Khách hàng có họ tên rất dài để kiểm tra bố cục bảng lịch hẹn'
const serviceName = 'Chăm sóc da chuyên sâu và phục hồi kết hợp nhiều dịch vụ bổ sung có tên dài'
const note = 'Ghi chú đầy đủ chỉ hiển thị trong chi tiết. '.repeat(15)
try {
  for (const width of [1366, 1024, 768, 390, 320]) {
    let status = 'ChoXacNhan'
    let canWrite = true
    const mutations = []
    const context = await browser.newContext({ viewport: { width, height: 1000 } })
    await context.addInitScript(() => localStorage.setItem('healthbeauty.refreshToken', 'isolated-layout-fixture'))
    const appointment = () => ({ id: 901, customerId: 1, customerName, staffId: 1, staffName: 'Kỹ thuật viên chuyên chăm sóc da', appointmentAt: '2026-11-01T10:00:00', status, note, fundingSource: 'ServicePackage', items: [{ id: 1, serviceId: 1, serviceName, comboId: null, expectedPrice: 350000, durationMinutes: 60 }] })
    await context.route('**/*', async (route) => {
      const request = route.request(), url = new URL(request.url())
      if (!url.pathname.includes('/api/v1/')) return url.origin === base ? route.continue() : route.abort()
      const path = url.pathname.split('/api/v1')[1]
      let data = []
      if (path === '/auth/refresh') data = { accessToken: 'isolated-layout-fixture', refreshToken: 'isolated-layout-fixture', accessTokenExpiresAt: '2099-01-01T00:00:00Z', account: { id: 999, name: 'Lễ tân thử nghiệm', email: 'fixture@example.test', role: 'Reception' } }
      else if (path === '/auth/permissions') data = { role: 'Reception', permissions: ['APPOINTMENT.READ', ...(canWrite ? ['APPOINTMENT.WRITE'] : []), 'STAFF.READ', 'CUSTOMER.READ', 'INVOICE.READ', 'SERVICE.READ'] }
      else if (path === '/appointments/901/status') { status = request.postDataJSON().status; mutations.push(status); data = {} }
      else if (path === '/appointments/901') data = { ...appointment(), khachHang: { hoTen: customerName }, nhanVien: { hoTen: 'Kỹ thuật viên chuyên chăm sóc da' } }
      else if (path === '/appointments') data = { items: [appointment()], totalCount: 1, page: 1, pageSize: 20 }
      else if (path === '/customers') data = [{ id: 1, fullName: customerName }]
      else if (path === '/staff') data = [{ nhanVienId: 1, hoTen: 'Kỹ thuật viên chuyên chăm sóc da', chucVu: 'Staff' }]
      return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(data) })
    })
    const page = await context.newPage()
    page.on('pageerror', (e) => errors.push(`${width}: ${e.message}`))
    await page.goto(`${base}/appointments`)
    const approve = page.getByRole('button', { name: 'Xác nhận lịch', exact: true })
    await approve.waitFor()
    await page.evaluate(() => document.fonts.ready)
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), false, `${width}: page overflows horizontally`)
    const box = await approve.boundingBox()
    assert.ok(box.x >= 0 && box.x + box.width <= width + 1, `${width}: approval outside viewport before horizontal scroll`)
    if (width >= 768) {
      const scroll = page.locator('.appointments-management .ant-table-content')
      assert.equal(await scroll.evaluate((el) => el.scrollLeft), 0)
      const cell = approve.locator('xpath=ancestor::td')
      assert.equal(await cell.evaluate((el) => getComputedStyle(el).position), 'sticky')
      await scroll.evaluate((el) => { el.scrollLeft = el.scrollWidth })
      const after = await approve.boundingBox()
      assert.ok(Math.abs(after.x - box.x) <= 2, `${width}: fixed action moved while scrolling`)
      await scroll.evaluate((el) => { el.scrollLeft = 0 })
    } else {
      assert.equal(await page.locator('.appointment-mobile-card').count(), 1)
      assert.equal(await page.locator('.appointments-management table').count(), 0)
    }
    await page.screenshot({ path: `${output}/appointments-${width}.png`, fullPage: true })
    await approve.click()
    await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận', exact: true }).click()
    await page.getByRole('button', { name: 'Bắt đầu dịch vụ', exact: true }).waitFor()
    assert.deepEqual(mutations, ['DaXacNhan'])
    const more = page.getByRole('button', { name: 'Thao tác khác cho lịch #901', exact: true })
    await more.focus()
    await page.keyboard.press('Enter')
    await page.getByRole('menuitem', { name: 'Khách đã đến', exact: true }).click()
    await page.getByRole('dialog').getByRole('button', { name: 'Xác nhận', exact: true }).click()
    await page.getByRole('button', { name: 'Thao tác khác cho lịch #901', exact: true }).click()
    await page.getByRole('menuitem', { name: 'Hủy lịch', exact: true }).waitFor()
    assert.equal(await page.getByRole('menuitem', { name: 'Khách đã đến', exact: true }).count(), 0)
    await page.keyboard.press('Escape')
    await page.getByRole('button', { name: 'Xem chi tiết', exact: true }).click()
    const drawer = page.locator('.ant-drawer-body')
    await drawer.getByText(note, { exact: true }).waitFor()
    await drawer.getByText(serviceName, { exact: true }).waitFor()
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth > innerWidth + 1), false)
    assert.deepEqual(mutations, ['DaXacNhan', 'DaDen'])
    canWrite = false
    await page.reload()
    await page.getByRole('button', { name: 'Xem chi tiết', exact: true }).waitFor()
    assert.equal(await page.getByRole('button', { name: 'Bắt đầu dịch vụ', exact: true }).count(), 0)
    assert.equal(await page.getByRole('button', { name: 'Thao tác khác cho lịch #901', exact: true }).count(), 0)
    results.push({ width, actionVisibleBeforeScrolling: true, fixedRight: width >= 768, mobileCards: width < 768, confirmationAndOptionalArrival: 'PASS', fullDetail: 'PASS', readOnlyPermissions: 'PASS' })
    await context.close()
  }
  assert.deepEqual(errors, [])
  await writeFile(`${output}/validation.json`, JSON.stringify({ results, errors, productionRequests: 0 }, null, 2))
  console.log(`PASS: ${results.length} viewports; fixed actions, mobile cards, keyboard menu, confirmation, optional arrival and full detail; no production requests.`)
} finally { await browser.close() }
