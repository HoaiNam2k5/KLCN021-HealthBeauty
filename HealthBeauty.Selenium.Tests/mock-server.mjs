// Local-only fixture. This server never connects to the production API or database.
import http from 'node:http'
import { readFile } from 'node:fs/promises'
import { extname, resolve, sep } from 'node:path'

const dist = resolve(process.argv[2] || '')
if (!dist || !process.argv[2]) throw new Error('Missing web dist directory')
let status = 'ChoXacNhan'
const customer = 'Khách hàng Selenium'
const appointment = () => ({ id: 901, customerId: 1, customerName: customer, staffId: 1, staffName: 'Kỹ thuật viên Selenium', appointmentAt: '2026-11-01T10:00:00', status, note: 'Dữ liệu kiểm thử cục bộ', fundingSource: 'Cash', items: [{ id: 1, serviceId: 1, serviceName: 'Chăm sóc da Selenium', comboId: null, expectedPrice: 300000, durationMinutes: 60 }] })
const session = { accessToken: 'local-fixture-access', refreshToken: 'local-fixture-refresh', accessTokenExpiresAt: '2099-01-01T00:00:00Z', account: { id: 999, name: 'Lễ tân thử nghiệm', email: 'fixture@example.test', role: 'Reception' } }
const json = (res, value, code = 200) => { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(value)) }
const types = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.png': 'image/png', '.svg': 'image/svg+xml', '.ico': 'image/x-icon', '.woff2': 'font/woff2' }
http.createServer(async (req, res) => {
  try {
    const path = new URL(req.url, 'http://127.0.0.1').pathname
    if (path === '/__fixture/reset') { status = 'ChoXacNhan'; return json(res, { ok: true }) }
    if (path === '/__fixture/state') return json(res, { status })
    if (path.startsWith('/api/v1/')) {
      let body = ''; for await (const chunk of req) body += chunk
      let input = {}; try { input = body ? JSON.parse(body) : {} } catch { return json(res, { message: 'Invalid JSON' }, 400) }
      const api = path.slice('/api/v1'.length)
      if (api === '/auth/login') return input.email === 'fixture@example.test' && input.password === 'FixtureOnly123!' ? json(res, session) : json(res, { message: 'Thông tin đăng nhập không hợp lệ.' }, 401)
      if (api === '/auth/refresh') return input.refreshToken === 'local-fixture-refresh' ? json(res, session) : json(res, { message: 'Invalid session' }, 401)
      if (api === '/auth/permissions') return json(res, { role: 'Reception', permissions: ['APPOINTMENT.READ', 'APPOINTMENT.WRITE', 'STAFF.READ', 'CUSTOMER.READ', 'INVOICE.READ', 'SERVICE.READ'] })
      if (api === '/appointments/901/status' && req.method !== 'GET') { status = input.status; return json(res, {}) }
      if (api === '/appointments/901') return json(res, { ...appointment(), khachHang: { hoTen: customer }, nhanVien: { hoTen: 'Kỹ thuật viên Selenium' } })
      if (api === '/appointments') return json(res, { items: [appointment()], totalCount: 1, page: 1, pageSize: 20 })
      if (api === '/customers') return json(res, [{ id: 1, fullName: customer }])
      if (api === '/staff') return json(res, [{ nhanVienId: 1, hoTen: 'Kỹ thuật viên Selenium', chucVu: 'Staff' }])
      if (api === '/services') return json(res, [{ id: 1, name: 'Chăm sóc da Selenium', price: 300000, durationMinutes: 60, active: true, categoryId: 1, categoryName: 'Chăm sóc da' }])
      if (api === '/service-categories') return json(res, [{ id: 1, name: 'Chăm sóc da', active: true }])
      if (api === '/invoices') return json(res, { items: [], totalCount: 0, page: 1, pageSize: 20 })
      return json(res, [])
    }
    const target = resolve(dist, '.' + decodeURIComponent(path))
    if (target !== dist && !target.startsWith(dist + sep)) return json(res, {}, 403)
    let file = target, data
    try { data = await readFile(file) } catch { file = resolve(dist, 'index.html'); data = await readFile(file) }
    res.writeHead(200, { 'Content-Type': types[extname(file)] || 'application/octet-stream', 'Content-Security-Policy': "default-src 'self' data: blob:; connect-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; font-src 'self' data:;" })
    res.end(data)
  } catch { json(res, { message: 'Fixture error' }, 500) }
}).listen(0, '127.0.0.1', function () { console.log(`READY ${this.address().port}`) })
