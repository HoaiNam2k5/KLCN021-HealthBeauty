using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
namespace HealthBeauty.Api.Models;
public sealed class ServicePackage
{
    public int Id { get; set; }
    public string Name { get; set; } = "";
    public decimal Price { get; set; }
    public int ValidityDays { get; set; }
    public bool Active { get; set; } = true;
    public string? ImageUrl { get; set; }
    [JsonIgnore]
    public Guid Version { get; set; } = Guid.NewGuid();
    public List<ServicePackageItem> Items { get; set; } = [];
}
public sealed class ServicePackageItem
{
    public int Id { get; set; }
    public int ServicePackageId { get; set; }
    public int ServiceId { get; set; }
    public int Sessions { get; set; }
}
public sealed class CustomerPackage
{
    public int Id { get; set; }
    public int ServicePackageId { get; set; }
    public int CustomerId { get; set; }
    public string Name { get; set; } = "";
    public decimal Price { get; set; }
    public int ValidityDays { get; set; }
    public string Status { get; set; } = "Pending";
    public DateTime CreatedAt { get; set; }
    public DateTime? PaidAt { get; set; }
    public DateTime? ExpiresAt { get; set; }
    public string? PaymentMethod { get; set; }
    public int? PaidByAccountId { get; set; }
    [JsonIgnore]
    public Guid Version { get; set; } = Guid.NewGuid();
    public List<CustomerPackageItem> Items { get; set; } = [];
}
public sealed class CustomerPackageItem
{
    public int Id { get; set; }
    public int CustomerPackageId { get; set; }
    public int ServiceId { get; set; }
    public string ServiceName { get; set; } = "";
    public int Granted { get; set; }
    public int Reserved { get; set; }
    public int Used { get; set; }
    [JsonIgnore]
    public Guid Version { get; set; } = Guid.NewGuid();
}
public sealed class PackageUsage
{
    public int Id { get; set; }
    public int CustomerPackageItemId { get; set; }
    public int AppointmentId { get; set; }
    public Lichhen Appointment { get; set; } = null!;
    public int Quantity { get; set; }
    public string Status { get; set; } = "Reserved";
    public DateTime CreatedAt { get; set; }
    public DateTime? SettledAt { get; set; }
}
public partial class Klcn021HealthBeautyContext
{
    public DbSet<ServicePackage> ServicePackages => Set<ServicePackage>();
    public DbSet<CustomerPackage> CustomerPackages => Set<CustomerPackage>();
    public DbSet<CustomerPackageItem> CustomerPackageItems => Set<CustomerPackageItem>();
    public DbSet<PackageUsage> PackageUsages => Set<PackageUsage>();
    private static void ConfigureServicePackages(ModelBuilder b)
    {
        b.Entity<ServicePackage>(e =>
        {
            e.ToTable("ServicePackage"); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(200); e.Property(x => x.ImageUrl).HasMaxLength(2048); e.Property(x => x.Price).HasPrecision(18, 2); e.Property(x => x.Version).IsConcurrencyToken(); e.HasMany(x => x.Items).WithOne().HasForeignKey(x => x.ServicePackageId).OnDelete(DeleteBehavior.Cascade);
        }
        );
        b.Entity<ServicePackageItem>(e =>
        {
            e.ToTable("ServicePackageItem"); e.HasKey(x => x.Id); e.HasIndex(x => new
            {
                x.ServicePackageId,
                x.ServiceId
            }
    ).IsUnique(); e.HasOne<Dichvu>().WithMany().HasForeignKey(x => x.ServiceId).OnDelete(DeleteBehavior.NoAction);
        }
        );
        b.Entity<CustomerPackage>(e =>
        {
            e.ToTable("CustomerPackage"); e.HasKey(x => x.Id); e.Property(x => x.Name).HasMaxLength(200); e.Property(x => x.Price).HasPrecision(18, 2); e.Property(x => x.Status).HasMaxLength(20); e.Property(x => x.PaymentMethod).HasMaxLength(30); e.Property(x => x.Version).IsConcurrencyToken(); e.HasMany(x => x.Items).WithOne().HasForeignKey(x => x.CustomerPackageId).OnDelete(DeleteBehavior.NoAction); e.HasOne<ServicePackage>().WithMany().HasForeignKey(x => x.ServicePackageId).OnDelete(DeleteBehavior.NoAction); e.HasOne<Khachhang>().WithMany().HasForeignKey(x => x.CustomerId).OnDelete(DeleteBehavior.NoAction); e.HasOne<Taikhoan>().WithMany().HasForeignKey(x => x.PaidByAccountId).OnDelete(DeleteBehavior.NoAction); e.HasIndex(x => new
            {
                x.CustomerId,
                x.CreatedAt
            }
    );
        }
        );
        b.Entity<CustomerPackageItem>(e =>
        {
            e.ToTable("CustomerPackageItem"); e.HasKey(x => x.Id); e.Property(x => x.ServiceName).HasMaxLength(200); e.Property(x => x.Version).IsConcurrencyToken(); e.HasIndex(x => new
            {
                x.CustomerPackageId,
                x.ServiceId
            }
    ).IsUnique(); e.HasOne<Dichvu>().WithMany().HasForeignKey(x => x.ServiceId).OnDelete(DeleteBehavior.NoAction);
        }
        );
        b.Entity<PackageUsage>(e =>
        {
            e.ToTable("PackageUsage"); e.HasKey(x => x.Id); e.Property(x => x.Status).HasMaxLength(20); e.HasIndex(x => new
            {
                x.AppointmentId,
                x.CustomerPackageItemId
            }
    ).IsUnique(); e.HasOne(x => x.Appointment).WithMany().HasForeignKey(x => x.AppointmentId).OnDelete(DeleteBehavior.NoAction); e.HasOne<CustomerPackageItem>().WithMany().HasForeignKey(x => x.CustomerPackageItemId).OnDelete(DeleteBehavior.NoAction);
        }
        );
        b.Entity<Lichhen>().HasOne<CustomerPackage>().WithMany().HasForeignKey(x => x.CustomerPackageId).OnDelete(DeleteBehavior.NoAction);
        b.Entity<Giaodichdiem>().HasOne<CustomerPackage>().WithMany().HasForeignKey(x => x.CustomerPackageId).OnDelete(DeleteBehavior.NoAction);
    }
}
