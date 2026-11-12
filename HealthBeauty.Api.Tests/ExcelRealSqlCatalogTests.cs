using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class SqlCopyFactAttribute : FactAttribute
{
    public SqlCopyFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_RUN_REAL_SQL") != "1")
            Skip = "Requires the explicitly approved local SQL test copy.";
    }
}

// Explicit opt-in: the tests read only the user's isolated local SQL copy.
public sealed class ExcelRealSqlCatalogTests
{
    private static Klcn021HealthBeautyContext OpenCopy(bool writable = false)
    {
        if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_RUN_REAL_SQL") != "1")
            throw new InvalidOperationException("Real SQL tests require explicit HEALTHBEAUTY_RUN_REAL_SQL=1.");
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root != null && !File.Exists(Path.Combine(root.FullName, "KLCN021_HealthBeauty.sln"))) root = root.Parent;
        if (root is null) throw new InvalidOperationException("Project root not found.");
        using var config = JsonDocument.Parse(File.ReadAllText(Path.Combine(root.FullName, "HealthBeauty.Api", "appsettings.Development.local.json")));
        var original = config.RootElement.GetProperty("ConnectionStrings").GetProperty("DefaultConnection").GetString();
        var builder = new SqlConnectionStringBuilder(original);
        if (!string.Equals(builder.DataSource, @"localhost\SQLEXPRESS", StringComparison.OrdinalIgnoreCase))
            throw new InvalidOperationException("Only the approved local SQL Express instance is permitted.");
        builder.InitialCatalog = "KLCN021_HealthBeauty_Test";
        builder.Encrypt = false;
        builder.TrustServerCertificate = true;
        builder.ApplicationIntent = writable ? ApplicationIntent.ReadWrite : ApplicationIntent.ReadOnly;
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseSqlServer(builder.ConnectionString).Options);
        if (db.Database.GetDbConnection().Database != "KLCN021_HealthBeauty_Test") throw new InvalidOperationException("Wrong database.");
        return db;
    }

    private sealed class FakeImageStorage : ICloudinaryImageStorage
    {
        public bool IsConfigured => true;
        public int Calls { get; private set; }
        public Task<UploadImageResponse> UploadAsync(byte[] bytes, string contentType, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult(new UploadImageResponse("https://example.test/real-sql-test-avatar.png", "real-sql-test-avatar"));
        }
    }
    private static T AsCustomer<T>(T controller, int accountId) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext { User = new ClaimsPrincipal(
            new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, "Customer")], "test")) } };
        return controller;
    }

    [SqlCopyFact]
    public async Task CAT01_CAT02_RealSqlCatalogAndSearchMatchActiveData()
    {
        await using var db = OpenCopy();
        var item = await db.Dichvus.AsNoTracking().Where(x => x.TrangThai).OrderBy(x => x.DichVuId).FirstAsync();
        var controller = new ServicesController(db);
        var all = Assert.IsAssignableFrom<IEnumerable<ServiceResponse>>(Assert.IsType<OkObjectResult>((await controller.Services(null, null, default)).Result).Value);
        Assert.Contains(all, x => x.Id == item.DichVuId && x.Name == item.TenDichVu && x.Price == item.Gia);
        var matches = Assert.IsAssignableFrom<IEnumerable<ServiceResponse>>(Assert.IsType<OkObjectResult>((await controller.Services(null, item.TenDichVu, default)).Result).Value);
        Assert.Contains(matches, x => x.Id == item.DichVuId);
        var noMatches = Assert.IsAssignableFrom<IEnumerable<ServiceResponse>>(Assert.IsType<OkObjectResult>((await controller.Services(null, "HB_NO_SUCH_SERVICE_981273", default)).Result).Value);
        Assert.Empty(noMatches);
    }

    [SqlCopyFact]
    public async Task CAT05_RealSqlServiceDetailMatchesPriceAndDuration()
    {
        await using var db = OpenCopy();
        var item = await db.Dichvus.AsNoTracking().Where(x => x.TrangThai).OrderBy(x => x.DichVuId).FirstAsync();
        var response = Assert.IsType<ServiceResponse>(Assert.IsType<OkObjectResult>((await new ServicesController(db).GetService(item.DichVuId, default)).Result).Value);
        Assert.Equal(item.TenDichVu, response.Name);
        Assert.Equal(item.Gia, response.Price);
        Assert.Equal(item.ThoiLuongPhut, response.DurationMinutes);
    }

    [SqlCopyFact]
    public async Task CAT06_RealSqlComboDetailMatchesComponents()
    {
        await using var db = OpenCopy();
        var list = Assert.IsAssignableFrom<IEnumerable<ComboResponse>>(Assert.IsType<OkObjectResult>(await new CombosController(db).List(default)).Value).ToList();
        Assert.NotEmpty(list);
        var combo = list.First(x => x.Items.Count > 0);
        var detail = Assert.IsType<ComboResponse>(Assert.IsType<OkObjectResult>(await new CombosController(db).Get(combo.Id, default)).Value);
        Assert.Equal(combo.Price, detail.Price);
        Assert.Equal(combo.Items.OrderBy(x => x.ServiceId), detail.Items.OrderBy(x => x.ServiceId));
        Assert.All(detail.Items, x => Assert.True(x.Quantity > 0));
    }

    [SqlCopyFact]
    public async Task USER04_RealSqlCustomerInboxRespectsOwnership()
    {
        await using var db = OpenCopy();
        var customer = await db.Khachhangs.AsNoTracking().Where(x => x.TaiKhoanId != null &&
                db.ThongBaos.Any(n => (n.TaiKhoanId == x.TaiKhoanId && (n.KhachHangId == null || n.KhachHangId == x.KhachHangId)) ||
                    (n.TaiKhoanId == null && n.KhachHangId == null)))
            .OrderBy(x => x.KhachHangId).FirstAsync();
        var accountId = customer.TaiKhoanId!.Value;
        var controller = new NotificationsController(db)
        {
            ControllerContext = new ControllerContext
            {
                HttpContext = new DefaultHttpContext
                {
                    User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString())], "test"))
                }
            }
        };
        var result = Assert.IsType<OkObjectResult>(await controller.List(1, 100, false, default));
        Assert.NotNull(result.Value);
        var property = result.Value!.GetType().GetProperty("items");
        Assert.NotNull(property);
        var items = Assert.IsAssignableFrom<IEnumerable<NotificationResponse>>(property!.GetValue(result.Value));
        Assert.NotEmpty(items);
        var allowedIds = await db.ThongBaos.AsNoTracking().Where(x =>
            (x.TaiKhoanId == accountId && (x.KhachHangId == null || x.KhachHangId == customer.KhachHangId)) ||
            (x.TaiKhoanId == null && x.KhachHangId == null)).Select(x => x.ThongBaoId).ToListAsync();
        Assert.All(items, item => Assert.Contains(item.Id, allowedIds));
    }

    [SqlCopyFact]
    public async Task USER01_RealSqlCustomerProfileUpdateIsRolledBack()
    {
        await using var db = OpenCopy(writable: true);
        var customer = await db.Khachhangs.AsNoTracking().Where(x => x.TaiKhoanId != null).OrderBy(x => x.KhachHangId).FirstAsync();
        var beforeName = customer.HoTen;
        await using var tx = await db.Database.BeginTransactionAsync();
        var controller = AsCustomer(new CustomersController(db), customer.TaiKhoanId!.Value);
        var response = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.UpdateMe(new("Khach Kiem Thu SQL", "0900000000", null), default)).Result).Value);
        Assert.Equal("Khach Kiem Thu SQL", response.FullName);
        db.ChangeTracker.Clear();
        Assert.Equal("Khach Kiem Thu SQL", (await db.Khachhangs.SingleAsync(x => x.KhachHangId == customer.KhachHangId)).HoTen);
        await tx.RollbackAsync();
        db.ChangeTracker.Clear();
        Assert.Equal(beforeName, (await db.Khachhangs.SingleAsync(x => x.KhachHangId == customer.KhachHangId)).HoTen);
    }

    [SqlCopyFact]
    public async Task USER02_USER03_RealSqlAvatarAndInvalidUploadAreRolledBack()
    {
        await using var db = OpenCopy(writable: true);
        var customer = await db.Khachhangs.AsNoTracking().Where(x => x.TaiKhoanId != null).OrderBy(x => x.KhachHangId).FirstAsync();
        var beforeAvatar = customer.AvatarUrl;
        await using var tx = await db.Database.BeginTransactionAsync();
        var storage = new FakeImageStorage();
        var controller = AsCustomer(new CustomerAvatarController(db, storage), customer.TaiKhoanId!.Value);
        static UploadImageRequest Request(byte[] data) => new() { File = new FormFile(new MemoryStream(data), 0, data.Length, "File", "avatar.png") { Headers = new HeaderDictionary(), ContentType = "image/png" } };
        var invalid = await controller.Upload(Request([0, 1, 2]), default);
        Assert.IsType<BadRequestObjectResult>(invalid.Result);
        Assert.Equal(0, storage.Calls);
        var upload = await controller.Upload(Request([137, 80, 78, 71, 13, 10, 26, 10, 0]), default);
        var response = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>(upload.Result).Value);
        Assert.EndsWith("real-sql-test-avatar.png", response.AvatarUrl);
        Assert.Equal(1, storage.Calls);
        await tx.RollbackAsync();
        db.ChangeTracker.Clear();
        Assert.Equal(beforeAvatar, (await db.Khachhangs.SingleAsync(x => x.KhachHangId == customer.KhachHangId)).AvatarUrl);
    }

    [SqlCopyFact]
    public async Task USER07_RealSqlEligibleAppointmentCanBeReviewedAndRolledBack()
    {
        await using var db = OpenCopy(writable: true);
        var target = await db.Hoadons.AsNoTracking().Where(x => x.TrangThai == "DaThanhToan" &&
                x.LichHen.TrangThai == "HoanThanh" && x.KhachHang.TaiKhoanId != null &&
                !db.Danhgia.Any(review => review.HoaDonId == x.HoaDonId))
            .Select(x => new { x.HoaDonId, x.LichHenId, AccountId = x.KhachHang.TaiKhoanId!.Value })
            .FirstAsync();
        await using var tx = await db.Database.BeginTransactionAsync();
        var controller = AsCustomer(new ReviewsController(db), target.AccountId);
        var result = await controller.CreateForAppointment(target.LichHenId, new ReviewRequest(5, "Kiểm thử SQL local"), default);
        Assert.IsType<CreatedResult>(result);
        Assert.True(await db.Danhgia.AnyAsync(x => x.HoaDonId == target.HoaDonId && x.SoSao == 5));
        await tx.RollbackAsync();
        db.ChangeTracker.Clear();
        Assert.False(await db.Danhgia.AnyAsync(x => x.HoaDonId == target.HoaDonId));
    }
}
