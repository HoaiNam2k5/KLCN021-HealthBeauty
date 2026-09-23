using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Models;

public partial class Klcn021HealthBeautyContext : DbContext
{
    public Klcn021HealthBeautyContext()
    {
    }

    public Klcn021HealthBeautyContext(DbContextOptions<Klcn021HealthBeautyContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Auditlog> Auditlogs { get; set; }

    public virtual DbSet<Chitietcombo> Chitietcombos { get; set; }

    public virtual DbSet<Chitiethoadon> Chitiethoadons { get; set; }

    public virtual DbSet<Chitietlichhen> Chitietlichhens { get; set; }

    public virtual DbSet<Combodichvu> Combodichvus { get; set; }

    public virtual DbSet<Dangnhaplog> Dangnhaplogs { get; set; }

    public virtual DbSet<Danhgium> Danhgia { get; set; }

    public virtual DbSet<Dichvu> Dichvus { get; set; }

    public virtual DbSet<Externallogin> Externallogins { get; set; }

    public virtual DbSet<Giaodichdiem> Giaodichdiems { get; set; }

    public virtual DbSet<Hoadon> Hoadons { get; set; }

    public virtual DbSet<Khachhang> Khachhangs { get; set; }

    public virtual DbSet<Khuyenmai> Khuyenmais { get; set; }

    public virtual DbSet<Lichhen> Lichhens { get; set; }

    public virtual DbSet<Lichlamviec> Lichlamviecs { get; set; }

    public virtual DbSet<Loaidichvu> Loaidichvus { get; set; }

    public virtual DbSet<Nhanvien> Nhanviens { get; set; }

    public virtual DbSet<Quyen> Quyens { get; set; }

    public virtual DbSet<Refreshtoken> Refreshtokens { get; set; }

    public virtual DbSet<Taikhoan> Taikhoans { get; set; }

    public virtual DbSet<Thanhtoan> Thanhtoans { get; set; }

    public virtual DbSet<Vaitro> Vaitros { get; set; }

    public virtual DbSet<VaitroQuyen> VaitroQuyens { get; set; }

    public virtual DbSet<Voucher> Vouchers { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Auditlog>(entity =>
        {
            entity.ToTable("AUDITLOG");

            entity.HasIndex(e => new { e.TaiKhoanId, e.CreatedAt }, "IX_AUDITLOG_AccountTime");

            entity.Property(e => e.AuditLogId).HasColumnName("AuditLogID");
            entity.Property(e => e.ActionName)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.CreatedAt)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.EntityId)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("EntityID");
            entity.Property(e => e.EntityName)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.IpAddress)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");
            entity.Property(e => e.UserAgent).HasMaxLength(500);

            entity.HasOne(d => d.TaiKhoan).WithMany(p => p.Auditlogs)
                .HasForeignKey(d => d.TaiKhoanId)
                .HasConstraintName("FK_AUDITLOG_TAIKHOAN");
        });

        modelBuilder.Entity<Chitietcombo>(entity =>
        {
            entity.HasKey(e => e.ComboChiTietId);

            entity.ToTable("CHITIETCOMBO");

            entity.HasIndex(e => new { e.ComboId, e.DichVuId }, "UQ_CHITIETCOMBO").IsUnique();

            entity.Property(e => e.ComboChiTietId).HasColumnName("ComboChiTietID");
            entity.Property(e => e.ComboId).HasColumnName("ComboID");
            entity.Property(e => e.DichVuId).HasColumnName("DichVuID");
            entity.Property(e => e.SoLuong).HasDefaultValue(1);

            entity.HasOne(d => d.Combo).WithMany(p => p.Chitietcombos)
                .HasForeignKey(d => d.ComboId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CTCOMBO_COMBO");

            entity.HasOne(d => d.DichVu).WithMany(p => p.Chitietcombos)
                .HasForeignKey(d => d.DichVuId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CTCOMBO_DICHVU");
        });

        modelBuilder.Entity<Chitiethoadon>(entity =>
        {
            entity.HasKey(e => e.HoaDonChiTietId);

            entity.ToTable("CHITIETHOADON");

            entity.Property(e => e.HoaDonChiTietId).HasColumnName("HoaDonChiTietID");
            entity.Property(e => e.ComboId).HasColumnName("ComboID");
            entity.Property(e => e.DichVuId).HasColumnName("DichVuID");
            entity.Property(e => e.DonGia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.HoaDonId).HasColumnName("HoaDonID");
            entity.Property(e => e.SoLuong).HasDefaultValue(1);

            entity.HasOne(d => d.Combo).WithMany(p => p.Chitiethoadons)
                .HasForeignKey(d => d.ComboId)
                .HasConstraintName("FK_CTHD_COMBO");

            entity.HasOne(d => d.DichVu).WithMany(p => p.Chitiethoadons)
                .HasForeignKey(d => d.DichVuId)
                .HasConstraintName("FK_CTHD_DICHVU");

            entity.HasOne(d => d.HoaDon).WithMany(p => p.Chitiethoadons)
                .HasForeignKey(d => d.HoaDonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CTHD_HOADON");
        });

        modelBuilder.Entity<Chitietlichhen>(entity =>
        {
            entity.ToTable("CHITIETLICHHEN");

            entity.Property(e => e.ChiTietLichHenId).HasColumnName("ChiTietLichHenID");
            entity.Property(e => e.ComboId).HasColumnName("ComboID");
            entity.Property(e => e.DichVuId).HasColumnName("DichVuID");
            entity.Property(e => e.GiaDuKien).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.LichHenId).HasColumnName("LichHenID");

            entity.HasOne(d => d.Combo).WithMany(p => p.Chitietlichhens)
                .HasForeignKey(d => d.ComboId)
                .HasConstraintName("FK_CTLICH_COMBO");

            entity.HasOne(d => d.DichVu).WithMany(p => p.Chitietlichhens)
                .HasForeignKey(d => d.DichVuId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CTLICH_DICHVU");

            entity.HasOne(d => d.LichHen).WithMany(p => p.Chitietlichhens)
                .HasForeignKey(d => d.LichHenId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_CTLICH_LICHHEN");
        });

        modelBuilder.Entity<Combodichvu>(entity =>
        {
            entity.HasKey(e => e.ComboId);

            entity.ToTable("COMBODICHVU");

            entity.Property(e => e.ComboId).HasColumnName("ComboID");
            entity.Property(e => e.GiaCombo).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TenCombo).HasMaxLength(150);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);
        });

        modelBuilder.Entity<Dangnhaplog>(entity =>
        {
            entity.ToTable("DANGNHAPLOG");

            entity.HasIndex(e => new { e.Email, e.CreatedAt }, "IX_DANGNHAPLOG_EmailTime");

            entity.Property(e => e.DangNhapLogId).HasColumnName("DangNhapLogID");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Email)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.IpAddress)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.LyDoThatBai)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");
            entity.Property(e => e.UserAgent).HasMaxLength(500);

            entity.HasOne(d => d.TaiKhoan).WithMany(p => p.Dangnhaplogs)
                .HasForeignKey(d => d.TaiKhoanId)
                .HasConstraintName("FK_DANGNHAPLOG_TAIKHOAN");
        });

        modelBuilder.Entity<Danhgium>(entity =>
        {
            entity.HasKey(e => e.DanhGiaId);

            entity.ToTable("DANHGIA");

            entity.Property(e => e.DanhGiaId).HasColumnName("DanhGiaID");
            entity.Property(e => e.BinhLuan).HasMaxLength(1000);
            entity.Property(e => e.HoaDonId).HasColumnName("HoaDonID");
            entity.Property(e => e.NgayDanhGia)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.TrangThai)
                .HasMaxLength(30)
                .HasDefaultValue("ChoDuyet");

            entity.HasOne(d => d.HoaDon).WithMany(p => p.Danhgia)
                .HasForeignKey(d => d.HoaDonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DANHGIA_HOADON");
        });

        modelBuilder.Entity<Dichvu>(entity =>
        {
            entity.ToTable("DICHVU");

            entity.HasIndex(e => new { e.LoaiDichVuId, e.TrangThai }, "IX_DICHVU_Loai");

            entity.Property(e => e.DichVuId).HasColumnName("DichVuID");
            entity.Property(e => e.Gia).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.LoaiDichVuId).HasColumnName("LoaiDichVuID");
            entity.Property(e => e.MoTa).HasMaxLength(1000);
            entity.Property(e => e.TenDichVu).HasMaxLength(150);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);

            entity.HasOne(d => d.LoaiDichVu).WithMany(p => p.Dichvus)
                .HasForeignKey(d => d.LoaiDichVuId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_DICHVU_LOAI");
        });

        modelBuilder.Entity<Externallogin>(entity =>
        {
            entity.ToTable("EXTERNALLOGIN");

            entity.HasIndex(e => new { e.Provider, e.ProviderUserId }, "UQ_EXTERNALLOGIN_ProviderUser").IsUnique();

            entity.Property(e => e.ExternalLoginId).HasColumnName("ExternalLoginID");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Email)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.Provider)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.ProviderUserId)
                .HasMaxLength(255)
                .IsUnicode(false)
                .HasColumnName("ProviderUserID");
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");

            entity.HasOne(d => d.TaiKhoan).WithMany(p => p.Externallogins)
                .HasForeignKey(d => d.TaiKhoanId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_EXTERNALLOGIN_TAIKHOAN");
        });

        modelBuilder.Entity<Giaodichdiem>(entity =>
        {
            entity.HasKey(e => e.GiaoDichId);

            entity.ToTable("GIAODICHDIEM");

            entity.HasIndex(e => new { e.KhachHangId, e.NgayGiaoDich }, "IX_GD_DIEM_Khach");

            entity.Property(e => e.GiaoDichId).HasColumnName("GiaoDichID");
            entity.Property(e => e.GhiChu).HasMaxLength(500);
            entity.Property(e => e.HoaDonId).HasColumnName("HoaDonID");
            entity.Property(e => e.KhachHangId).HasColumnName("KhachHangID");
            entity.Property(e => e.LoaiGiaoDich).HasMaxLength(20);
            entity.Property(e => e.NgayGiaoDich)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.HoaDon).WithMany(p => p.Giaodichdiems)
                .HasForeignKey(d => d.HoaDonId)
                .HasConstraintName("FK_GD_DIEM_HOADON");

            entity.HasOne(d => d.KhachHang).WithMany(p => p.Giaodichdiems)
                .HasForeignKey(d => d.KhachHangId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_GD_DIEM_KHACH");
        });

        modelBuilder.Entity<Hoadon>(entity =>
        {
            entity.ToTable("HOADON");

            entity.HasIndex(e => new { e.NgayLap, e.TrangThai }, "IX_HOADON_NgayLap");

            entity.Property(e => e.HoaDonId).HasColumnName("HoaDonID");
            entity.Property(e => e.KhachHangId).HasColumnName("KhachHangID");
            entity.Property(e => e.LichHenId).HasColumnName("LichHenID");
            entity.Property(e => e.NgayLap)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.TongTienSauGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TongTienTruocGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TrangThai)
                .HasMaxLength(30)
                .HasDefaultValue("ChuaThanhToan");

            entity.HasOne(d => d.KhachHang).WithMany(p => p.Hoadons)
                .HasForeignKey(d => d.KhachHangId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_HOADON_KHACH");

            entity.HasOne(d => d.LichHen).WithMany(p => p.Hoadons)
                .HasForeignKey(d => d.LichHenId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_HOADON_LICHHEN");
        });

        modelBuilder.Entity<Khachhang>(entity =>
        {
            entity.ToTable("KHACHHANG");

            entity.HasIndex(e => e.TaiKhoanId, "UQ_KHACHHANG_TaiKhoan").IsUnique();

            entity.Property(e => e.KhachHangId).HasColumnName("KhachHangID");
            entity.Property(e => e.GioiTinh).HasMaxLength(20);
            entity.Property(e => e.HoTen).HasMaxLength(100);
            entity.Property(e => e.SoDienThoai)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");

            entity.HasOne(d => d.TaiKhoan).WithOne(p => p.Khachhang)
                .HasForeignKey<Khachhang>(d => d.TaiKhoanId)
                .HasConstraintName("FK_KHACHHANG_TAIKHOAN");
        });

        modelBuilder.Entity<Khuyenmai>(entity =>
        {
            entity.ToTable("KHUYENMAI");

            entity.Property(e => e.KhuyenMaiId).HasColumnName("KhuyenMaiID");
            entity.Property(e => e.DieuKienApDung).HasMaxLength(1000);
            entity.Property(e => e.LoaiGiam).HasMaxLength(30);
            entity.Property(e => e.MucGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.NgayBatDauHieuLuc).HasPrecision(0);
            entity.Property(e => e.NgayKetThucHieuLuc).HasPrecision(0);
            entity.Property(e => e.TenKhuyenMai).HasMaxLength(150);
        });

        modelBuilder.Entity<Lichhen>(entity =>
        {
            entity.ToTable("LICHHEN");

            entity.HasIndex(e => new { e.NgayGioHen, e.TrangThai }, "IX_LICHHEN_NgayGio");

            entity.Property(e => e.LichHenId).HasColumnName("LichHenID");
            entity.Property(e => e.GhiChu).HasMaxLength(1000);
            entity.Property(e => e.GioKetThucDuKien).HasPrecision(0);
            entity.Property(e => e.KhachHangId).HasColumnName("KhachHangID");
            entity.Property(e => e.NgayGioHen).HasPrecision(0);
            entity.Property(e => e.NhanVienId).HasColumnName("NhanVienID");
            entity.Property(e => e.TrangThai)
                .HasMaxLength(30)
                .HasDefaultValue("ChoXacNhan");

            entity.HasOne(d => d.KhachHang).WithMany(p => p.Lichhens)
                .HasForeignKey(d => d.KhachHangId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_LICHHEN_KHACH");

            entity.HasOne(d => d.NhanVien).WithMany(p => p.Lichhens)
                .HasForeignKey(d => d.NhanVienId)
                .HasConstraintName("FK_LICHHEN_NHANVIEN");
        });

        modelBuilder.Entity<Lichlamviec>(entity =>
        {
            entity.ToTable("LICHLAMVIEC");

            entity.Property(e => e.LichLamViecId).HasColumnName("LichLamViecID");
            entity.Property(e => e.GioBatDau).HasPrecision(0);
            entity.Property(e => e.GioKetThuc).HasPrecision(0);
            entity.Property(e => e.NhanVienId).HasColumnName("NhanVienID");
            entity.Property(e => e.TrangThai).HasMaxLength(30);

            entity.HasOne(d => d.NhanVien).WithMany(p => p.Lichlamviecs)
                .HasForeignKey(d => d.NhanVienId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_LICHLAMVIEC_NHANVIEN");
        });

        modelBuilder.Entity<Loaidichvu>(entity =>
        {
            entity.ToTable("LOAIDICHVU");

            entity.Property(e => e.LoaiDichVuId).HasColumnName("LoaiDichVuID");
            entity.Property(e => e.MoTa).HasMaxLength(255);
            entity.Property(e => e.TenLoai).HasMaxLength(100);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);
        });

        modelBuilder.Entity<Nhanvien>(entity =>
        {
            entity.ToTable("NHANVIEN");

            entity.HasIndex(e => e.TaiKhoanId, "UQ_NHANVIEN_TaiKhoan").IsUnique();

            entity.Property(e => e.NhanVienId).HasColumnName("NhanVienID");
            entity.Property(e => e.ChucVu).HasMaxLength(50);
            entity.Property(e => e.ChuyenMon).HasMaxLength(255);
            entity.Property(e => e.HoTen).HasMaxLength(100);
            entity.Property(e => e.SoDienThoai)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");

            entity.HasOne(d => d.TaiKhoan).WithOne(p => p.Nhanvien)
                .HasForeignKey<Nhanvien>(d => d.TaiKhoanId)
                .HasConstraintName("FK_NHANVIEN_TAIKHOAN");
        });

        modelBuilder.Entity<Quyen>(entity =>
        {
            entity.ToTable("QUYEN");

            entity.HasIndex(e => e.MaQuyen, "UQ_QUYEN_Ma").IsUnique();

            entity.Property(e => e.QuyenId).HasColumnName("QuyenID");
            entity.Property(e => e.MaQuyen)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.MoTa).HasMaxLength(500);
            entity.Property(e => e.NhomQuyen)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.TenQuyen).HasMaxLength(150);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);
        });

        modelBuilder.Entity<Refreshtoken>(entity =>
        {
            entity.ToTable("REFRESHTOKEN");

            entity.HasIndex(e => new { e.TaiKhoanId, e.RevokedAt, e.ExpiresAt }, "IX_REFRESHTOKEN_Account");

            entity.HasIndex(e => e.TokenHash, "UQ_REFRESHTOKEN_Hash").IsUnique();

            entity.Property(e => e.RefreshTokenId).HasColumnName("RefreshTokenID");
            entity.Property(e => e.CreatedAt)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.CreatedByIp)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.ExpiresAt).HasPrecision(0);
            entity.Property(e => e.ReplacedByTokenHash)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.RevokedAt).HasPrecision(0);
            entity.Property(e => e.RevokedByIp)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");
            entity.Property(e => e.TokenHash)
                .HasMaxLength(255)
                .IsUnicode(false);

            entity.HasOne(d => d.TaiKhoan).WithMany(p => p.Refreshtokens)
                .HasForeignKey(d => d.TaiKhoanId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_REFRESHTOKEN_TAIKHOAN");
        });

        modelBuilder.Entity<Taikhoan>(entity =>
        {
            entity.ToTable("TAIKHOAN");

            entity.HasIndex(e => e.Email, "UQ_TAIKHOAN_Email").IsUnique();

            entity.Property(e => e.TaiKhoanId).HasColumnName("TaiKhoanID");
            entity.Property(e => e.Email)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.KhoaDen).HasPrecision(0);
            entity.Property(e => e.LanDangNhapCuoi).HasPrecision(0);
            entity.Property(e => e.MatKhauHash)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.NgayTao)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.TenTaiKhoan).HasMaxLength(100);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);
            entity.Property(e => e.VaiTroId).HasColumnName("VaiTroID");

            entity.HasOne(d => d.VaiTro).WithMany(p => p.Taikhoans)
                .HasForeignKey(d => d.VaiTroId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_TAIKHOAN_VAITRO");
        });

        modelBuilder.Entity<Thanhtoan>(entity =>
        {
            entity.ToTable("THANHTOAN");

            entity.Property(e => e.ThanhToanId).HasColumnName("ThanhToanID");
            entity.Property(e => e.HoaDonId).HasColumnName("HoaDonID");
            entity.Property(e => e.NgayGioThanhToan).HasPrecision(0);
            entity.Property(e => e.PhuongThuc).HasMaxLength(30);
            entity.Property(e => e.SoTien).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.TrangThai)
                .HasMaxLength(30)
                .HasDefaultValue("ChoXuLy");

            entity.HasOne(d => d.HoaDon).WithMany(p => p.Thanhtoans)
                .HasForeignKey(d => d.HoaDonId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_THANHTOAN_HOADON");
        });

        modelBuilder.Entity<Vaitro>(entity =>
        {
            entity.ToTable("VAITRO");

            entity.Property(e => e.VaiTroId).HasColumnName("VaiTroID");
            entity.Property(e => e.MoTa).HasMaxLength(255);
            entity.Property(e => e.TenVaiTro).HasMaxLength(50);
        });

        modelBuilder.Entity<VaitroQuyen>(entity =>
        {
            entity.HasKey(e => new { e.VaiTroId, e.QuyenId });

            entity.ToTable("VAITRO_QUYEN");

            entity.Property(e => e.VaiTroId).HasColumnName("VaiTroID");
            entity.Property(e => e.QuyenId).HasColumnName("QuyenID");
            entity.Property(e => e.DuocCap).HasDefaultValue(true);
            entity.Property(e => e.NgayGan)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.Quyen).WithMany(p => p.VaitroQuyens)
                .HasForeignKey(d => d.QuyenId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_VAITROQUYEN_QUYEN");

            entity.HasOne(d => d.VaiTro).WithMany(p => p.VaitroQuyens)
                .HasForeignKey(d => d.VaiTroId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_VAITROQUYEN_VAITRO");
        });

        modelBuilder.Entity<Voucher>(entity =>
        {
            entity.ToTable("VOUCHER");

            entity.HasIndex(e => e.MaCode, "UQ_VOUCHER_MaCode").IsUnique();

            entity.Property(e => e.VoucherId).HasColumnName("VoucherID");
            entity.Property(e => e.GiaTriGiam).HasColumnType("decimal(18, 2)");
            entity.Property(e => e.HanSuDung).HasPrecision(0);
            entity.Property(e => e.KhachHangId).HasColumnName("KhachHangID");
            entity.Property(e => e.KhuyenMaiId).HasColumnName("KhuyenMaiID");
            entity.Property(e => e.MaCode)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.TrangThai).HasDefaultValue(true);

            entity.HasOne(d => d.KhachHang).WithMany(p => p.Vouchers)
                .HasForeignKey(d => d.KhachHangId)
                .HasConstraintName("FK_VOUCHER_KHACH");

            entity.HasOne(d => d.KhuyenMai).WithMany(p => p.Vouchers)
                .HasForeignKey(d => d.KhuyenMaiId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_VOUCHER_KM");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
