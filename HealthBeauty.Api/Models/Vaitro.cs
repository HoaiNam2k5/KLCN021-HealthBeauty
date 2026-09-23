using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Vaitro
{
    public int VaiTroId { get; set; }

    public string TenVaiTro { get; set; } = null!;

    public string? MoTa { get; set; }

    public virtual ICollection<Taikhoan> Taikhoans { get; set; } = new List<Taikhoan>();

    public virtual ICollection<VaitroQuyen> VaitroQuyens { get; set; } = new List<VaitroQuyen>();
}
