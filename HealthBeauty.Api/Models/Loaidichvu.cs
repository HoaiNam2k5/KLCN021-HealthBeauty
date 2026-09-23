using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Loaidichvu
{
    public int LoaiDichVuId { get; set; }

    public string TenLoai { get; set; } = null!;

    public string? MoTa { get; set; }

    public bool TrangThai { get; set; }

    public virtual ICollection<Dichvu> Dichvus { get; set; } = new List<Dichvu>();
}
