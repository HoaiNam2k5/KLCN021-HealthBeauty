using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ExcelAppointmentCasesTests
{
    [Fact]
    public async Task BOOK03_CustomerCannotCreatePastAppointment()
    {
        await using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Customer" });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, TenDichVu = "Facial", Gia = 100000, ThoiLuongPhut = 60, TrangThai = true });
        await db.SaveChangesAsync();
        var controller = new AppointmentsController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "1"), new Claim(ClaimTypes.Role, "Customer")], "test"))
        } } };
        var request = new CreateAppointmentRequest(DateTime.Now.AddDays(-1), [new AppointmentItemRequest(1, null, 0)], null, null, null);

        var result = await controller.Create(request, default);

        Assert.IsType<BadRequestObjectResult>(result.Result);
        Assert.Empty(await db.Lichhens.ToListAsync());
    }
}
