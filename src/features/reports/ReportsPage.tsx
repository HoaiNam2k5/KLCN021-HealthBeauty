import { useMemo, useState } from 'react'
import { Alert, Button, Card, Col, DatePicker, Empty, Result, Row, Spin, Statistic, Typography } from 'antd'
import { CalendarOutlined, StarFilled } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { useNavigate } from 'react-router-dom'
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { useAuth } from '../../hooks/useAuth'
import * as api from './reportQueries'
import * as t from '../../types/reports'
import type { Service } from '../../types/services'
const money=(v:number)=>`${new Intl.NumberFormat('vi-VN').format(v)} ₫`
export default function ReportsPage({home=false}:{home?:boolean}){
 const s=useAuth(),admin=(t.REPORT_ADMIN_ROLES as readonly string[]).includes(s?.account?.role??''),nav=useNavigate()
 if(!admin)return home?<Result status="success" title={t.REPORT_HOME_GREETING} subTitle={t.REPORT_ROLE_LIMITED_NOTE} extra={<Button type="primary" icon={<CalendarOutlined/>} onClick={()=>nav(t.REPORT_APPOINTMENTS_ROUTE)}>{t.REPORT_HOME_SHORTCUT}</Button>}/>:<Result status="403" title="403" subTitle={t.REPORT_ACCESS_DENIED}/>
 return <Dashboard home={home}/>
}
function Dashboard({home}:{home:boolean}){
 const [range,setRange]=useState<[Dayjs,Dayjs]>(()=>[dayjs().subtract(29,'day').startOf('day'),dayjs().endOf('day')])
 const from=range[0].format(t.REPORT_TIME_FORMAT),to=range[1].format(t.REPORT_TIME_FORMAT)
 const a=api.useAppointmentReport(from,to),r=api.useRevenueReport(from,to),s=api.useServiceReport(),c=api.useCustomerReport(),i=api.useReportInvoices(),v=api.useReportReviews(),al=api.useReportAppointments(),sl=api.useReportServices(),cl=api.useReportCustomers(),nav=useNavigate()
 const loading=[a,r,s,c,i,v,al,sl,cl].some(q=>q.isLoading),error=a.error??r.error??s.error??c.error??i.error??v.error??al.error??sl.error??cl.error
 const revenue=useMemo(()=>{const start=range[0].startOf('day'),end=range[1].endOf('day'),m=new Map<string,number>();(i.data??[]).filter(x=>x.status==='DaThanhToan').forEach(x=>{const d=dayjs(x.createdAt);if(!d.isValid()||d.isBefore(start)||d.isAfter(end))return;const k=d.format('YYYY-MM-DD');m.set(k,(m.get(k)??0)+x.total)});return Array.from({length:end.startOf('day').diff(start,'day')+1},(_,n)=>{const d=start.add(n,'day');return{date:d.format('DD/MM'),revenue:m.get(d.format('YYYY-MM-DD'))??0}})},[i.data,range])
 const dateField=useMemo(()=>t.REPORT_CUSTOMER_DATE_FIELDS.find(f=>(cl.data??[]).some(x=>typeof x[f]==='string'&&dayjs(x[f]).isValid())),[cl.data])
 const fresh=useMemo(()=>dateField?(cl.data??[]).filter(x=>{const d=x[dateField];return typeof d==='string'&&dayjs(d).isValid()&&!dayjs(d).isBefore(range[0].startOf('day'))&&!dayjs(d).isAfter(range[1].endOf('day'))}).length:null,[cl.data,dateField,range])
 const avg=useMemo(()=>v.data?.length?v.data.reduce((n,x)=>n+x.soSao,0)/v.data.length:null,[v.data])
 const names=useMemo(()=>new Map<number,string>((sl.data??[]).map((x:Service)=>[x.id,x.name??'Dịch vụ'])),[sl.data])
 const top=useMemo(()=>{const m=new Map<string,number>();(al.data??[]).forEach(x=>x.items?.forEach((y)=>{const n=y.serviceName||names.get(y.serviceId)||'Dịch vụ';m.set(n,(m.get(n)??0)+1)}));return [...m].map(([name,quantity])=>({name,quantity})).sort((x,y)=>y.quantity-x.quantity).slice(0,5)},[al.data,names])
 const status=(a.data??[]).map(x=>({ ...x,name:t.REPORT_STATUS_LABELS[x.status]??x.status,color:t.REPORT_STATUS_COLORS[x.status]??'#888888'})),total=status.reduce((n,x)=>n+x.count,0)
 const change=(x:[Dayjs|null,Dayjs|null]|null)=>{if(x?.[0]&&x[1])setRange([x[0].startOf('day'),x[1].endOf('day')])}
 return <section>
  <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',marginBottom:16}}><div><Typography.Title level={3} style={{margin:0}}>{home?'Tổng quan':t.REPORT_PAGE_TITLE}</Typography.Title><Typography.Text type="secondary">{t.REPORT_PAGE_DESCRIPTION}</Typography.Text></div>{!home&&<Button onClick={()=>nav('/')}>Trang chủ</Button>}</div>
  <Card size="small" style={{marginBottom:16}}><Typography.Text strong>{t.REPORT_DATE_FILTER_LABEL} </Typography.Text><DatePicker.RangePicker value={range} onChange={change} allowClear={false} format="DD/MM/YYYY"/><Typography.Text type="secondary">{t.REPORT_DATE_FILTER_NOTE}</Typography.Text></Card>
  {error&&<Alert type="error" showIcon message={t.REPORT_FETCH_ERROR} description={String(error)} style={{marginBottom:16}}/>}{loading?<Spin tip={t.REPORT_LOADING}/>:<>
   <Row gutter={[12,12]}>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số lịch hẹn" value={total}/></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số khách hàng" value={c.data?.length??0}/><Typography.Text type="secondary">{t.REPORT_TOTAL_CUSTOMERS_NOTE}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Tổng doanh thu" value={r.data?.revenue??0} formatter={x=>money(Number(x))}/><Typography.Text type="secondary">{t.REPORT_REVENUE_API_NOTE}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Khách mới" value={fresh??'—'}/><Typography.Text type="secondary">{fresh===null?t.REPORT_CUSTOMER_DATE_NOTE:'Khách tạo trong khoảng ngày đã chọn.'}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title={t.REPORT_AVERAGE_RATING_LABEL} value={avg===null?'—':avg.toFixed(1)} suffix={avg===null?'':<><StarFilled style={{color:'#B7791F'}}/> / 5</>}/><Typography.Text type="secondary">{t.REPORT_AVERAGE_RATING_NOTE}</Typography.Text></Card></Col>
   </Row>
   <Row gutter={[16,16]} style={{marginTop:12}}>
    <Col xs={24} xl={14}><Card title="Doanh thu theo ngày" extra={<Typography.Text type="secondary">{t.REPORT_CALCULATION_NOTE}</Typography.Text>}><Typography.Paragraph type="secondary">{t.REPORT_REVENUE_CHART_NOTE} {t.REPORT_CLIENT_REVENUE_NOTE}</Typography.Paragraph>{revenue.some(x=>x.revenue>0)?<ResponsiveContainer width="100%" height={t.REPORT_CHART_HEIGHT}><BarChart data={revenue} margin={t.REPORT_CHART_MARGIN}><CartesianGrid stroke={t.REPORT_GRID_COLOR}/><XAxis dataKey="date" tick={{fill:t.REPORT_TEXT_COLOR,fontSize:12}}/><YAxis tick={{fill:t.REPORT_TEXT_COLOR,fontSize:12}} tickFormatter={(x:number)=>new Intl.NumberFormat('vi-VN',{notation:'compact'}).format(x)}/><Tooltip formatter={x=>money(Number(x))}/><Bar dataKey="revenue" name="Doanh thu" fill={t.REPORT_CHART_COLOR} radius={[3,3,0,0]}/></BarChart></ResponsiveContainer>:<Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={t.REPORT_EMPTY_CHART}/>}</Card></Col>
    <Col xs={24} xl={10}><Card title="Lịch hẹn theo trạng thái"><Typography.Paragraph type="secondary">{t.REPORT_STATUS_SOURCE_NOTE}</Typography.Paragraph>{total?<ResponsiveContainer width="100%" height={t.REPORT_CHART_HEIGHT}><PieChart><Pie data={status} dataKey="count" nameKey="name" cx="50%" cy="50%" outerRadius={90} label={({name,value})=>`${name}: ${value}`}>{status.map(x=><Cell key={x.status} fill={x.color}/>)}</Pie><Tooltip/></PieChart></ResponsiveContainer>:<Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={t.REPORT_EMPTY}/>}</Card></Col>
    <Col xs={24} xl={14}><Card title="Dịch vụ được đặt nhiều nhất"><Typography.Paragraph type="secondary">{t.REPORT_SERVICE_SOURCE_NOTE}</Typography.Paragraph>{top.length?<ResponsiveContainer width="100%" height={t.REPORT_CHART_HEIGHT}><BarChart data={s.data?.length?s.data.slice(0,5).map(x=>({name:x.name??'Dịch vụ',quantity:x.quantity})):top} layout="vertical" margin={t.REPORT_CHART_MARGIN}><CartesianGrid stroke={t.REPORT_GRID_COLOR}/><XAxis type="number" allowDecimals={false}/><YAxis type="category" dataKey="name" width={140} tick={{fontSize:12}}/><Tooltip/><Bar dataKey="quantity" name="Lượt đặt" fill="#2F7D4F" radius={[0,3,3,0]}/></BarChart></ResponsiveContainer>:<Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={t.REPORT_EMPTY_CHART}/>}</Card></Col>
    <Col xs={24} xl={10}><Card title="Số lịch theo trạng thái">{status.length?status.map(x=><div key={x.status} style={{display:'flex',justifyContent:'space-between',padding:'8px 0',borderBottom:'1px solid #dedbd6'}}><span>{x.name}</span><Typography.Text strong>{x.count}</Typography.Text></div>):<Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={t.REPORT_EMPTY}/>}<Typography.Paragraph type="secondary" style={{marginTop:12}}>{t.REPORT_SERVICES_CUSTOMERS_NOTE}</Typography.Paragraph></Card></Col>
   </Row>
   <Typography.Paragraph type="secondary" style={{marginTop:16}}>{t.REPORT_CUSTOMER_DATE_DISCLOSURE}</Typography.Paragraph>
   {v.isError&&<Alert type="warning" message="Không tải được dữ liệu đánh giá."/>}{i.isError&&<Alert type="warning" message="Không tải được hóa đơn để vẽ doanh thu theo ngày."/>}{al.isError&&<Alert type="warning" message="Không tải được lịch hẹn để đối chiếu dịch vụ."/>}
   <Typography.Text type="secondary" style={{display:'block'}}>Tổng doanh thu API: {money(r.data?.revenue??0)}. Số hóa đơn: {r.data?.invoiceCount??0}. Tổng lịch trong kỳ: {total}.</Typography.Text>
  </>}
 </section>
}
