using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Khuyenmai
{
    public int KhuyenMaiId { get; set; }

    public string TenKhuyenMai { get; set; } = null!;

    public string LoaiGiam { get; set; } = null!;

    public decimal MucGiam { get; set; }

    public string? DieuKienApDung { get; set; }

    public DateTime? NgayBatDauHieuLuc { get; set; }

    public DateTime? NgayKetThucHieuLuc { get; set; }

    public virtual ICollection<Voucher> Vouchers { get; set; } = new List<Voucher>();
}
