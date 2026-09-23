using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Thanhtoan
{
    public int ThanhToanId { get; set; }

    public int HoaDonId { get; set; }

    public string PhuongThuc { get; set; } = null!;

    public decimal SoTien { get; set; }

    public DateTime? NgayGioThanhToan { get; set; }

    public string TrangThai { get; set; } = null!;

    public virtual Hoadon HoaDon { get; set; } = null!;
}
