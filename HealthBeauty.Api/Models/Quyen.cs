using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Quyen
{
    public int QuyenId { get; set; }

    public string MaQuyen { get; set; } = null!;

    public string TenQuyen { get; set; } = null!;

    public string NhomQuyen { get; set; } = null!;

    public string? MoTa { get; set; }

    public bool TrangThai { get; set; }

    public virtual ICollection<VaitroQuyen> VaitroQuyens { get; set; } = new List<VaitroQuyen>();
}
