import type { ThemeConfig } from 'antd'

const theme: ThemeConfig = {
  token: {
    colorPrimary: '#111111',
    colorLink: '#0007cb',
    colorBgLayout: '#faf9f6',
    colorBgContainer: '#ffffff',
    colorBorder: '#dedbd6',
    colorText: '#111111',
    colorTextSecondary: '#414141',
    colorTextTertiary: '#585858',
    colorTextQuaternary: '#888888',
    colorSuccess: '#2F7D4F',
    colorWarning: '#B7791F',
    colorError: '#C0392B',
    colorInfo: '#0007cb',
    borderRadius: 4,
    fontFamily: "Inter, 'Segoe UI', system-ui, sans-serif",
    fontSize: 14,
    fontWeightStrong: 500,
    boxShadow: 'none',
    boxShadowSecondary: 'none',
  },
  components: {
    Button: { primaryColor: '#ffffff', fontWeight: 500 },
    Table: { headerBg: '#faf9f6', headerColor: '#414141', rowHoverBg: '#f1eee9' },
    Modal: { titleFontSize: 18 },
  },
}

export default theme
