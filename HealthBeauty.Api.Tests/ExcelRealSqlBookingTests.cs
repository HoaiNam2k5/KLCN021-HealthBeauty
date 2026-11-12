using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace HealthBeauty.Api.Tests;

// Explicit opt-in: the database must be the isolated local copy. The source
// connection string is only read as configuration and is never printed.
public sealed class RealBookingSqlFactAttribute : FactAttribute
{
    public RealBookingSqlFactAttribute()
    {
        if (Environment.GetEnvironmentVariable("HEALTHBEAUTY_RUN_SQL_COPY_TESTS") != "1")
            Skip = "Requires explicit opt-in and the local isolated SQL test copy.";
    }
}

public sealed class ExcelRealSqlBookingTests
{
    private static Klcn021HealthBeautyContext OpenCopy()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "KLCN021_HealthBeauty.sln"))) dir = dir.Parent;
        if (dir is null) throw new InvalidOperationException("Project root was not found.");
        var config = new ConfigurationBuilder().AddJsonFile(Path.Combine(dir.FullName, "HealthBeauty.Api", "appsettings.Development.local.json")).Build();
        var source = config.GetConnectionString("DefaultConnection") ?? throw new InvalidOperationException("Local connection configuration missing.");
        var builder = new SqlConnectionStringBuilder(source);
        var allowed = new[] { @"localhost\SQLEXPRESS", @".\SQLEXPRESS", @"(local)\SQLEXPRESS" };
        if (!allowed.Contains(builder.DataSource, StringComparer.OrdinalIgnoreCase)) throw new InvalidOperationException("Only local SQL Express is allowed.");
        builder.InitialCatalog = "KLCN021_HealthBeauty_Test";
        builder.Encrypt = false;
        builder.TrustServerCertificate = true;
        return new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseSqlServer(builder.ConnectionString).Options);
    }

    [RealBookingSqlFact]
    public async Task BOOK02_BOOK03_BOOK04_RealSqlCopy_ValidPastAndConflictingAppointment()
    {
        await using var db = OpenCopy();
        Assert.Equal("KLCN021_HealthBeauty_Test", db.Database.GetDbConnection().Database);
        await using var transaction = await db.Database.BeginTransactionAsync();
        var accountId = await db.Khachhangs.Where(x => x.TaiKhoanId.HasValue).Select(x => x.TaiKhoanId!.Value).FirstAsync();
        var service = await db.Dichvus.AsNoTracking().Where(x => x.TrangThai && x.ThoiLuongPhut > 0 && x.ThoiLuongPhut <= 240).FirstAsync();
        var staff = await TechnicianEligibility.Query(db).FirstAsync();
        var date = DateOnly.FromDateTime(DateTime.Today.AddDays(300));
        while (await db.Lichlamviecs.AnyAsync(x => x.NhanVienId == staff.NhanVienId && x.NgayLam == date)
            || await db.Lichhens.AnyAsync(x => x.NhanVienId == staff.NhanVienId && x.NgayGioHen >= date.ToDateTime(TimeOnly.MinValue) && x.NgayGioHen < date.AddDays(1).ToDateTime(TimeOnly.MinValue))) date = date.AddDays(1);
        db.Lichlamviecs.Add(new Lichlamviec { NhanVienId = staff.NhanVienId, NgayLam = date, GioBatDau = new TimeOnly(8, 0), GioKetThuc = new TimeOnly(18, 0), TrangThai = "HoatDong" });
        await db.SaveChangesAsync();
        var controller = new AppointmentsController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, "Customer")], "copy-test"))
        } } };
        var items = new List<AppointmentItemRequest> { new(service.DichVuId, null, 0) };
        var past = await controller.Create(new CreateAppointmentRequest(DateTime.Now.AddDays(-1), items, null, null, staff.NhanVienId), default);
        Assert.IsType<BadRequestObjectResult>(past.Result);
        var start = date.ToDateTime(new TimeOnly(9, 0));
        var request = new CreateAppointmentRequest(start, items, "SQL copy test", null, staff.NhanVienId);
        var created = Assert.IsType<CreatedAtActionResult>((await controller.Create(request, default)).Result);
        var appointment = Assert.IsType<AppointmentResponse>(created.Value);
        Assert.True(await db.Lichhens.AnyAsync(x => x.LichHenId == appointment.Id));
        var conflict = await controller.Create(request, default);
        Assert.IsType<ConflictObjectResult>(conflict.Result);
        var otherAccount = await db.Khachhangs.Where(x => x.TaiKhoanId.HasValue && x.TaiKhoanId != accountId).Select(x => x.TaiKhoanId!.Value).FirstAsync();
        var otherController = new AppointmentsController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, otherAccount.ToString()), new Claim(ClaimTypes.Role, "Customer")], "copy-test"))
        } } };
        Assert.IsType<ConflictObjectResult>((await otherController.Create(request, default)).Result);
        Assert.IsType<ConflictObjectResult>((await controller.Create(request with { StaffId = null }, default)).Result);
        Assert.Equal(1, await db.Lichhens.CountAsync(x => x.LichHenId == appointment.Id));
        var management = new AppointmentManagementController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, "Customer")], "copy-test"))
        } } };
        var moved = date.ToDateTime(new TimeOnly(14, 0));
        Assert.IsType<OkObjectResult>(await management.Reschedule(appointment.Id, new AppointmentUpdateRequest(moved, staff.NhanVienId, null), default));
        db.ChangeTracker.Clear();
        var stored = await db.Lichhens.Include(x => x.Chitietlichhens).SingleAsync(x => x.LichHenId == appointment.Id);
        Assert.Equal(moved, stored.NgayGioHen);
        Assert.Equal(service.DichVuId, Assert.Single(stored.Chitietlichhens).DichVuId);
        var reception = new AppointmentManagementController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, "Reception")], "copy-test"))
        } } };
        var receptionList = new AppointmentsController(db) { ControllerContext = new ControllerContext { HttpContext = reception.ControllerContext.HttpContext } };
        var receptionResponse = Assert.IsType<OkObjectResult>(await receptionList.GetMine(moved, moved.AddMinutes(1), null, null, null));
        var receptionItems = Assert.IsAssignableFrom<IEnumerable<AppointmentResponse>>(receptionResponse.Value!.GetType().GetProperty("items")!.GetValue(receptionResponse.Value));
        var visible = Assert.Single(receptionItems.Where(x => x.Id == appointment.Id));
        Assert.False(string.IsNullOrWhiteSpace(visible.CustomerName));
        var history = Assert.IsType<OkObjectResult>(await controller.GetMine(null, null, null, null, null));
        var listed = Assert.IsAssignableFrom<IEnumerable<AppointmentResponse>>(history.Value!.GetType().GetProperty("items")!.GetValue(history.Value));
        Assert.Contains(listed, x => x.Id == appointment.Id);
        Assert.IsType<ConflictObjectResult>(await reception.Status(appointment.Id, new("HoanThanh"), default));
        Assert.IsType<NoContentResult>(await reception.Status(appointment.Id, new("DaXacNhan"), default));
        Assert.IsType<NoContentResult>(await reception.Status(appointment.Id, new("DaDen"), default));
        Assert.IsType<NoContentResult>(await reception.Status(appointment.Id, new("DangThucHien"), default));
        Assert.IsType<NoContentResult>(await reception.Status(appointment.Id, new("HoanThanh"), default));
        db.ChangeTracker.Clear();
        Assert.Equal("HoanThanh", (await db.Lichhens.SingleAsync(x => x.LichHenId == appointment.Id)).TrangThai);
        Assert.True(await db.Hoadons.AnyAsync(x => x.LichHenId == appointment.Id));
        var completedResponse = Assert.IsType<OkObjectResult>(await controller.GetMine(moved, moved.AddMinutes(1), "HoanThanh", null, null));
        var completedItems = Assert.IsAssignableFrom<IEnumerable<AppointmentResponse>>(completedResponse.Value!.GetType().GetProperty("items")!.GetValue(completedResponse.Value));
        Assert.Contains(completedItems, x => x.Id == appointment.Id && x.InvoiceId.HasValue);
        await transaction.RollbackAsync();
        db.ChangeTracker.Clear();
        Assert.False(await db.Lichhens.AnyAsync(x => x.LichHenId == appointment.Id));
        Assert.False(await db.Hoadons.AnyAsync(x => x.LichHenId == appointment.Id));
    }
}
