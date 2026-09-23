using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Nhanvien
{
    public int NhanVienId { get; set; }

    public int? TaiKhoanId { get; set; }

    public string HoTen { get; set; } = null!;

    public string? ChucVu { get; set; }

    public string? ChuyenMon { get; set; }

    public string? SoDienThoai { get; set; }

    public DateOnly? NgayVaoLam { get; set; }

    public virtual ICollection<Lichhen> Lichhens { get; set; } = new List<Lichhen>();

    public virtual ICollection<Lichlamviec> Lichlamviecs { get; set; } = new List<Lichlamviec>();

    public virtual Taikhoan? TaiKhoan { get; set; }
}
