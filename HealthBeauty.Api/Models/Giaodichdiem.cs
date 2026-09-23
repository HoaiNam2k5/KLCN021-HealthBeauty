using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Giaodichdiem
{
    public int GiaoDichId { get; set; }

    public int KhachHangId { get; set; }

    public int? HoaDonId { get; set; }

    public int SoDiem { get; set; }

    public string LoaiGiaoDich { get; set; } = null!;

    public DateTime NgayGiaoDich { get; set; }

    public string? GhiChu { get; set; }

    public virtual Hoadon? HoaDon { get; set; }

    public virtual Khachhang KhachHang { get; set; } = null!;
}
