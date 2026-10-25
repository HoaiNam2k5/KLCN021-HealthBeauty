using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Models;

public sealed class SePayTransaction
{
    public long Id { get; set; }
    public int? InvoiceId { get; set; }
    public decimal Amount { get; set; }
    public string Gateway { get; set; } = "";
    public string AccountNumber { get; set; } = "";
    public string TransferType { get; set; } = "";
    public string Content { get; set; } = "";
    public string? ReferenceCode { get; set; }
    public string Outcome { get; set; } = "";
    public DateTime ReceivedAt { get; set; }
    public DateTime TransactionAt { get; set; }
}

public partial class Klcn021HealthBeautyContext
{
    public DbSet<SePayTransaction> SePayTransactions { get; set; }

    private static void ConfigureBankTransfers(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<SePayTransaction>(e =>
        {
            e.ToTable("SePayTransaction");
            e.HasKey(x => x.Id);
            e.Property(x => x.Id).ValueGeneratedNever();
            e.Property(x => x.Amount).HasColumnType("decimal(18,2)");
            e.Property(x => x.Gateway).HasMaxLength(100);
            e.Property(x => x.AccountNumber).HasMaxLength(19).IsUnicode(false);
            e.Property(x => x.TransferType).HasMaxLength(5).IsUnicode(false);
            e.Property(x => x.Content).HasMaxLength(2000);
            e.Property(x => x.ReferenceCode).HasMaxLength(100);
            e.Property(x => x.Outcome).HasMaxLength(30).IsUnicode(false);
            e.Property(x => x.ReceivedAt).HasPrecision(7);
            e.Property(x => x.TransactionAt).HasPrecision(0);
            e.HasIndex(x => x.InvoiceId, "UX_SePayTransaction_PaidInvoice")
                .IsUnique().HasFilter("[Outcome] = 'Paid'");
            e.HasIndex(x => x.ReceivedAt, "IX_SePayTransaction_ReceivedAt");
            e.HasOne<Hoadon>().WithMany().HasForeignKey(x => x.InvoiceId).OnDelete(DeleteBehavior.NoAction);
        });
    }
}
