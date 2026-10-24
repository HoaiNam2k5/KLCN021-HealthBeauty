using System.Security.Claims;
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

public sealed class CustomerSelfServiceTests
{
    private const string Original = "old-password-123";
    private static readonly byte[] Png = [137, 80, 78, 71, 13, 10, 26, 10, 0];
    private sealed class Storage : ICloudinaryImageStorage
    {
        public bool IsConfigured { get; set; } = true;
        public Exception? Error { get; set; }
        public Func<Task>? BeforeReturn { get; set; }
        public int Calls { get; private set; }
        public async Task<UploadImageResponse> UploadAsync(byte[] bytes, string type, CancellationToken ct)
        {
            Calls++;
            if (Error is not null) throw Error;
            if (BeforeReturn is not null) await BeforeReturn();
            return new("https://res.cloudinary.com/demo/image/upload/avatar.png", "avatar-test");
        }
    }
    private sealed class Fixture : IAsyncDisposable
    {
        public readonly DbContextOptions<Klcn021HealthBeautyContext> Options = new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options;
        public Klcn021HealthBeautyContext Db { get; }
        public readonly PasswordService Passwords = new();
        public readonly Storage Images = new();
        public readonly IConfiguration Config = new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?>
        {
            ["Jwt:Key"] = "customer-self-service-only-tests-secret-32-characters", ["Jwt:Issuer"] = "Test", ["Jwt:Audience"] = "Test"
        }).Build();
        public Fixture() => Db = new(Options);
        public async Task Seed()
        {
            Db.Vaitros.Add(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" });
            for (var i = 1; i <= 2; i++)
            {
                Db.Taikhoans.Add(new Taikhoan { TaiKhoanId = i, VaiTroId = 1, Email = $"customer{i}@example.test", MatKhauHash = Passwords.Hash(Original), TrangThai = true });
                Db.Khachhangs.Add(new Khachhang { KhachHangId = i, TaiKhoanId = i, HoTen = $"Customer {i}", DiemThuong = 100, AvatarUrl = "https://example.test/old.png", RowVersion = [1] });
                Db.Refreshtokens.Add(new Refreshtoken { TaiKhoanId = i, TokenHash = $"session-{i}", CreatedAt = DateTime.UtcNow, ExpiresAt = DateTime.UtcNow.AddDays(1) });
            }
            await Db.SaveChangesAsync(); Db.ChangeTracker.Clear();
        }
        public AuthController Auth(int id = 1, Klcn021HealthBeautyContext? db = null, IPasswordService? passwords = null) => User(
            new AuthController(db ?? Db, passwords ?? Passwords, new TokenService(Config), Config), id);
        public CustomerAvatarController Avatar(int id = 1) => User(new CustomerAvatarController(Db, Images), id);
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private static T User<T>(T controller, int id = 1) where T : ControllerBase
    {
        controller.ControllerContext = new ControllerContext { HttpContext = new DefaultHttpContext
        { User = new ClaimsPrincipal(new ClaimsIdentity([new Claim(ClaimTypes.NameIdentifier, id.ToString()), new Claim(ClaimTypes.Role, "Customer")], "Test")) } };
        return controller;
    }
    private static UploadImageRequest File(byte[]? bytes = null, string type = "image/png") => new()
    {
        File = new FormFile(new MemoryStream(bytes ?? Png), 0, (bytes ?? Png).Length, "File", "avatar.png")
        { Headers = new HeaderDictionary(), ContentType = type }
    };

    [Fact]
    public async Task AvatarUploadAndDeleteAffectOnlyCurrentCustomerAndPreserveProfilePoints()
    {
        await using var f = new Fixture(); await f.Seed();
        var controller = f.Avatar();
        var avatar = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.Upload(File(), default)).Result).Value);
        Assert.Equal(1, avatar.Id); Assert.Equal(100, avatar.RewardPoints); Assert.Equal("Customer 1", avatar.FullName);
        Assert.EndsWith("avatar.png", avatar.AvatarUrl);
        Assert.Equal("https://example.test/old.png", (await f.Db.Khachhangs.FindAsync(2))!.AvatarUrl);
        var deleted = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.Delete(default)).Result).Value);
        Assert.Null(deleted.AvatarUrl); Assert.Equal(100, deleted.RewardPoints);
        Assert.Equal(1, f.Images.Calls);
    }

    [Fact]
    public async Task LegacyProfileUpdatesAndReadsPreserveAvatar()
    {
        await using var f = new Fixture(); await f.Seed();
        var controller = User(new CustomersController(f.Db));
        var updated = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.UpdateMe(new("Renamed", "0901234567", "Nam"), default)).Result).Value);
        Assert.Equal("https://example.test/old.png", updated.AvatarUrl);
        var mine = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.Me(default)).Result).Value);
        Assert.Equal(updated.AvatarUrl, mine.AvatarUrl);
        var managed = Assert.IsType<CustomerResponse>(Assert.IsType<OkObjectResult>((await controller.Update(1, new("Managed", null, null), default)).Result).Value);
        Assert.Equal(updated.AvatarUrl, managed.AvatarUrl);
    }

    [Theory]
    [InlineData("image/svg+xml")]
    [InlineData("image/png")]
    public async Task InvalidAvatarDoesNotCallStorageOrMutateCustomer(string type)
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.IsType<BadRequestObjectResult>((await f.Avatar().Upload(File([0, 1, 2], type), default)).Result);
        Assert.Equal(0, f.Images.Calls); Assert.Equal("https://example.test/old.png", (await f.Db.Khachhangs.FindAsync(1))!.AvatarUrl);
    }

    [Fact]
    public async Task OversizedOrMissingAvatarIsRejected()
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.IsType<BadRequestObjectResult>((await f.Avatar().Upload(new(), default)).Result);
        var response = Assert.IsType<ObjectResult>((await f.Avatar().Upload(File(new byte[ImageUploadValidation.MaximumImageBytes + 1]), default)).Result);
        Assert.Equal(413, response.StatusCode); Assert.Equal(0, f.Images.Calls);
    }

    [Theory]
    [InlineData("disabled", 503)]
    [InlineData("timeout", 504)]
    [InlineData("provider", 502)]
    public async Task FailedUploadKeepsExistingImage(string problem, int status)
    {
        await using var f = new Fixture(); await f.Seed();
        f.Images.IsConfigured = problem != "disabled";
        f.Images.Error = problem == "timeout" ? new TimeoutException() : problem == "provider" ? new ImageStorageException() : null;
        Assert.Equal(status, Assert.IsType<ObjectResult>((await f.Avatar().Upload(File(), default)).Result).StatusCode);
        Assert.Equal("https://example.test/old.png", (await f.Db.Khachhangs.FindAsync(1))!.AvatarUrl); Assert.Empty(f.Db.Auditlogs);
    }

    [Fact]
    public async Task CustomerChangedDuringUploadProducesConflictWithoutOverwritingConcurrentUpdate()
    {
        await using var f = new Fixture(); await f.Seed();
        f.Images.BeforeReturn = async () =>
        {
            await using var concurrent = new Klcn021HealthBeautyContext(f.Options);
            var customer = (await concurrent.Khachhangs.FindAsync(1))!;
            customer.HoTen = "Concurrent name"; customer.DiemThuong = 150; customer.RowVersion = [2];
            await concurrent.SaveChangesAsync();
        };
        Assert.IsType<ConflictObjectResult>((await f.Avatar().Upload(File(), default)).Result);
        var current = (await f.Db.Khachhangs.FindAsync(1))!;
        Assert.Equal("Concurrent name", current.HoTen); Assert.Equal(150, current.DiemThuong); Assert.Equal("https://example.test/old.png", current.AvatarUrl);
    }

    [Fact]
    public async Task PasswordChangeRotatesStampAndRevokesOnlyOwnedSessionsWithoutLeakingPassword()
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.IsType<NoContentResult>(await f.Auth().ChangePassword(new(Original, "new-password-456"), default));
        var account = (await f.Db.Taikhoans.FindAsync(1))!;
        Assert.True(f.Passwords.Verify("new-password-456", account.MatKhauHash)); Assert.False(f.Passwords.Verify(Original, account.MatKhauHash));
        Assert.Equal(32, account.SecurityStamp!.Length);
        Assert.NotNull((await f.Db.Refreshtokens.SingleAsync(x => x.TaiKhoanId == 1)).RevokedAt);
        Assert.Null((await f.Db.Refreshtokens.SingleAsync(x => x.TaiKhoanId == 2)).RevokedAt);
        var audit = Assert.Single(f.Db.Auditlogs);
        Assert.DoesNotContain(Original, audit.NewValues); Assert.DoesNotContain("new-password-456", audit.NewValues);
    }

    [Theory]
    [InlineData("wrong-old", "new-password-456")]
    [InlineData(Original, Original)]
    [InlineData(Original, "short")]
    public async Task BadPasswordProofOrNewPasswordDoesNotMutateAccount(string old, string next)
    {
        await using var f = new Fixture(); await f.Seed();
        Assert.IsType<BadRequestObjectResult>(await f.Auth().ChangePassword(new(old, next), default));
        Assert.True(f.Passwords.Verify(Original, (await f.Db.Taikhoans.FindAsync(1))!.MatKhauHash));
        Assert.Empty(f.Db.Auditlogs); Assert.All(f.Db.Refreshtokens, x => Assert.Null(x.RevokedAt));
    }

    [Theory]
    [InlineData(false)]
    [InlineData(true)]
    public async Task InactiveOrLockedAccountCannotChangePassword(bool locked)
    {
        await using var f = new Fixture(); await f.Seed();
        var account = (await f.Db.Taikhoans.FindAsync(1))!; account.TrangThai = locked; account.KhoaDen = locked ? DateTime.UtcNow.AddHours(1) : null;
        await f.Db.SaveChangesAsync();
        Assert.IsType<UnauthorizedResult>(await f.Auth().ChangePassword(new(Original, "new-password-456"), default));
    }

    private sealed class CompetingPasswordService(PasswordService inner, Action beforeHash) : IPasswordService
    {
        public string Hash(string password) { beforeHash(); return inner.Hash(password); }
        public bool Verify(string password, string hash) => inner.Verify(password, hash);
    }

    [Fact]
    public async Task LegacyLongCurrentPasswordCanBeChangedToBoundedNewPassword()
    {
        await using var f = new Fixture(); await f.Seed();
        var legacyPassword = new string('x', 256);
        (await f.Db.Taikhoans.FindAsync(1))!.MatKhauHash = f.Passwords.Hash(legacyPassword);
        await f.Db.SaveChangesAsync();
        Assert.IsType<NoContentResult>(await f.Auth().ChangePassword(new(legacyPassword, "new-password-456"), default));
    }

    [Fact]
    public async Task ConcurrentPasswordChangeCannotOverwriteWinningPassword()
    {
        await using var f = new Fixture(); await f.Seed();
        var competing = new CompetingPasswordService(f.Passwords, () =>
        {
            using var other = new Klcn021HealthBeautyContext(f.Options);
            var account = other.Taikhoans.Find(1)!;
            account.MatKhauHash = f.Passwords.Hash("winner-password-123"); account.SecurityStamp = Guid.NewGuid().ToString("N");
            other.SaveChanges();
        });
        Assert.IsType<ConflictObjectResult>(await f.Auth(passwords: competing).ChangePassword(new(Original, "loser-password-123"), default));
        Assert.True(f.Passwords.Verify("winner-password-123", (await f.Db.Taikhoans.FindAsync(1))!.MatKhauHash));
    }
}
