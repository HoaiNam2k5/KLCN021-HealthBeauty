import { useMemo, useState } from 'react'
import { Alert, Button, Card, Col, DatePicker, Empty, Result, Row, Spin, Statistic, Typography } from 'antd'
import { CalendarOutlined, StarFilled } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { useNavigate } from 'react-router-dom'
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { useAuth } from '../../hooks/useAuth'
import * as reportQueries from './reportQueries'
import * as reportText from '../../types/reports'
import { getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import type { Service } from '../../types/services'

interface StatusChartItem { status: string; count: number; name: string; color: string }
interface RevenueChartItem { date: string; revenue: number }
interface TopServiceItem { name: string; quantity: number }
const formatMoney = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

export default function ReportsPage({ home = false }: { home?: boolean }) {
  const session = useAuth()
  const navigate = useNavigate()
  const canViewReports = (reportText.REPORT_ADMIN_ROLES as readonly string[]).includes(session?.account?.role ?? '')
  if (!canViewReports) return home ? <Result status="success" title={reportText.REPORT_HOME_GREETING} subTitle={reportText.REPORT_ROLE_LIMITED_NOTE} extra={<Button type="primary" icon={<CalendarOutlined />} onClick={() => navigate(reportText.REPORT_APPOINTMENTS_ROUTE)}>{reportText.REPORT_HOME_SHORTCUT}</Button>} /> : <Result status="403" title="403" subTitle={reportText.REPORT_ACCESS_DENIED} />
  return <ReportsDashboard home={home} />
}
function ReportsDashboard({ home }: { home: boolean }) {
 const [dateRange,setDateRange]=useState<[Dayjs,Dayjs]>(()=>[dayjs().subtract(29,'day').startOf('day'),dayjs().endOf('day')])
 const from=dateRange[0].format(reportText.REPORT_TIME_FORMAT)
 const to=dateRange[1].format(reportText.REPORT_TIME_FORMAT)
 const appointmentReport=reportQueries.useAppointmentReport(from,to)
 const revenueReport=reportQueries.useRevenueReport(from,to)
 const serviceReport=reportQueries.useServiceReport()
 const customerReport=reportQueries.useCustomerReport()
 const invoiceList=reportQueries.useReportInvoices()
 const reviewList=reportQueries.useReportReviews()
 const appointmentList=reportQueries.useReportAppointments()
 const serviceList=reportQueries.useReportServices()
 const customerList=reportQueries.useReportCustomers()
 const navigate=useNavigate()
 const queryList=[appointmentReport,revenueReport,serviceReport,customerReport,invoiceList,reviewList,appointmentList,serviceList,customerList]
 const isLoading=queryList.some((query)=>query.isLoading)
 const firstError=queryList.find((query)=>query.error)?.error
 const appointmentStatuses=useMemo(()=> (appointmentReport.data??[]).map((item)=>{const presentation=getAppointmentStatusPresentation(item.status);return {...item,name:presentation.label,color:presentation.color}}),[appointmentReport.data])
 const appointmentCount=appointmentStatuses.reduce((count,item)=>count+item.count,0)
 const revenueByDay=useMemo(()=>buildRevenueChart(invoiceList.data??[],dateRange),[invoiceList.data,dateRange])
 const customerDateField=useMemo(()=>reportText.REPORT_CUSTOMER_DATE_FIELDS.find((field)=>(customerList.data??[]).some((customer)=>typeof customer[field]==='string'&&dayjs(customer[field]).isValid())),[customerList.data])
 const newCustomerCount=useMemo(()=>customerDateField?(customerList.data??[]).filter((customer)=>{const createdAt=customer[customerDateField];return typeof createdAt==='string'&&dayjs(createdAt).isValid()&&!dayjs(createdAt).isBefore(dateRange[0].startOf('day'))&&!dayjs(createdAt).isAfter(dateRange[1].endOf('day'))}).length:null,[customerList.data,customerDateField,dateRange])
 const averageRating=useMemo(()=>reviewList.data?.length?reviewList.data.reduce((ratingTotal,review)=>ratingTotal+review.soSao,0)/reviewList.data.length:null,[reviewList.data])
 const serviceNames=useMemo(()=>new Map<number,string>((serviceList.data??[]).map((service:Service)=>[service.id,service.name??'Dịch vụ'])),[serviceList.data])
 const topServices=useMemo(()=>buildTopServices(appointmentList.data??[],serviceNames),[appointmentList.data,serviceNames])
 const handleDateRangeChange=(value:[Dayjs|null,Dayjs|null]|null)=>{if(value?.[0]&&value[1])setDateRange([value[0].startOf('day'),value[1].endOf('day')])}
 return (
  <section>
   <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',marginBottom:16}}>
    <div><Typography.Title level={3} style={{margin:0}}>{home?'Tổng quan':reportText.REPORT_PAGE_TITLE}</Typography.Title><Typography.Text type="secondary">{reportText.REPORT_PAGE_DESCRIPTION}</Typography.Text></div>
    {!home&&<Button onClick={()=>navigate('/')}>Trang chủ</Button>}
   </div>
   <Card size="small" style={{marginBottom:16}}><Typography.Text strong>{reportText.REPORT_DATE_FILTER_LABEL} </Typography.Text><DatePicker.RangePicker value={dateRange} onChange={handleDateRangeChange} allowClear={false} format="DD/MM/YYYY"/><Typography.Text type="secondary">{reportText.REPORT_DATE_FILTER_NOTE}</Typography.Text></Card>
   {firstError&&<Alert type="error" showIcon message={reportText.REPORT_FETCH_ERROR} description={String(firstError)} style={{marginBottom:16}}/>}
   {isLoading?<Spin tip={reportText.REPORT_LOADING}/>:<>
    <OverviewCards appointmentCount={appointmentCount} customerCount={customerReport.data?.length??0} revenue={revenueReport.data?.revenue??0} newCustomerCount={newCustomerCount} averageRating={averageRating}/>
    <Row gutter={[16,16]} style={{marginTop:12}}>
     <Col xs={24} xl={14}><RevenueChart revenueByDay={revenueByDay}/></Col>
     <Col xs={24} xl={10}><AppointmentStatusChart statuses={appointmentStatuses} appointmentCount={appointmentCount}/></Col>
     <Col xs={24} xl={14}><TopServicesChart serviceReport={serviceReport.data??[]} topServices={topServices}/></Col>
     <Col xs={24} xl={10}><AppointmentStatusSummary statuses={appointmentStatuses}/></Col>
    </Row>
    <Typography.Paragraph type="secondary" style={{marginTop:16}}>{reportText.REPORT_CUSTOMER_DATE_DISCLOSURE}</Typography.Paragraph>
    {reviewList.isError&&<Alert type="warning" message="Không tải được dữ liệu đánh giá."/>}
    {invoiceList.isError&&<Alert type="warning" message="Không tải được hóa đơn để vẽ doanh thu theo ngày."/>}
    {appointmentList.isError&&<Alert type="warning" message="Không tải được lịch hẹn để đối chiếu dịch vụ."/>}
    <Typography.Text type="secondary" style={{display:'block'}}>Tổng doanh thu API: {formatMoney(revenueReport.data?.revenue??0)}. Số hóa đơn: {revenueReport.data?.invoiceCount??0}. Tổng lịch trong kỳ: {appointmentCount}.</Typography.Text>
   </>}
  </section>
 )
}

function OverviewCards({ appointmentCount, customerCount, revenue, newCustomerCount, averageRating }: { appointmentCount: number; customerCount: number; revenue: number; newCustomerCount: number | null; averageRating: number | null }) {
  return <Row gutter={[12, 12]}>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số lịch hẹn" value={appointmentCount} /></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số khách hàng" value={customerCount} /><Typography.Text type="secondary">{reportText.REPORT_TOTAL_CUSTOMERS_NOTE}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Tổng doanh thu" value={revenue} formatter={(value) => formatMoney(Number(value))} /><Typography.Text type="secondary">{reportText.REPORT_REVENUE_API_NOTE}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Khách mới" value={newCustomerCount ?? '—'} /><Typography.Text type="secondary">{newCustomerCount === null ? reportText.REPORT_CUSTOMER_DATE_NOTE : 'Khách tạo trong khoảng ngày đã chọn.'}</Typography.Text></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title={reportText.REPORT_AVERAGE_RATING_LABEL} value={averageRating === null ? '—' : averageRating.toFixed(1)} suffix={averageRating === null ? '' : <><StarFilled style={{ color: '#B7791F' }} /> / 5</>} /><Typography.Text type="secondary">{reportText.REPORT_AVERAGE_RATING_NOTE}</Typography.Text></Card></Col>
  </Row>
}

function RevenueChart({ revenueByDay }: { revenueByDay: RevenueChartItem[] }) {
  return <Card title="Doanh thu theo ngày" extra={<Typography.Text type="secondary">{reportText.REPORT_CALCULATION_NOTE}</Typography.Text>}>
    <Typography.Paragraph type="secondary">{reportText.REPORT_REVENUE_CHART_NOTE} {reportText.REPORT_CLIENT_REVENUE_NOTE}</Typography.Paragraph>
    {revenueByDay.some((item) => item.revenue > 0) ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={revenueByDay} margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR}/><XAxis dataKey="date"/><YAxis tickFormatter={(value:number)=>new Intl.NumberFormat('vi-VN',{notation:'compact'}).format(value)}/><Tooltip formatter={(value)=>formatMoney(Number(value))}/><Bar dataKey="revenue" name="Doanh thu" fill={reportText.REPORT_CHART_COLOR} radius={[3,3,0,0]}/></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART}/>}
  </Card>
}

function AppointmentStatusChart({ statuses, appointmentCount }: { statuses: StatusChartItem[]; appointmentCount: number }) {
  return <Card title="Lịch hẹn theo trạng thái"><Typography.Paragraph type="secondary">{reportText.REPORT_STATUS_SOURCE_NOTE}</Typography.Paragraph>
    {appointmentCount ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><PieChart><Pie data={statuses} dataKey="count" nameKey="name" cx="50%" cy="50%" outerRadius={90} label={({name,value})=>`${name}: ${value}`}>{statuses.map((item)=><Cell key={item.status} fill={item.color}/>)}</Pie><Tooltip/></PieChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY}/>}
  </Card>
}

function TopServicesChart({ serviceReport, topServices }: { serviceReport: { name: string; quantity: number }[]; topServices: TopServiceItem[] }) {
  const chartData = serviceReport.length ? serviceReport.slice(0, reportText.REPORT_SERVICE_LIMIT).map((service) => ({ name: service.name || reportText.REPORT_UNKNOWN_SERVICE, quantity: service.quantity })) : topServices
  return <Card title="Dịch vụ được đặt nhiều nhất"><Typography.Paragraph type="secondary">{reportText.REPORT_SERVICE_SOURCE_NOTE}</Typography.Paragraph>
    {chartData.length ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={chartData} layout="vertical" margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR}/><XAxis type="number" allowDecimals={false}/><YAxis type="category" dataKey="name" width={140} tick={{fontSize:12}}/><Tooltip/><Bar dataKey="quantity" name="Lượt đặt" fill="#2F7D4F" radius={[0,3,3,0]}/></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART}/>}
  </Card>
}

function AppointmentStatusSummary({ statuses }: { statuses: StatusChartItem[] }) {
  return <Card title="Số lịch theo trạng thái">{statuses.length ? statuses.map((item)=><div key={item.status} style={{display:'flex',justifyContent:'space-between',padding:'8px 0',borderBottom:'1px solid #dedbd6'}}><span>{item.name}</span><Typography.Text strong>{item.count}</Typography.Text></div>) : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY}/>}<Typography.Paragraph type="secondary" style={{marginTop:12}}>{reportText.REPORT_SERVICES_CUSTOMERS_NOTE}</Typography.Paragraph></Card>
}

function buildRevenueChart(invoices: { createdAt: string; total: number; status: string }[], dateRange: [Dayjs, Dayjs]): RevenueChartItem[] {
  const startDate = dateRange[0].startOf('day')
  const endDate = dateRange[1].startOf('day')
  const revenueByDate = new Map<string, number>()
  invoices.filter((invoice) => invoice.status === reportText.PAID_INVOICE_STATUS).forEach((invoice) => {
    const invoiceDate = dayjs(invoice.createdAt)
    if (!invoiceDate.isValid() || invoiceDate.isBefore(startDate) || invoiceDate.isAfter(dateRange[1].endOf('day'))) return
    const dateKey = invoiceDate.format('YYYY-MM-DD')
    revenueByDate.set(dateKey, (revenueByDate.get(dateKey) ?? 0) + invoice.total)
  })
  const dayCount = endDate.diff(startDate, 'day') + 1
  return Array.from({ length: dayCount }, (_, offset) => {
    const date = startDate.add(offset, 'day')
    return { date: date.format(reportText.REPORT_DAY_FORMAT), revenue: revenueByDate.get(date.format('YYYY-MM-DD')) ?? 0 }
  })
}

function buildTopServices(appointments: { items: { serviceId: number; serviceName: string }[] }[], serviceNames: Map<number, string>): TopServiceItem[] {
  const serviceCounts = new Map<string, number>()
  appointments.forEach((appointment) => appointment.items.forEach((item) => {
    const serviceName = item.serviceName || serviceNames.get(item.serviceId) || reportText.REPORT_UNKNOWN_SERVICE
    serviceCounts.set(serviceName, (serviceCounts.get(serviceName) ?? 0) + 1)
  }))
  return [...serviceCounts].map(([name, quantity]) => ({ name, quantity })).sort((first, second) => second.quantity - first.quantity).slice(0, reportText.REPORT_SERVICE_LIMIT)
}
