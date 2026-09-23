using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Chitietcombo
{
    public int ComboChiTietId { get; set; }

    public int ComboId { get; set; }

    public int DichVuId { get; set; }

    public int SoLuong { get; set; }

    public virtual Combodichvu Combo { get; set; } = null!;

    public virtual Dichvu DichVu { get; set; } = null!;
}
