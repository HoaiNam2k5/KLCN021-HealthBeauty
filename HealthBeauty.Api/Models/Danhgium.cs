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

    public virtual Hoadon HoaDon { get; set; } = null!;
}
