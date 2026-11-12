using System.Security.Claims;
using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ExcelCustomerCasesTests
{
    [Fact]
    public async Task USER01_UpdateOwnedProfilePersistsAndCanBeReadBack()
    {
        await using var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Khachhangs.AddRange(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Old" },
            new Khachhang { KhachHangId = 2, TaiKhoanId = 2, HoTen = "Other" });
        await db.SaveChangesAsync();
        var controller = new CustomersController(db) { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext {
            User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, "1")], "test"))
        } } };

        var updated = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.UpdateMe(new UpdateCustomerRequest(" New Name ", " 0900000000 ", " Nam "), default)).Result).Value);
        Assert.Equal("New Name", updated.FullName);
        Assert.Equal("0900000000", updated.Phone);
        db.ChangeTracker.Clear();
        var read = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.Me(default)).Result).Value);
        Assert.Equal("New Name", read.FullName);
        Assert.Equal("0900000000", read.Phone);
        Assert.Equal("Other", (await db.Khachhangs.FindAsync(2))!.HoTen);
    }
}
