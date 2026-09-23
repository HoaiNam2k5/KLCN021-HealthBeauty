using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Voucher
{
    public int VoucherId { get; set; }

    public string MaCode { get; set; } = null!;

    public int KhuyenMaiId { get; set; }

    public int? KhachHangId { get; set; }

    public decimal GiaTriGiam { get; set; }

    public DateTime HanSuDung { get; set; }

    public bool TrangThai { get; set; }

    public virtual Khachhang? KhachHang { get; set; }

    public virtual Khuyenmai KhuyenMai { get; set; } = null!;
}
