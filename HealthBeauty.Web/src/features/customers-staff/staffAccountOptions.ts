import type { Staff } from '../../types/customersStaff'

export function staffAccountOptions(staff: Staff[], accountId?: number) {
  return staff.map((person) => ({
    value: person.nhanVienId,
    label: `${person.hoTen || 'Nhân viên'} (#${person.nhanVienId})${person.taiKhoanId ? ' — đã có tài khoản' : ''}`,
    disabled: person.taiKhoanId != null && person.taiKhoanId !== accountId,
  }))
}
