using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Chitietlichhen
{
    public int ChiTietLichHenId { get; set; }

    public int LichHenId { get; set; }

    public int DichVuId { get; set; }

    public int? ComboId { get; set; }

    public int? ThoiLuongThucTe { get; set; }

    public decimal GiaDuKien { get; set; }

    public virtual Combodichvu? Combo { get; set; }

    public virtual Dichvu DichVu { get; set; } = null!;

    public virtual Lichhen LichHen { get; set; } = null!;
}
