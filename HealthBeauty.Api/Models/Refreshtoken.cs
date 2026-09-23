using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Refreshtoken
{
    public long RefreshTokenId { get; set; }

    public int TaiKhoanId { get; set; }

    public string TokenHash { get; set; } = null!;

    public DateTime ExpiresAt { get; set; }

    public DateTime CreatedAt { get; set; }

    public DateTime? RevokedAt { get; set; }

    public string? ReplacedByTokenHash { get; set; }

    public string? CreatedByIp { get; set; }

    public string? RevokedByIp { get; set; }

    public virtual Taikhoan TaiKhoan { get; set; } = null!;
}
