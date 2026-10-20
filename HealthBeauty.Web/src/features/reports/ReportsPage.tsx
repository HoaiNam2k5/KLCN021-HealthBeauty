import { useMemo, useState } from 'react'
import { Alert, App, Button, Card, Col, DatePicker, Empty, Result, Row, Select, Spin, Statistic, Typography } from 'antd'
import { CalendarOutlined, DownloadOutlined, PrinterOutlined, StarFilled } from '@ant-design/icons'
import dayjs, { type Dayjs } from 'dayjs'
import { useNavigate } from 'react-router-dom'
import { Bar, BarChart, CartesianGrid, Cell, Pie, PieChart, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { usePermissions } from '../../hooks/usePermissions'
import { exportReportXlsx } from '../../api/reports'
import * as reportQueries from './reportQueries'
import * as reportText from '../../types/reports'
import { getAppointmentStatusPresentation } from '../appointments/appointmentStatus'
import type { ReportFilterParams } from '../../types/reports'

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
  const navigate = useNavigate()
  const [dateRange, setDateRange] = useState<[Dayjs, Dayjs]>(() => [dayjs().subtract(29, 'day').startOf('day'), dayjs().startOf('day')])
  const [groupBy, setGroupBy] = useState<'day' | 'week' | 'month' | 'quarter' | 'year'>('day')
  const [breakdownBy, setBreakdownBy] = useState<'service' | 'combo' | 'staff' | 'category'>('service')
  const from = dateRange[0].startOf('day').format(reportText.REPORT_TIME_FORMAT)
  const to = dateRange[1].add(1, 'day').startOf('day').format(reportText.REPORT_TIME_FORMAT)
  const params: ReportFilterParams = { from, to, groupBy }
  const appointmentSummary = reportQueries.useAppointmentSummary({ from, to, groupBy: 'status' })
  const orderSummary = reportQueries.useOrderSummary(params)
  const orderBreakdown = reportQueries.useOrderBreakdown({ from, to, groupBy: breakdownBy })
  const newCustomers = reportQueries.useNewCustomers(params)
  const packageSales = reportQueries.usePackageSales(from, to)
  const reviewList = reportQueries.useReportReviews()
  const customerList = reportQueries.useReportCustomers()
  const queries = [appointmentSummary, orderSummary, orderBreakdown, newCustomers, reviewList, customerList, packageSales]
  const isLoading = queries.some((query) => query.isLoading)
  const firstError = queries.find((query) => query.error)?.error
  const statuses = useMemo<StatusChartItem[]>(() => (appointmentSummary.data?.items ?? []).map((item) => {
    const presentation = getAppointmentStatusPresentation(item.status)
    return { ...item, name: presentation.label, color: presentation.color }
  }), [appointmentSummary.data])
  const appointmentCount = appointmentSummary.data?.totalCount ?? statuses.reduce((sum, item) => sum + item.count, 0)
  const revenueItems = useMemo<RevenueChartItem[]>(() => (orderSummary.data?.items ?? []).map((item) => ({ date: groupBy === 'quarter' ? `Q${Math.floor(dayjs(item.periodStart).month() / 3) + 1}/${dayjs(item.periodStart).format('YYYY')}` : dayjs(item.periodStart).format(groupBy === 'day' ? reportText.REPORT_DAY_FORMAT : groupBy === 'week' ? 'DD/MM' : groupBy === 'year' ? 'YYYY' : 'MM/YYYY'), revenue: item.paidRevenue })), [orderSummary.data, groupBy])
  const topServices = useMemo<TopServiceItem[]>(() => (orderBreakdown.data?.items ?? []).map((item) => ({ name: item.name || reportText.REPORT_UNKNOWN_SERVICE, quantity: item.quantity ?? 0 })).sort((a, b) => (b.quantity ?? 0) - (a.quantity ?? 0)).slice(0, reportText.REPORT_SERVICE_LIMIT), [orderBreakdown.data])
  const averageRating = reviewList.data ? reviewList.data.averageRating : null
  const newCustomerCount = newCustomers.data?.totalCount ?? 0
  const handleDateRangeChange = (value: [Dayjs | null, Dayjs | null] | null) => { if (value?.[0] && value[1]) setDateRange([value[0].startOf('day'), value[1].startOf('day')]) }

  async function exportXlsx() {
    try {
      const blob = await exportReportXlsx('orders', { from, to, groupBy })
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `Bao_Cao_HealthBeauty_${dateRange[0].format('YYYY-MM-DD')}_${dateRange[1].format('YYYY-MM-DD')}.xlsx`
      document.body.appendChild(link); link.click(); link.remove(); URL.revokeObjectURL(url)
      message.success('Xuất file Excel báo cáo thành công!')
    } catch (error: unknown) { message.error(String(error)) }
  }

  return <section className="healthbeauty-report-page">
    <style>{`@media print { @page { size: A4; margin: 14mm; } body * { visibility: hidden !important; } .healthbeauty-report-page, .healthbeauty-report-page * { visibility: visible !important; } .healthbeauty-report-page { position: absolute !important; inset: 0 auto auto 0 !important; width: 100% !important; margin: 0 !important; padding: 0 !important; background: #fff !important; } .report-no-print, .report-filters, .ant-layout-sider, .ant-menu, .page-heading button { display: none !important; } .healthbeauty-report-page .ant-card { break-inside: avoid; box-shadow: none !important; } }`}</style>
    <div className="page-heading"><div><Typography.Title level={3} style={{ margin: 0 }}>{home ? reportText.REPORT_HOME_GREETING : reportText.REPORT_PAGE_TITLE}</Typography.Title></div>{!home && <Button onClick={() => navigate('/')}>Trang chủ</Button>}</div>
    <Card className="report-filters" size="small" style={{ marginBottom: 16 }}><div className="filter-bar"><Typography.Text strong>{reportText.REPORT_DATE_FILTER_LABEL} </Typography.Text><DatePicker.RangePicker value={dateRange} onChange={handleDateRangeChange} allowClear={false} format="DD/MM/YYYY" placeholder={['Từ ngày', 'Đến ngày']} style={{ maxWidth: '100%' }} /><Select value={groupBy} onChange={setGroupBy} options={[{ label: 'Ngày', value: 'day' }, { label: 'Tuần', value: 'week' }, { label: 'Tháng', value: 'month' }, { label: 'Quý', value: 'quarter' }, { label: 'Năm', value: 'year' }]} /><Select value={breakdownBy} onChange={setBreakdownBy} options={[{ label: 'Dịch vụ', value: 'service' }, { label: 'Combo', value: 'combo' }, { label: 'Nhân viên', value: 'staff' }, { label: 'Loại dịch vụ', value: 'category' }]} /><Button className="report-no-print" icon={<DownloadOutlined />} disabled={isLoading} onClick={exportXlsx}>Xuất Excel</Button><Button className="report-no-print" icon={<PrinterOutlined />} onClick={() => window.print()}>In báo cáo</Button></div></Card>
    {firstError && <Alert type="error" showIcon message={reportText.REPORT_FETCH_ERROR} description={String(firstError)} style={{ marginBottom: 16 }} />}
    {isLoading ? <Spin tip={reportText.REPORT_LOADING} /> : <>
      <OverviewCards appointmentCount={appointmentCount} customerCount={customerList.data?.length ?? 0} revenue={orderSummary.data?.paidRevenue ?? 0} newCustomerCount={newCustomerCount} averageRating={averageRating} unknownHistoricalCount={newCustomers.data?.unknownHistoricalCount ?? 0} />
      <Card size="small" style={{ marginTop: 12 }} title="Doanh thu bán gói dịch vụ trong kỳ"><Statistic value={packageSales.data?.revenue ?? 0} formatter={v => formatMoney(Number(v))} suffix={packageSales.data ? ` · ${packageSales.data.count} phiếu đã thanh toán` : ''}/></Card>
      <Row gutter={[16, 16]} style={{ marginTop: 12 }}><Col xs={24} xl={14}><RevenueChart data={revenueItems} groupBy={groupBy} /></Col><Col xs={24} xl={10}><AppointmentStatusChart statuses={statuses} appointmentCount={appointmentCount} /></Col><Col xs={24} xl={14}><TopServicesChart data={topServices} /></Col><Col xs={24} xl={10}><AppointmentStatusSummary statuses={statuses} /></Col></Row>
      {reviewList.isError && <Alert type="warning" message="Không tải được dữ liệu đánh giá." />}
    </>}
  </section>
}

function OverviewCards({ appointmentCount, customerCount, revenue, newCustomerCount, averageRating, unknownHistoricalCount }: { appointmentCount: number; customerCount: number; revenue: number; newCustomerCount: number; averageRating: number | null; unknownHistoricalCount: number }) {
  return <Row gutter={[12, 12]}><Col xs={24} sm={12} lg={6}><Card><Statistic title="Số lịch hẹn" value={appointmentCount} /></Card></Col><Col xs={24} sm={12} lg={6}><Card><Statistic title="Số khách hàng" value={customerCount} /></Card></Col><Col xs={24} sm={12} lg={6}><Card><Statistic title="Tổng doanh thu" value={revenue} formatter={(value) => formatMoney(Number(value))} /></Card></Col><Col xs={24} sm={12} lg={6}><Card title={unknownHistoricalCount ? `Khách mới (không rõ lịch sử: ${unknownHistoricalCount})` : 'Khách mới'}><Statistic value={newCustomerCount} /></Card></Col><Col xs={24} sm={12} lg={6}><Card><Statistic title={reportText.REPORT_AVERAGE_RATING_LABEL} value={averageRating === null ? '—' : averageRating.toFixed(1)} suffix={averageRating === null ? '' : <><StarFilled style={{ color: '#B7791F' }} /> / 5</>} /></Card></Col></Row>
}

function RevenueChart({ data, groupBy }: { data: RevenueChartItem[]; groupBy: 'day' | 'week' | 'month' | 'quarter' | 'year' }) {
  return <Card title={`Doanh thu theo ${groupBy === 'day' ? 'ngày' : groupBy === 'week' ? 'tuần' : groupBy === 'month' ? 'tháng' : groupBy === 'quarter' ? 'quý' : 'năm'}`}>{data.some((item) => item.revenue > 0) ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={data} margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR} /><XAxis dataKey="date" /><YAxis tickFormatter={(value: number) => new Intl.NumberFormat('vi-VN', { notation: 'compact' }).format(value)} /><Tooltip formatter={(value) => formatMoney(Number(value))} /><Bar dataKey="revenue" name="Doanh thu" fill={reportText.REPORT_CHART_COLOR} radius={[3, 3, 0, 0]} /></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART} />}</Card>
}
function AppointmentStatusChart({ statuses, appointmentCount }: { statuses: StatusChartItem[]; appointmentCount: number }) {
  return <Card title="Lịch hẹn theo trạng thái">{appointmentCount ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><PieChart><Pie data={statuses} dataKey="count" nameKey="name" cx="50%" cy="50%" outerRadius={90} label={({ name, value }) => `${name}: ${value}`}>{statuses.map((item) => <Cell key={item.status} fill={item.color} />)}</Pie><Tooltip /></PieChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY} />}</Card>
}
function TopServicesChart({ data }: { data: TopServiceItem[] }) {
  return <Card title="Dịch vụ được đặt nhiều nhất">{data.length ? <ResponsiveContainer width="100%" height={reportText.REPORT_CHART_HEIGHT}><BarChart data={data} layout="vertical" margin={reportText.REPORT_CHART_MARGIN}><CartesianGrid stroke={reportText.REPORT_GRID_COLOR} /><XAxis type="number" allowDecimals={false} /><YAxis type="category" dataKey="name" width={140} tick={{ fontSize: 12 }} /><Tooltip /><Bar dataKey="quantity" name="Lượt đặt" fill="#2F7D4F" radius={[0, 3, 3, 0]} /></BarChart></ResponsiveContainer> : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY_CHART} />}</Card>
}
function AppointmentStatusSummary({ statuses }: { statuses: StatusChartItem[] }) {
  return <Card title="Số lịch theo trạng thái">{statuses.length ? statuses.map((item) => <div key={item.status} style={{ display: 'flex', justifyContent: 'space-between', padding: '8px 0', borderBottom: '1px solid #dedbd6' }}><span>{item.name}</span><Typography.Text strong>{item.count}</Typography.Text></div>) : <Empty image={Empty.PRESENTED_IMAGE_SIMPLE} description={reportText.REPORT_EMPTY} />}</Card>
}
