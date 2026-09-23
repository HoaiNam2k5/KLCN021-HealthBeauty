using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Taikhoan
{
    public int TaiKhoanId { get; set; }

    public int VaiTroId { get; set; }

    public string? TenTaiKhoan { get; set; }

    public string MatKhauHash { get; set; } = null!;

    public string Email { get; set; } = null!;

    public bool TrangThai { get; set; }

    public DateTime NgayTao { get; set; }

    public int SoLanDangNhapSai { get; set; }

    public DateTime? KhoaDen { get; set; }

    public DateTime? LanDangNhapCuoi { get; set; }

    public virtual ICollection<Auditlog> Auditlogs { get; set; } = new List<Auditlog>();

    public virtual ICollection<Dangnhaplog> Dangnhaplogs { get; set; } = new List<Dangnhaplog>();

    public virtual ICollection<Externallogin> Externallogins { get; set; } = new List<Externallogin>();

    public virtual Khachhang? Khachhang { get; set; }

    public virtual Nhanvien? Nhanvien { get; set; }

    public virtual ICollection<Refreshtoken> Refreshtokens { get; set; } = new List<Refreshtoken>();

    public virtual Vaitro VaiTro { get; set; } = null!;
}
