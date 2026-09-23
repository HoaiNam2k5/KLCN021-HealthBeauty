using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Khachhang
{
    public int KhachHangId { get; set; }

    public int? TaiKhoanId { get; set; }

    public string HoTen { get; set; } = null!;

    public string? SoDienThoai { get; set; }

    public string? GioiTinh { get; set; }

    public int DiemThuong { get; set; }

    public virtual ICollection<Giaodichdiem> Giaodichdiems { get; set; } = new List<Giaodichdiem>();

    public virtual ICollection<Hoadon> Hoadons { get; set; } = new List<Hoadon>();

    public virtual ICollection<Lichhen> Lichhens { get; set; } = new List<Lichhen>();

    public virtual Taikhoan? TaiKhoan { get; set; }

    public virtual ICollection<Voucher> Vouchers { get; set; } = new List<Voucher>();
}
