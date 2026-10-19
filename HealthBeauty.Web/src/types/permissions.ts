export interface AdminRole {
  roleId: number
  tenVaiTro: string
}

export interface AdminPermission {
  permissionId: number
  active: boolean
  tenQuyen: string
  maQuyen: string
  nhomQuyen: string
  moTa: string | null
}

export interface RolePermission extends AdminPermission {
  granted: boolean
}

export interface RolePermissionRequest {
  permissionId: number
  granted: boolean
}
