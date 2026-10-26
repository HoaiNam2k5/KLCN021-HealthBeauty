import { Card, Col, Row, Typography } from 'antd'
import { CalendarOutlined, DollarOutlined, ScheduleOutlined, UserAddOutlined } from '@ant-design/icons'
import { useNavigate } from 'react-router-dom'
import { usePermissions } from '../../hooks/usePermissions'
import { quickActions } from './quickActions'

const icons = { appointment: <CalendarOutlined />, invoice: <DollarOutlined />, customer: <UserAddOutlined />, schedule: <ScheduleOutlined /> }

export default function QuickActionsBar() {
  const navigate = useNavigate()
  const access = usePermissions()
  const actions = quickActions(access)
  if (actions.length === 0) return null
  return <Card size="small" className="report-no-print" style={{ marginBottom: 16, background: '#faf8f6', border: '1px solid #eee5df', borderRadius: 8 }}>
    <Typography.Text strong style={{ fontSize: 12, color: '#8c4559', display: 'block', marginBottom: 8 }}>Thao tác nhanh cho lễ tân &amp; thu ngân</Typography.Text>
    <Row gutter={[12, 12]}>
      {actions.map(action => <Col xs={24} sm={12} lg={6} key={action.key}>
        <Card size="small" hoverable role="button" tabIndex={0} aria-label={action.title}
          onClick={() => navigate(action.destination)}
          onKeyDown={event => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); navigate(action.destination) } }}
          style={{ borderRadius: 8, cursor: 'pointer', border: '1px solid #e8e8e8' }}>
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <div style={{ width: 40, height: 40, borderRadius: 8, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: 22, color: action.color, background: action.background }}>
              {icons[action.key as keyof typeof icons]}
            </div>
            <div style={{ minWidth: 0 }}>
              <Typography.Text strong style={{ display: 'block', fontSize: 13 }}>{action.title}</Typography.Text>
              <Typography.Text type="secondary" style={{ display: 'block', fontSize: 11 }}>{action.description}</Typography.Text>
            </div>
          </div>
        </Card>
      </Col>)}
    </Row>
  </Card>
}
