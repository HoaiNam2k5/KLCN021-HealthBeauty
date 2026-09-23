using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Chitiethoadon
{
    public int HoaDonChiTietId { get; set; }

    public int HoaDonId { get; set; }

    public int? DichVuId { get; set; }

    public int? ComboId { get; set; }

    public int SoLuong { get; set; }

    public decimal DonGia { get; set; }

    public virtual Combodichvu? Combo { get; set; }

    public virtual Dichvu? DichVu { get; set; }

    public virtual Hoadon HoaDon { get; set; } = null!;
}
