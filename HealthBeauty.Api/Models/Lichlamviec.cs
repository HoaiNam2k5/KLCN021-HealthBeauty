using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Lichlamviec
{
    public int LichLamViecId { get; set; }

    public int NhanVienId { get; set; }

    public DateOnly NgayLam { get; set; }

    public TimeOnly GioBatDau { get; set; }

    public TimeOnly GioKetThuc { get; set; }

    public string? TrangThai { get; set; }

    public virtual Nhanvien NhanVien { get; set; } = null!;
}
