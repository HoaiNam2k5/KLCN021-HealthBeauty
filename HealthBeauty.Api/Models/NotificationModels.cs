using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Models;

public sealed class ThietBiKhachHang
{
    public int Id { get; set; }
    public int TaiKhoanId { get; set; }
    public int? KhachHangId { get; set; }
    public string FcmToken { get; set; } = "";
    public string? LoaiThietBi { get; set; }
    public DateTime NgayCapNhat { get; set; }
    public bool TrangThai { get; set; } = true;
}

public sealed class ThongBao
{
    public int ThongBaoId { get; set; }
    public int? TaiKhoanId { get; set; }
    public int? KhachHangId { get; set; }
    public string TieuDe { get; set; } = "";
    public string NoiDung { get; set; } = "";
    public string LoaiThongBao { get; set; } = "";
    public string? DuLieuKemTheo { get; set; }
    public DateTime NgayTao { get; set; }
    public string PushStatus { get; set; } = "Pending";
    public int PushAttempts { get; set; }
    public DateTime NextPushAt { get; set; }
    public string? PushLeaseId { get; set; }
    public DateTime? PushLeaseUntil { get; set; }
}

public sealed class ThongBaoDaDoc
{
    public int ThongBaoId { get; set; }
    public int TaiKhoanId { get; set; }
    public DateTime NgayDoc { get; set; }
}

public partial class Klcn021HealthBeautyContext
{
    public DbSet<ThietBiKhachHang> ThietBiKhachHangs { get; set; }
    public DbSet<ThongBao> ThongBaos { get; set; }
    public DbSet<ThongBaoDaDoc> ThongBaoDaDocs { get; set; }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Lichhen>().Property(x => x.RowVersion).IsRowVersion();
        modelBuilder.Entity<Hoadon>().Property(x => x.RowVersion).IsRowVersion();
        modelBuilder.Entity<ThietBiKhachHang>(e =>
        {
            e.ToTable("ThietBiKhachHang"); e.HasKey(x => x.Id);
            e.Property(x => x.FcmToken).HasMaxLength(500).UseCollation("Latin1_General_100_BIN2");
            e.Property(x => x.LoaiThietBi).HasMaxLength(50);
            e.Property(x => x.NgayCapNhat).HasPrecision(7);
            e.HasIndex(x => x.FcmToken, "IX_ThietBi_Token").IsUnique();
            e.HasIndex(x => x.TaiKhoanId, "IX_ThietBi_TaiKhoan");
            e.HasOne<Taikhoan>().WithMany().HasForeignKey(x => x.TaiKhoanId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<Khachhang>().WithMany().HasForeignKey(x => x.KhachHangId).OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<ThongBao>(e =>
        {
            e.ToTable("ThongBao"); e.HasKey(x => x.ThongBaoId);
            e.Property(x => x.TieuDe).HasMaxLength(250); e.Property(x => x.NoiDung).HasMaxLength(1000);
            e.Property(x => x.LoaiThongBao).HasMaxLength(50);
            e.Property(x => x.NgayTao).HasPrecision(7); e.Property(x => x.NextPushAt).HasPrecision(7);
            e.Property(x => x.PushLeaseUntil).HasPrecision(7);
            e.Property(x => x.PushStatus).HasMaxLength(20).IsUnicode(false);
            e.Property(x => x.PushLeaseId).HasMaxLength(32).IsUnicode(false);
            e.HasIndex(x => new { x.TaiKhoanId, x.NgayTao }, "IX_ThongBao_TaiKhoan");
            e.HasIndex(x => new { x.PushStatus, x.NextPushAt }, "IX_ThongBao_Push");
            e.HasOne<Taikhoan>().WithMany().HasForeignKey(x => x.TaiKhoanId).OnDelete(DeleteBehavior.NoAction);
            e.HasOne<Khachhang>().WithMany().HasForeignKey(x => x.KhachHangId).OnDelete(DeleteBehavior.NoAction);
        });
        modelBuilder.Entity<ThongBaoDaDoc>(e =>
        {
            e.ToTable("ThongBaoDaDoc"); e.HasKey(x => new { x.ThongBaoId, x.TaiKhoanId });
            e.Property(x => x.NgayDoc).HasPrecision(7);
            e.HasOne<ThongBao>().WithMany().HasForeignKey(x => x.ThongBaoId).OnDelete(DeleteBehavior.Cascade);
            e.HasOne<Taikhoan>().WithMany().HasForeignKey(x => x.TaiKhoanId).OnDelete(DeleteBehavior.NoAction);
            e.HasIndex(x => new { x.TaiKhoanId, x.ThongBaoId }, "IX_ThongBaoDaDoc_TaiKhoan");
        });
    }
}
