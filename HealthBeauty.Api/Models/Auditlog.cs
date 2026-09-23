using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Auditlog
{
    public long AuditLogId { get; set; }

    public int? TaiKhoanId { get; set; }

    public string ActionName { get; set; } = null!;

    public string? EntityName { get; set; }

    public string? EntityId { get; set; }

    public string? OldValues { get; set; }

    public string? NewValues { get; set; }

    public string? IpAddress { get; set; }

    public string? UserAgent { get; set; }

    public DateTime CreatedAt { get; set; }

    public virtual Taikhoan? TaiKhoan { get; set; }
}
