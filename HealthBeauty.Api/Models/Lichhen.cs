using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Lichhen
{
    public int LichHenId { get; set; }

    public int KhachHangId { get; set; }

    public int? NhanVienId { get; set; }

    public DateTime NgayGioHen { get; set; }

    public TimeOnly? GioKetThucDuKien { get; set; }

    public string TrangThai { get; set; } = null!;

    public string? GhiChu { get; set; }

    public virtual ICollection<Chitietlichhen> Chitietlichhens { get; set; } = new List<Chitietlichhen>();

    public virtual ICollection<Hoadon> Hoadons { get; set; } = new List<Hoadon>();

    public virtual Khachhang KhachHang { get; set; } = null!;

    public virtual Nhanvien? NhanVien { get; set; }
}
