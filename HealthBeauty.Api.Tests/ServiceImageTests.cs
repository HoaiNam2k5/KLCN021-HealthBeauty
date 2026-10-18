using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ServiceImageTests
{
    private static Klcn021HealthBeautyContext Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Loaidichvus.Add(new Loaidichvu { LoaiDichVuId = 1, TenLoai = "Category", TrangThai = true });
        db.Dichvus.Add(new Dichvu { DichVuId = 1, LoaiDichVuId = 1, TenDichVu = "Service", Gia = 100, ThoiLuongPhut = 30, TrangThai = true });
        db.SaveChanges();
        return db;
    }

    [Fact]
    public async Task ServiceImage_RoundTripsAndSupportsPreserveReplaceClear()
    {
        await using var db = Database();
        var controller = new ServicesController(db);
        var created = await controller.CreateService(new(1, "New service", 100, 30, null, "https://example.com/service.png"), default);
        var response = Assert.IsType<ServiceResponse>(Assert.IsType<CreatedAtActionResult>(created.Result).Value);
        Assert.Equal("https://example.com/service.png", response.ImageUrl);
        var id = response.Id;
        var detail = await controller.GetService(id, default);
        Assert.Equal(response.ImageUrl, Assert.IsType<ServiceResponse>(Assert.IsType<OkObjectResult>(detail.Result).Value).ImageUrl);
        var list = await controller.Services(null, "New", default);
        Assert.Equal(response.ImageUrl, Assert.Single(Assert.IsAssignableFrom<IEnumerable<ServiceResponse>>(Assert.IsType<OkObjectResult>(list.Result).Value)).ImageUrl);
        await controller.UpdateService(id, new(1, "New service", 100, 30, null), default);
        Assert.Equal(response.ImageUrl, (await db.Dichvus.FindAsync(id))!.ImageUrl);
        await controller.UpdateService(id, new(1, "New service", 100, 30, null, "http://example.com/new.jpg"), default);
        Assert.Equal("http://example.com/new.jpg", (await db.Dichvus.FindAsync(id))!.ImageUrl);
        await controller.UpdateService(id, new(1, "New service", 100, 30, null, ""), default);
        Assert.Null((await db.Dichvus.FindAsync(id))!.ImageUrl);
    }

    [Fact]
    public async Task ComboImage_RoundTripsAndSupportsPreserveReplaceClear()
    {
        await using var db = Database();
        var controller = new CombosController(db);
        var request = new ComboRequest("Combo", 100, null, null, [new(1, 1)], "https://example.com/combo.png");
        var response = Assert.IsType<ComboResponse>(Assert.IsType<CreatedAtActionResult>(await controller.Create(request, default)).Value);
        Assert.Equal(request.ImageUrl, response.ImageUrl);
        Assert.Equal(request.ImageUrl, Assert.IsType<ComboResponse>(Assert.IsType<OkObjectResult>(await controller.Get(response.Id, default)).Value).ImageUrl);
        Assert.Equal(request.ImageUrl, Assert.Single(Assert.IsAssignableFrom<IEnumerable<ComboResponse>>(Assert.IsType<OkObjectResult>(await controller.List(default)).Value)).ImageUrl);
        await controller.Update(response.Id, request with { ImageUrl = null }, default);
        Assert.Equal(request.ImageUrl, (await db.Combodichvus.FindAsync(response.Id))!.ImageUrl);
        await controller.Update(response.Id, request with { ImageUrl = "http://example.com/new.jpg" }, default);
        Assert.Equal("http://example.com/new.jpg", (await db.Combodichvus.FindAsync(response.Id))!.ImageUrl);
        await controller.Update(response.Id, request with { ImageUrl = "" }, default);
        Assert.Null((await db.Combodichvus.FindAsync(response.Id))!.ImageUrl);
    }

    [Theory]
    [InlineData("javascript:alert(1)")]
    [InlineData("data:image/png;base64,test")]
    [InlineData("file:///tmp/image.png")]
    [InlineData("/relative/image.png")]
    [InlineData("https://user:password@example.com/image.png")]
    [InlineData("https://example.com/image\r\n.png")]
    public async Task InvalidUrls_AreRejectedWithoutMutatingServiceOrCombo(string url)
    {
        await using var db = Database();
        db.Combodichvus.Add(new Combodichvu { ComboId = 1, TenCombo = "Existing", GiaCombo = 100, TrangThai = true, ImageUrl = "https://example.com/old.png" });
        await db.SaveChangesAsync();
        var services = new ServicesController(db);
        var combos = new CombosController(db);
        Assert.IsType<BadRequestObjectResult>((await services.CreateService(new(1, "Invalid", 100, 30, null, url), default)).Result);
        Assert.IsType<BadRequestObjectResult>(await services.UpdateService(1, new(1, "Changed", 500, 30, null, url), default));
        var request = new ComboRequest("Changed", 500, null, null, [new(1, 1)], url);
        Assert.IsType<BadRequestObjectResult>(await combos.Create(request, default));
        Assert.IsType<BadRequestObjectResult>(await combos.Update(1, request, default));
        Assert.Equal("Service", (await db.Dichvus.FindAsync(1))!.TenDichVu);
        Assert.Equal("Existing", (await db.Combodichvus.FindAsync(1))!.TenCombo);
        Assert.Equal("https://example.com/old.png", (await db.Combodichvus.FindAsync(1))!.ImageUrl);
        Assert.Single(db.Dichvus);
        Assert.Single(db.Combodichvus);
        Assert.Empty(db.ChangeTracker.Entries().Where(x => x.State is EntityState.Modified or EntityState.Added or EntityState.Deleted));
    }

    [Fact]
    public async Task OverlongUrl_IsRejected()
    {
        await using var db = Database();
        var url = "https://example.com/" + new string('a', 2048);
        Assert.IsType<BadRequestObjectResult>((await new ServicesController(db).CreateService(new(1, "Invalid", 100, 30, null, url), default)).Result);
        Assert.IsType<BadRequestObjectResult>(await new CombosController(db).Create(new("Invalid", 100, null, null, [new(1, 1)], url), default));
    }
}
