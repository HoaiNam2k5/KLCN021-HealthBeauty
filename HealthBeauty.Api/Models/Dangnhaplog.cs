using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Dangnhaplog
{
    public long DangNhapLogId { get; set; }

    public int? TaiKhoanId { get; set; }

    public string? Email { get; set; }

    public bool ThanhCong { get; set; }

    public string? LyDoThatBai { get; set; }

    public string? IpAddress { get; set; }

    public string? UserAgent { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Taikhoan? TaiKhoan { get; set; }
}
