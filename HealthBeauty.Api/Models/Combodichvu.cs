using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Combodichvu
{
    public int ComboId { get; set; }

    public string TenCombo { get; set; } = null!;

    public decimal GiaCombo { get; set; }

    public DateOnly? NgayBatDauHieuLuc { get; set; }

    public DateOnly? NgayKetThucHieuLuc { get; set; }

    public bool TrangThai { get; set; }

    public virtual ICollection<Chitietcombo> Chitietcombos { get; set; } = new List<Chitietcombo>();

    public virtual ICollection<Chitiethoadon> Chitiethoadons { get; set; } = new List<Chitiethoadon>();

    public virtual ICollection<Chitietlichhen> Chitietlichhens { get; set; } = new List<Chitietlichhen>();
}
