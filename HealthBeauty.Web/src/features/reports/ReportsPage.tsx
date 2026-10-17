import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Col, DatePicker, Empty, Result, Row, Spin, Statistic, Typography } from 'antd'
import { CalendarOutlined, DownloadOutlined, PrinterOutlined, StarFilled } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { useNavigate } from 'react-router-dom'
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { usePermissions } from '../../hooks/usePermissions'
import * as reportQueries from './reportQueries'
import * as reportText from '../../types/reports'
import { getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import type { Service } from '../../types/services'

interface StatusChartItem { status: string; count: number; name: string; color: string }
interface RevenueChartItem { date: string; revenue: number }
interface TopServiceItem { name: string; quantity: number }
const formatMoney = (amount: number) => `${new Intl.NumberFormat('vi-VN').format(amount)} ₫`

export default function ReportsPage({ home = false }: { home?: boolean }) {
  const { has, canVisit } = usePermissions()
  const navigate = useNavigate()
  const canViewReports = has('REPORT.READ')
  if (!canViewReports) return home ? <Result status="success" title={reportText.REPORT_HOME_GREETING} extra={canVisit(reportText.REPORT_APPOINTMENTS_ROUTE) ? <Button type="primary" icon={<CalendarOutlined />} onClick={() => navigate(reportText.REPORT_APPOINTMENTS_ROUTE)}>{reportText.REPORT_HOME_SHORTCUT}</Button> : undefined} /> : <Result status="403" title="403" subTitle={reportText.REPORT_ACCESS_DENIED} />
  return <ReportsDashboard home={home} />
}
function ReportsDashboard({ home }: { home: boolean }) {
 const { message } = App.useApp()
 const { has } = usePermissions()
 const [dateRange,setDateRange]=useState<[Dayjs,Dayjs]>(()=>[dayjs().subtract(29,'day').startOf('day'),dayjs().endOf('day')])
 const from=dateRange[0].format(reportText.REPORT_TIME_FORMAT)
 const to=dateRange[1].format(reportText.REPORT_TIME_FORMAT)
 const appointmentReport=reportQueries.useAppointmentReport(from,to)
 const revenueReport=reportQueries.useRevenueReport(from,to)
 const serviceReport=reportQueries.useServiceReport()
 const customerReport=reportQueries.useCustomerReport()
 const invoiceList=reportQueries.useReportInvoices(has('INVOICE.READ'))
 const reviewList=reportQueries.useReportReviews()
 const appointmentList=reportQueries.useReportAppointments(has('APPOINTMENT.READ'))
 const serviceList=reportQueries.useReportServices()
 const customerList=reportQueries.useReportCustomers(has('CUSTOMER.READ'))
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
  const reportRevenue = revenueReport.data?.revenue ?? 0
  const exportToCsv = () => {
   const csvCell = (value: string | number) => `"${String(value).replace(/"/g, '""')}"`
   const rows: (string | number)[][] = [
    ['=== BÁO CÁO HOẠT ĐỘNG HEALTHBEAUTY SPA & CLINIC ==='],
    [`Thời gian báo cáo: Từ ${dateRange[0].format('DD/MM/YYYY')} đến ${dateRange[1].format('DD/MM/YYYY')}`],
    [`Ngày xuất: ${dayjs().format('DD/MM/YYYY HH:mm')}`], [],
    ['--- 1. TỔNG QUAN CHỈ SỐ ---'], ['Chỉ số', 'Giá trị'],
    ['Tổng doanh thu', formatMoney(reportRevenue)], ['Tổng số lịch hẹn', appointmentCount], ['Khách hàng mới', newCustomerCount ?? 'Không có dữ liệu'],
    ['Điểm đánh giá trung bình', `${averageRating === null ? '—' : averageRating.toFixed(1)}/5`], [],
    ['--- 2. LỊCH HẸN THEO TRẠNG THÁI ---'], ['Trạng thái', 'Số lượng'], ...appointmentStatuses.map((item) => [item.name, item.count]), [],
    ['--- 3. DOANH THU THEO NGÀY ---'], ['Ngày', 'Doanh thu (₫)'], ...revenueByDay.map((item) => [item.date, item.revenue]), [],
    ['--- 4. TOP DỊCH VỤ ĐƯỢC ĐẶT NHIỀU NHẤT ---'], ['Tên dịch vụ', 'Số lượt đặt'],
    ...(serviceReport.data?.length ? serviceReport.data.slice(0, reportText.REPORT_SERVICE_LIMIT).map((item) => [item.name || reportText.REPORT_UNKNOWN_SERVICE, item.quantity]) : topServices.map((item) => [item.name, item.quantity])),
   ]
   const csv = '\uFEFF' + rows.map((row) => row.map(csvCell).join(',')).join('\r\n')
   const url = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8;' }))
   const link = document.createElement('a')
   link.href = url
   link.download = `Bao_Cao_HealthBeauty_${dateRange[0].format('YYYY-MM-DD')}_${dateRange[1].format('YYYY-MM-DD')}.csv`
   document.body.appendChild(link); link.click(); link.remove(); URL.revokeObjectURL(url)
   message.success('Xuất file báo cáo thành công!')
  }
  const handlePrint = () => window.print()
  return (
   <section className="healthbeauty-report-page">
    <style>{`@media print { @page { size: A4; margin: 14mm; } body * { visibility: hidden !important; } .healthbeauty-report-page, .healthbeauty-report-page * { visibility: visible !important; } .healthbeauty-report-page { position: absolute !important; inset: 0 auto auto 0 !important; width: 100% !important; margin: 0 !important; padding: 0 !important; background: #fff !important; } .report-no-print, .report-filters, .ant-layout-sider, .ant-menu, .page-heading button { display: none !important; } .healthbeauty-report-page .ant-card { break-inside: avoid; box-shadow: none !important; } }`}</style>
   <div className="page-heading">
    <div><Typography.Title level={3} style={{margin:0}}>{home?'Tổng quan':reportText.REPORT_PAGE_TITLE}</Typography.Title></div>
    {!home&&<Button onClick={()=>navigate('/')}>Trang chủ</Button>}
   </div>
   <Card className="report-filters" size="small" style={{marginBottom:16}}><div className="filter-bar"><Typography.Text strong>{reportText.REPORT_DATE_FILTER_LABEL} </Typography.Text><DatePicker.RangePicker value={dateRange} onChange={handleDateRangeChange} allowClear={false} format="DD/MM/YYYY" placeholder={['Từ ngày', 'Đến ngày']} style={{maxWidth:'100%'}}/><Button className="report-no-print" icon={<DownloadOutlined />} disabled={isLoading} onClick={exportToCsv}>Xuất Excel</Button><Button className="report-no-print" icon={<PrinterOutlined />} disabled={isLoading} onClick={handlePrint}>In báo cáo</Button></div></Card>
   {firstError&&<Alert type="error" showIcon message={reportText.REPORT_FETCH_ERROR} description={String(firstError)} style={{marginBottom:16}}/>}
   {isLoading?<Spin tip={reportText.REPORT_LOADING}/>:<>
    <OverviewCards appointmentCount={appointmentCount} customerCount={customerReport.data?.length??0} revenue={revenueReport.data?.revenue??0} newCustomerCount={newCustomerCount} averageRating={averageRating}/>
    <Row gutter={[16,16]} style={{marginTop:12}}>
     <Col xs={24} xl={14}><RevenueChart revenueByDay={revenueByDay}/></Col>
     <Col xs={24} xl={10}><AppointmentStatusChart statuses={appointmentStatuses} appointmentCount={appointmentCount}/></Col>
     <Col xs={24} xl={14}><TopServicesChart serviceReport={serviceReport.data??[]} topServices={topServices}/></Col>
     <Col xs={24} xl={10}><AppointmentStatusSummary statuses={appointmentStatuses}/></Col>
    </Row>

    {reviewList.isError&&<Alert type="warning" message="Không tải được dữ liệu đánh giá."/>}
    {invoiceList.isError&&<Alert type="warning" message="Không tải được hóa đơn để vẽ doanh thu theo ngày."/>}
    {appointmentList.isError&&<Alert type="warning" message="Không tải được lịch hẹn để đối chiếu dịch vụ."/>}

   </>}
  </section>
 )
}

function OverviewCards({ appointmentCount, customerCount, revenue, newCustomerCount, averageRating }: { appointmentCount: number; customerCount: number; revenue: number; newCustomerCount: number | null; averageRating: number | null }) {
  return <Row gutter={[12, 12]}>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số lịch hẹn" value={appointmentCount} /></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Số khách hàng" value={customerCount} /></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Tổng doanh thu" value={revenue} formatter={(value) => formatMoney(Number(value))} /></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title="Khách mới" value={newCustomerCount ?? '—'} /></Card></Col>
    <Col xs={24} sm={12} lg={6}><Card><Statistic title={reportText.REPORT_AVERAGE_RATING_LABEL} value={averageRating === null ? '—' : averageRating.toFixed(1)} suffix={averageRating === null ? '' : <><StarFilled style={{ color: '#B7791F' }} /> / 5</>} /></Card></Col>
  </Row>
}

function RevenueChart({ revenueByDay }: { revenueByDay: RevenueChartItem[] }) {
  return <Card title="Doanh thu theo ngày">

    {revenueByDay.some((item) => item.revenue > 0) ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={revenueByDay} margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR}/><XAxis dataKey="date"/><YAxis tickFormatter={(value:number)=>new Intl.NumberFormat('vi-VN',{notation:'compact'}).format(value)}/><Tooltip formatter={(value)=>formatMoney(Number(value))}/><Bar dataKey="revenue" name="Doanh thu" fill={reportText.REPORT_CHART_COLOR} radius={[3,3,0,0]}/></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART}/>}
  </Card>
}

function AppointmentStatusChart({ statuses, appointmentCount }: { statuses: StatusChartItem[]; appointmentCount: number }) {
  return <Card title="Lịch hẹn theo trạng thái">
    {appointmentCount ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><PieChart><Pie data={statuses} dataKey="count" nameKey="name" cx="50%" cy="50%" outerRadius={90} label={({name,value})=>`${name}: ${value}`}>{statuses.map((item)=><Cell key={item.status} fill={item.color}/>)}</Pie><Tooltip/></PieChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY}/>}
  </Card>
}

function TopServicesChart({ serviceReport, topServices }: { serviceReport: { name: string; quantity: number }[]; topServices: TopServiceItem[] }) {
  const chartData = serviceReport.length ? serviceReport.slice(0, reportText.REPORT_SERVICE_LIMIT).map((service) => ({ name: service.name || reportText.REPORT_UNKNOWN_SERVICE, quantity: service.quantity })) : topServices
  return <Card title="Dịch vụ được đặt nhiều nhất">
    {chartData.length ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={chartData} layout="vertical" margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR}/><XAxis type="number" allowDecimals={false}/><YAxis type="category" dataKey="name" width={140} tick={{fontSize:12}}/><Tooltip/><Bar dataKey="quantity" name="Lượt đặt" fill="#2F7D4F" radius={[0,3,3,0]}/></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART}/>}
  </Card>
}

function AppointmentStatusSummary({ statuses }: { statuses: StatusChartItem[] }) {
  return <Card title="Số lịch theo trạng thái">{statuses.length ? statuses.map((item)=><div key={item.status} style={{display:'flex',justifyContent:'space-between',padding:'8px 0',borderBottom:'1px solid #dedbd6'}}><span>{item.name}</span><Typography.Text strong>{item.count}</Typography.Text></div>) : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY}/>}</Card>
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
