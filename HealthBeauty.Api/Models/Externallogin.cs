using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Externallogin
{
    public long ExternalLoginId { get; set; }

    public int TaiKhoanId { get; set; }

    public string Provider { get; set; } = null!;

    public string ProviderUserId { get; set; } = null!;

    public string? Email { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Taikhoan TaiKhoan { get; set; } = null!;
}
