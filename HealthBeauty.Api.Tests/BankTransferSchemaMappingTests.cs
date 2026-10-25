using System.Text.RegularExpressions;
using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class BankTransferSchemaMappingTests
{
    private static Klcn021HealthBeautyContext ModelContext() => new(
        new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseSqlServer("Server=unused;Database=ModelOnly;Integrated Security=true;Encrypt=false").Options);

    private static string Script => File.ReadAllText(Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory, "../../../../DB_KLCN021/16_BankTransfers.sql")));

    [Fact]
    public void SqlServerLedgerMappingMatchesAllElevenMigrationColumns()
    {
        using var db = ModelContext();
        var entity = db.Model.FindEntityType(typeof(SePayTransaction))!;
        Assert.Equal("SePayTransaction", entity.GetTableName());
        Assert.Equal("dbo", entity.GetSchema() ?? "dbo");
        var columns = new Dictionary<string, (string Type, bool Nullable)>
        {
            ["Id"] = ("bigint", false), ["InvoiceId"] = ("int", true),
            ["Amount"] = ("decimal(18,2)", false), ["Gateway"] = ("nvarchar(100)", false),
            ["AccountNumber"] = ("varchar(19)", false), ["TransferType"] = ("varchar(5)", false),
            ["Content"] = ("nvarchar(2000)", false), ["ReferenceCode"] = ("nvarchar(100)", true),
            ["Outcome"] = ("varchar(30)", false), ["ReceivedAt"] = ("datetime2(7)", false),
            ["TransactionAt"] = ("datetime2(0)", false)
        };
        Assert.Equal(columns.Count, entity.GetProperties().Count());
        foreach (var (name, expected) in columns)
        {
            var property = entity.FindProperty(name)!;
            Assert.Equal(expected.Type, property.GetRelationalTypeMapping().StoreType.Replace(" ", ""));
            Assert.Equal(expected.Nullable, property.IsNullable);
        }
        var id = entity.FindProperty("Id")!;
        Assert.Equal(ValueGenerated.Never, id.ValueGenerated);
        Assert.Equal("Id", Assert.Single(entity.FindPrimaryKey()!.Properties).Name);
    }

    [Fact]
    public void MigrationCoversAllScalarSettlementDependenciesAndGeneratedKeys()
    {
        using var db = ModelContext();
        var expected = new HashSet<string>();
        foreach (var type in new[] { typeof(Hoadon), typeof(Khachhang), typeof(Thanhtoan), typeof(Giaodichdiem), typeof(ThongBao) })
        {
            var entity = db.Model.FindEntityType(type)!;
            var table = entity.GetTableName()!;
            var store = StoreObjectIdentifier.Table(table, entity.GetSchema());
            foreach (var property in entity.GetProperties()) expected.Add($"{table}.{property.GetColumnName(store)}");
        }
        var prerequisiteBlock = Script.Split("INSERT @required VALUES", 2)[1].Split(';', 2)[0];
        var actual = Regex.Matches(prerequisiteBlock, @"\(N'([^']+)',N'([^']+)'\)")
            .Select(x => $"{x.Groups[1].Value}.{x.Groups[2].Value}").ToHashSet();
        Assert.Equal(46, expected.Count);
        Assert.True(expected.SetEquals(actual), "SQL16 prerequisites must track every mapped scalar used by settlement.");
    }

    [Fact]
    public void LedgerRelationshipsAndIdempotencyIndexesMatchMigration()
    {
        using var db = ModelContext();
        var entity = db.Model.FindEntityType(typeof(SePayTransaction))!;
        var fk = Assert.Single(entity.GetForeignKeys());
        Assert.Equal("InvoiceId", Assert.Single(fk.Properties).Name);
        Assert.Equal("HOADON", fk.PrincipalEntityType.GetTableName());
        Assert.Equal("HoaDonId", Assert.Single(fk.PrincipalKey.Properties).Name);
        Assert.Equal(DeleteBehavior.NoAction, fk.DeleteBehavior);
        var paid = Assert.Single(entity.GetIndexes().Where(x => x.GetDatabaseName() == "UX_SePayTransaction_PaidInvoice"));
        Assert.True(paid.IsUnique);
        Assert.Equal("InvoiceId", Assert.Single(paid.Properties).Name);
        Assert.Equal("[Outcome] = 'Paid'", paid.GetFilter());
        var received = Assert.Single(entity.GetIndexes().Where(x => x.GetDatabaseName() == "IX_SePayTransaction_ReceivedAt"));
        Assert.False(received.IsUnique);
        Assert.Equal("ReceivedAt", Assert.Single(received.Properties).Name);
        Assert.Null(received.GetFilter());
    }
}
