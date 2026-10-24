using System.Security.Claims;
using System.Text.Json;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentReviewDetailsTests
{
    private static Klcn021HealthBeautyContext Db() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
        .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);

    private static T AsUser<T>(T controller, int accountId = 1, string role = "Customer") where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext
        {
            User = new ClaimsPrincipal(new ClaimsIdentity([
                new Claim(ClaimTypes.NameIdentifier, accountId.ToString()), new Claim(ClaimTypes.Role, role)
            ], "test"))
        } };
        return controller;
    }

    private static async Task Seed(Klcn021HealthBeautyContext db)
    {
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Owner" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Other" });
        db.Lichhens.Add(new Lichhen { LichHenId = 1, KhachHangId = 1, NhanVienId = 10,
            NgayGioHen = new DateTime(2026, 10, 20, 9, 0, 0), TrangThai = "HoanThanh" });
        db.Hoadons.Add(new Hoadon { HoaDonId = 1, LichHenId = 1, KhachHangId = 1,
            NgayLap = new DateTime(2026, 10, 20, 10, 0, 0), TrangThai = "DaThanhToan" });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
    }

    private static async Task<JsonElement> Items(Klcn021HealthBeautyContext db, int accountId = 1, string role = "Customer")
    {
        var result = await AsUser(new AppointmentsController(db), accountId, role)
            .GetMine(null, null, null, null, null);
        var value = Assert.IsType<OkObjectResult>(result).Value;
        return JsonSerializer.SerializeToElement(value, new JsonSerializerOptions(JsonSerializerDefaults.Web)).GetProperty("items");
    }

    [Fact]
    public async Task ReviewTextAndReplySurviveReloadThroughActualListEndpoint()
    {
        await using var db = Db();
        await Seed(db);
        var created = await AsUser(new ReviewsController(db)).CreateForAppointment(1,
            new ReviewRequest(5, "Appointment feedback"), default);
        Assert.IsType<CreatedResult>(created);
        db.ChangeTracker.Clear();
        var review = await db.Danhgia.SingleAsync();
        review.Reply = "Thank you";
        review.RepliedAt = new DateTime(2026, 10, 21, 3, 30, 0);
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();

        var item = (await Items(db))[0];
        Assert.True(item.GetProperty("hasReviewed").GetBoolean());
        Assert.Equal(5, item.GetProperty("reviewStars").GetInt32());
        Assert.Equal("Appointment feedback", item.GetProperty("reviewComment").GetString());
        Assert.Equal(review.NgayDanhGia, item.GetProperty("reviewedAt").GetDateTime());
        Assert.Equal("Thank you", item.GetProperty("reviewReply").GetString());
        Assert.Equal(DateTimeKind.Utc, item.GetProperty("reviewRepliedAt").GetDateTime().Kind);
        Assert.Equal(1, item.GetProperty("invoiceId").GetInt32());
        Assert.Equal("Cash", item.GetProperty("fundingSource").GetString());
    }

    [Theory]
    [InlineData("ChoDuyet")]
    [InlineData("DaAn")]
    public async Task OwnerCanReadOwnNonDeletedReviewRegardlessOfPublicVisibility(string status)
    {
        await using var db = Db();
        await Seed(db);
        db.Danhgia.Add(new Danhgium { HoaDonId = 1, SoSao = 3, BinhLuan = "Own feedback",
            NgayDanhGia = new DateTime(2026, 10, 20, 11, 0, 0), TrangThai = status });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        Assert.Equal("Own feedback", (await Items(db))[0].GetProperty("reviewComment").GetString());
        Assert.Equal(0, (await Items(db, 2)).GetArrayLength());
    }

    [Fact]
    public async Task DeletedReviewKeepsDuplicateGuardButDoesNotExposeDeletedContent()
    {
        await using var db = Db();
        await Seed(db);
        db.Danhgia.Add(new Danhgium { HoaDonId = 1, SoSao = 2, BinhLuan = "Removed", Reply = "Removed reply",
            NgayDanhGia = DateTime.Now, RepliedAt = DateTime.UtcNow, TrangThai = "An", IsDeleted = true });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        var item = (await Items(db))[0];
        Assert.True(item.GetProperty("hasReviewed").GetBoolean());
        foreach (var property in new[] { "reviewStars", "reviewComment", "reviewedAt", "reviewReply", "reviewRepliedAt" })
            Assert.Equal(JsonValueKind.Null, item.GetProperty(property).ValueKind);
        Assert.IsType<ConflictObjectResult>(await AsUser(new ReviewsController(db))
            .CreateForAppointment(1, new ReviewRequest(5, "Replacement"), default));
    }

    [Fact]
    public async Task UnreviewedAppointmentHasNullReviewFieldsAndExistingInvoiceData()
    {
        await using var db = Db();
        await Seed(db);
        var item = (await Items(db))[0];
        Assert.False(item.GetProperty("hasReviewed").GetBoolean());
        Assert.Equal("DaThanhToan", item.GetProperty("invoiceStatus").GetString());
        foreach (var property in new[] { "reviewStars", "reviewComment", "reviewedAt", "reviewReply", "reviewRepliedAt" })
            Assert.Equal(JsonValueKind.Null, item.GetProperty(property).ValueKind);
    }

    [Fact]
    public async Task StaffOnlyReceivesReviewDetailsForAssignedAppointments()
    {
        await using var db = Db();
        await Seed(db);
        db.Nhanviens.AddRange(new Nhanvien { NhanVienId = 10, TaiKhoanId = 10, HoTen = "Assigned" },
            new Nhanvien { NhanVienId = 11, TaiKhoanId = 11, HoTen = "Unassigned" });
        db.Danhgia.Add(new Danhgium { HoaDonId = 1, SoSao = 4, BinhLuan = "Private feedback",
            NgayDanhGia = DateTime.Now, TrangThai = "HienThi" });
        await db.SaveChangesAsync();
        db.ChangeTracker.Clear();
        Assert.Equal("Private feedback", (await Items(db, 10, "Staff"))[0].GetProperty("reviewComment").GetString());
        Assert.Equal(0, (await Items(db, 11, "Staff")).GetArrayLength());
        var forbidden = await AsUser(new AppointmentsController(db), 12, "Staff")
            .GetMine(null, null, null, null, null);
        Assert.IsType<ForbidResult>(forbidden);
    }
}
