using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Dichvu
{
    public int DichVuId { get; set; }

    public int LoaiDichVuId { get; set; }

    public string TenDichVu { get; set; } = null!;

    public decimal Gia { get; set; }

    public int ThoiLuongPhut { get; set; }

    public string? MoTa { get; set; }

    public bool TrangThai { get; set; }

    public virtual ICollection<Chitietcombo> Chitietcombos { get; set; } = new List<Chitietcombo>();

    public virtual ICollection<Chitiethoadon> Chitiethoadons { get; set; } = new List<Chitiethoadon>();

    public virtual ICollection<Chitietlichhen> Chitietlichhens { get; set; } = new List<Chitietlichhen>();

    public virtual Loaidichvu LoaiDichVu { get; set; } = null!;
}
