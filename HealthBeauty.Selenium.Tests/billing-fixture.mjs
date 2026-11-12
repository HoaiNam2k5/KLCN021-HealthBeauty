// Local in-memory API fixture for rendered React billing tests. No external calls.
import http from 'node:http'
import { readFile } from 'node:fs/promises'
import { extname, resolve, sep } from 'node:path'

const dist = resolve(process.argv[2] || '')
if (!process.argv[2]) throw new Error('Missing web dist')
let paid = false, mismatched = false, detailReads = 0
const invoice = () => ({ id: 801, appointmentId: 901, customerId: 1, createdAt: '2026-11-06T10:00:00', subtotal: 300000, total: 300000,
  status: paid ? 'DaThanhToan' : 'ChuaThanhToan', items: [{ id: 1, serviceId: 1, serviceName: 'Chăm sóc da kiểm thử hóa đơn', comboId: null, comboName: null, quantity: 1, unitPrice: 300000 }],
  payments: paid ? [{ id: 501, method: 'ChuyenKhoan', amount: 300000, paidAt: '2026-11-06T11:00:00', status: 'ThanhCong' }] : [] })
const account = { accessToken: 'fixture-access', refreshToken: 'fixture-refresh', accessTokenExpiresAt: '2099-01-01T00:00:00Z', account: { id: 999, name: 'Lễ tân hóa đơn', email: 'billing@example.test', role: 'Reception' } }
const json = (res, data, code = 200) => {res.writeHead(code, {'Content-Type':'application/json; charset=utf-8', 'Cache-Control':'no-store'});res.end(JSON.stringify(data))}
const mime = {'.html':'text/html; charset=utf-8','.js':'text/javascript; charset=utf-8','.css':'text/css; charset=utf-8','.png':'image/png','.svg':'image/svg+xml','.ico':'image/x-icon','.woff2':'font/woff2'}
http.createServer(async (req,res) => {
  try {
    const path = new URL(req.url,'http://127.0.0.1').pathname
    if (path === '/__fixture/reset') {paid=false;mismatched=false;detailReads=0;return json(res,{ok:true})}
    if (path === '/__fixture/paid') {paid=true;return json(res,{ok:true})}
    if (path === '/__fixture/mismatch') {mismatched=true;return json(res,{ok:true})}
    if (path === '/__fixture/reads') return json(res,{detailReads})
    if (path.startsWith('/api/v1/')) {
      let raw='';for await (const chunk of req) raw+=chunk
      const data=raw?JSON.parse(raw):{}
      const api=path.slice('/api/v1'.length)
      if (api==='/auth/login') return data.email==='billing@example.test'&&data.password==='FixtureOnly123!'?json(res,account):json(res,{},401)
      if (api==='/auth/refresh') return json(res,account)
      if (api==='/auth/permissions') return json(res,{role:'Reception',permissions:['INVOICE.READ','CUSTOMER.READ','APPOINTMENT.READ','SERVICE.READ']})
      if (api==='/customers') return json(res,[{id:1,fullName:'Khách hàng hóa đơn kiểm thử'}])
      if (api==='/appointments') return json(res,{items:[],totalCount:0,page:1,pageSize:100})
      if (api==='/invoices') return json(res,[invoice()])
      if (api==='/invoices/801') {detailReads++;return json(res,invoice())}
      if (api==='/invoices/801/bank-transfer') return json(res,{invoiceId:801,amount:mismatched?1:300000,status:'ChuaThanhToan',bankName:'Ngân hàng kiểm thử',bankCode:'TEST',accountNumber:'000111222',accountName:'TAI KHOAN GIA LAP',transferContent:'HB801',qrImageUrl:'https://vietqr.app/img?acc=000111222&bank=TEST&amount=300000&des=HB801'})
      if (api==='/services') return json(res,[{id:1,name:'Chăm sóc da kiểm thử hóa đơn',price:300000,durationMinutes:60,active:true}])
      return json(res,[])
    }
    const target=resolve(dist,'.'+decodeURIComponent(path))
    if (target!==dist&&!target.startsWith(dist+sep)) return json(res,{},403)
    let file=target,body
    try {body=await readFile(file)} catch {file=resolve(dist,'index.html');body=await readFile(file)}
    res.writeHead(200,{'Content-Type':mime[extname(file)]||'application/octet-stream','Content-Security-Policy':"default-src 'self' data: blob:; connect-src 'self'; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; font-src 'self' data:;"});res.end(body)
  } catch {json(res,{message:'Fixture error'},500)}
}).listen(0,'127.0.0.1',function(){console.log(`READY ${this.address().port}`)})
