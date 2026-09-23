using System;
using System.Collections.Generic;

namespace HealthBeauty.Api.Models;

public partial class Hoadon
{
    public int HoaDonId { get; set; }

    public int LichHenId { get; set; }

    public int KhachHangId { get; set; }

    public DateTime NgayLap { get; set; }

    public decimal TongTienTruocGiam { get; set; }

    public decimal TongTienSauGiam { get; set; }

    public string TrangThai { get; set; } = null!;

    public virtual ICollection<Chitiethoadon> Chitiethoadons { get; set; } = new List<Chitiethoadon>();

    public virtual ICollection<Danhgium> Danhgia { get; set; } = new List<Danhgium>();

    public virtual ICollection<Giaodichdiem> Giaodichdiems { get; set; } = new List<Giaodichdiem>();

    public virtual Khachhang KhachHang { get; set; } = null!;

    public virtual Lichhen LichHen { get; set; } = null!;

    public virtual ICollection<Thanhtoan> Thanhtoans { get; set; } = new List<Thanhtoan>();
}
