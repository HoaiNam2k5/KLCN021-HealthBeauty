using HealthBeauty.Api.Contracts;
using HealthBeauty.Api.Controllers;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class ExcelRegistrationCasesTests
{
    private sealed class Passwords : IPasswordService
    {
        public string Hash(string value) => "test-hash:" + value;
        public bool Verify(string value, string hash) => hash == Hash(value);
    }
    private sealed class Tokens : ITokenService
    {
        public (string Token, DateTime ExpiresAt) CreateAccessToken(Taikhoan account) => ("test-token", DateTime.UtcNow.AddMinutes(30));
        public string CreateRefreshToken() => Guid.NewGuid().ToString();
        public string HashRefreshToken(string token) => token;
    }
    private static Klcn021HealthBeautyContext NewDatabase() => new(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>().UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
    private static AuthController Controller(Klcn021HealthBeautyContext db) => new(db, new Passwords(), new Tokens(), new ConfigurationBuilder().AddInMemoryCollection().Build())
    { ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext() } };

    [Fact]
    public async Task AUTH01_RegisterCreatesCustomerAndSession()
    {
        await using var db = NewDatabase();
        var result = await Controller(db).Register(new RegisterRequest(" NEW@example.test ", "Password123!", " Customer Test ", "0900000000"), default);
        var response = Assert.IsType<AuthResponse>(Assert.IsType<OkObjectResult>(result.Result).Value);
        var account = await db.Taikhoans.SingleAsync();
        var customer = await db.Khachhangs.SingleAsync();
        Assert.Equal("new@example.test", account.Email);
        Assert.Equal(account.TaiKhoanId, customer.TaiKhoanId);
        Assert.Equal(account.TaiKhoanId, response.Account.Id);
        Assert.Single(await db.Refreshtokens.ToListAsync());
    }

    [Fact]
    public async Task AUTH02_DuplicateEmailDoesNotCreateCustomerOrSession()
    {
        await using var db = NewDatabase();
        var controller = Controller(db);
        var request = new RegisterRequest("customer@example.test", "Password123!", "Customer", "0900000000");
        Assert.IsType<OkObjectResult>((await controller.Register(request, default)).Result);
        Assert.IsType<ConflictObjectResult>((await controller.Register(request with { Email = " CUSTOMER@example.test " }, default)).Result);
        Assert.Equal(1, await db.Taikhoans.CountAsync());
        Assert.Equal(1, await db.Khachhangs.CountAsync());
        Assert.Equal(1, await db.Refreshtokens.CountAsync());
    }
}
