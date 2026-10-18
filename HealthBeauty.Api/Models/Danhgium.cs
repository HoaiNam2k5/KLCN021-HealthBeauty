using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Danhgium
{
    public int DanhGiaId { get; set; }

    public int HoaDonId { get; set; }

    public byte SoSao { get; set; }

    public string? BinhLuan { get; set; }

    public DateTime NgayDanhGia { get; set; }

    public string TrangThai { get; set; } = null!;

    public bool IsDeleted { get; set; }
    public string? Reply { get; set; }
    public int? ReplyAccountId { get; set; }
    public DateTime? RepliedAt { get; set; }
    [System.Text.Json.Serialization.JsonIgnore]
    public Guid Version { get; set; } = Guid.NewGuid();

    public virtual Hoadon HoaDon { get; set; } = null!;
}
