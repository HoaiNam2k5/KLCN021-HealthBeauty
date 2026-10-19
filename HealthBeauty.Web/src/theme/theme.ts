import type { ThemeConfig } from 'antd'

const theme: ThemeConfig = {
  token: {
    colorPrimary: '#8c4559',
    colorLink: '#8c4559',
    colorBgLayout: '#f7f6f3',
    colorBgContainer: '#ffffff',
    colorBorder: '#e6e2dd',
    colorText: '#111111',
    colorTextSecondary: '#414141',
    colorTextTertiary: '#585858',
    colorTextQuaternary: '#888888',
    colorSuccess: '#2F7D4F',
    colorWarning: '#B7791F',
    colorError: '#C0392B',
    colorInfo: '#0007cb',
    borderRadius: 10,
    fontFamily: "Inter, 'Segoe UI', system-ui, sans-serif",
    fontSize: 14,
    fontWeightStrong: 600,
    boxShadow: 'none',
    boxShadowSecondary: 'none',
  },
  components: {
    Button: { primaryColor: '#ffffff', fontWeight: 500, controlHeight: 38 },
    Table: { headerBg: '#faf9f6', headerColor: '#414141', rowHoverBg: '#f1eee9' },
    Modal: { titleFontSize: 18 },
    Menu: { darkItemColor: '#ded5d0', darkItemHoverColor: '#ffffff', darkItemSelectedColor: '#ffffff', darkItemBg: '#252321', darkSubMenuItemBg: '#252321', darkItemSelectedBg: '#8c4559', darkItemHoverBg: '#36312e', itemBorderRadius: 8 },
    Card: { headerFontSize: 16 },
  },
}

export default theme
