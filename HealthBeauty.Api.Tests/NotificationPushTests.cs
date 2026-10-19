using FirebaseAdmin.Messaging;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class NotificationPushTests
{
    private sealed class Clock : TimeProvider
    {
        public DateTimeOffset Now = new(2026, 10, 17, 0, 0, 0, TimeSpan.Zero);
        public override DateTimeOffset GetUtcNow() => Now;
    }
    private sealed class Host : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = "Testing";
        public string ApplicationName { get; set; } = "HealthBeauty.Tests";
        public string ContentRootPath { get; set; } = Path.GetTempPath();
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
    private sealed class Sender : INotificationPushSender
    {
        public bool IsConfigured { get; set; } = true;
        public NotificationPushOutcome Outcome = NotificationPushOutcome.Sent;
        public readonly List<string[]> Calls = [];
        public Func<Task>? BeforeResult;
        public bool Throw;
        public async Task<IReadOnlyList<NotificationPushOutcome>> SendAsync(ThongBao message,
            IReadOnlyList<string> tokens, CancellationToken cancellationToken)
        {
            Calls.Add(tokens.ToArray());
            if (BeforeResult is not null) await BeforeResult();
            if (Throw) throw new IOException("sensitive provider detail");
            return tokens.Select(_ => Outcome).ToArray();
        }
    }
    private sealed class Fixture : IAsyncDisposable
    {
        public readonly Clock Clock = new();
        public readonly Sender Sender = new();
        public readonly Klcn021HealthBeautyContext Db;
        public readonly NotificationPushDispatcher Dispatcher;
        public Fixture()
        {
            Db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
                .UseInMemoryDatabase(Guid.NewGuid().ToString("N")).Options);
            Db.Vaitros.AddRange(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" }, new Vaitro { VaiTroId = 2, TenVaiTro = "Admin" });
            for (var id = 1; id <= 4; id++)
            {
                Db.Taikhoans.Add(new Taikhoan { TaiKhoanId = id, VaiTroId = id == 3 ? 2 : 1,
                    Email = $"fake{id}@example.test", MatKhauHash = "fake-hash", TrangThai = id != 4 });
                Db.Khachhangs.Add(new Khachhang { KhachHangId = id * 11, TaiKhoanId = id, HoTen = "Test customer" });
            }
            AddDevice(1, 1, 11); AddDevice(2, 2, 22); AddDevice(3, 1, 22);
            AddDevice(4, 3, 33); AddDevice(5, 4, 44); AddDevice(6, 1, null);
            Db.SaveChanges();
            Db.ChangeTracker.Clear();
            Dispatcher = new NotificationPushDispatcher(Db, Sender, Clock, NullLogger<NotificationPushDispatcher>.Instance);
        }
        public void AddDevice(int id, int account, int? customer) => Db.ThietBiKhachHangs.Add(new ThietBiKhachHang
        {
            Id = id, TaiKhoanId = account, KhachHangId = customer, FcmToken = "fake-token-" + id,
            TrangThai = true, NgayCapNhat = Clock.Now.UtcDateTime
        });
        public async Task<ThongBao> AddNotification(bool broadcast = false)
        {
            var message = Message(); message.TaiKhoanId = broadcast ? null : 1; message.KhachHangId = broadcast ? null : 11;
            message.NgayTao = Clock.Now.UtcDateTime; message.NextPushAt = Clock.Now.UtcDateTime;
            Db.ThongBaos.Add(message); await Db.SaveChangesAsync(); Db.ChangeTracker.Clear(); return message;
        }
        public Task<ThongBao> Saved(int id) => Db.ThongBaos.AsNoTracking().SingleAsync(x => x.ThongBaoId == id);
        public ValueTask DisposeAsync() => Db.DisposeAsync();
    }
    private static ThongBao Message() => new()
    {
        ThongBaoId = 123, TieuDe = "Test title", NoiDung = "Test body", LoaiThongBao = "Test",
        DuLieuKemTheo = "{\"appointmentId\":42}", PushStatus = "Pending"
    };

    [Fact]
    public void PayloadHasStableDedupIdAndroidChannelAndApnsSound()
    {
        var message = FirebaseNotificationPushSender.BuildMessage(Message(), new[] { "fake-token" });
        Assert.Equal("123", message.Data["notificationId"]);
        Assert.Equal("Test", message.Data["type"]);
        Assert.Equal("{\"appointmentId\":42}", message.Data["payload"]);
        Assert.Equal("spa_notifications", message.Android.Notification.ChannelId);
        Assert.Equal("default", message.Android.Notification.Sound);
        Assert.Equal("default", message.Apns.Aps.Sound);
    }
    [Fact]
    public void PayloadFlattensNavigationKeysAndCannotOverrideDedupIdentifier()
    {
        var notification = Message();
        notification.DuLieuKemTheo = "{\"type\":\"APPOINTMENT\",\"appointmentId\":\"42\",\"notificationId\":\"spoof\"}";
        var message = FirebaseNotificationPushSender.BuildMessage(notification, new[] { "fake-token" });
        Assert.Equal("APPOINTMENT", message.Data["type"]);
        Assert.Equal("42", message.Data["appointmentId"]);
        Assert.Equal("123", message.Data["notificationId"]);
    }
    [Theory]
    [InlineData(0)] [InlineData(501)]
    public void PayloadRejectsInvalidBatchSize(int size) => Assert.Throws<ArgumentOutOfRangeException>(() =>
        FirebaseNotificationPushSender.BuildMessage(Message(), Enumerable.Repeat("fake-token", size).ToArray()));

    [Theory]
    [InlineData(MessagingErrorCode.Unregistered, NotificationPushOutcome.Unregistered)]
    [InlineData(MessagingErrorCode.InvalidArgument, NotificationPushOutcome.Failed)]
    [InlineData(MessagingErrorCode.Unavailable, NotificationPushOutcome.Retry)]
    [InlineData(MessagingErrorCode.Internal, NotificationPushOutcome.Retry)]
    [InlineData(MessagingErrorCode.QuotaExceeded, NotificationPushOutcome.Retry)]
    public void OnlyUnregisteredIsTreatedAsInvalidDevice(MessagingErrorCode code, NotificationPushOutcome expected) =>
        Assert.Equal(expected, FirebaseNotificationPushSender.Classify(code));

    [Theory]
    [InlineData(false, "")]
    [InlineData(true, "missing-firebase-credential-unit-test.json")]
    public void MissingOrDisabledFirebaseIsSafeAndDoesNotAttemptNetwork(bool enabled, string path)
    {
        using var sender = new FirebaseNotificationPushSender(Options.Create(new FirebaseOptions
            { Enabled = enabled, CredentialsPath = path }), new Host(), NullLogger<FirebaseNotificationPushSender>.Instance);
        Assert.False(sender.IsConfigured);
    }
    [Fact]
    public async Task MissingFirebaseLeavesPendingInboxAndAttemptsUntouched()
    {
        await using var f = new Fixture(); var message = await f.AddNotification(); f.Sender.IsConfigured = false;
        Assert.Equal(0, await f.Dispatcher.DispatchOnceAsync());
        var saved = await f.Saved(message.ThongBaoId); Assert.Equal("Pending", saved.PushStatus); Assert.Equal(0, saved.PushAttempts);
        Assert.Empty(f.Sender.Calls);
    }
    [Fact]
    public async Task TargetedSendRequiresActiveCustomerOwnedDevice()
    {
        await using var f = new Fixture(); var message = await f.AddNotification();
        Assert.Equal(1, await f.Dispatcher.DispatchOnceAsync());
        Assert.Equal(new[] { "fake-token-1" }, Assert.Single(f.Sender.Calls));
        var saved = await f.Saved(message.ThongBaoId); Assert.Equal("Sent", saved.PushStatus); Assert.Null(saved.PushLeaseId);
        Assert.Equal(0, await f.Dispatcher.DispatchOnceAsync());
    }
    [Fact]
    public async Task BroadcastExcludesInactiveStaffMismatchedAndUnboundDevices()
    {
        await using var f = new Fixture(); await f.AddNotification(true);
        await f.Dispatcher.DispatchOnceAsync();
        Assert.Equal(new[] { "fake-token-1", "fake-token-2" }, Assert.Single(f.Sender.Calls));
    }
    [Fact]
    public async Task BroadcastSplitsIntoBatchesOfAtMost500()
    {
        await using var f = new Fixture(); await f.AddNotification(true);
        for (var i = 7; i <= 1005; i++) f.AddDevice(i, 1, 11);
        await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear(); await f.Dispatcher.DispatchOnceAsync();
        Assert.Equal(new[] { 500, 500, 1 }, f.Sender.Calls.Select(x => x.Length));
    }
    [Fact]
    public async Task InvalidArgumentDoesNotDisableToken()
    {
        await using var f = new Fixture(); await f.AddNotification(); f.Sender.Outcome = NotificationPushOutcome.Failed;
        await f.Dispatcher.DispatchOnceAsync();
        Assert.True((await f.Db.ThietBiKhachHangs.AsNoTracking().SingleAsync(x => x.Id == 1)).TrangThai);
    }
    [Fact]
    public async Task UnregisteredDisablesOnlyTheExactCurrentBinding()
    {
        await using var f = new Fixture(); await f.AddNotification(); f.Sender.Outcome = NotificationPushOutcome.Unregistered;
        await f.Dispatcher.DispatchOnceAsync();
        Assert.False((await f.Db.ThietBiKhachHangs.AsNoTracking().SingleAsync(x => x.Id == 1)).TrangThai);
        Assert.True((await f.Db.ThietBiKhachHangs.AsNoTracking().SingleAsync(x => x.Id == 2)).TrangThai);
    }
    [Fact]
    public async Task UnregisteredResponseCannotDisableReassignedToken()
    {
        await using var f = new Fixture(); await f.AddNotification(); f.Sender.Outcome = NotificationPushOutcome.Unregistered;
        f.Sender.BeforeResult = async () =>
        {
            var device = await f.Db.ThietBiKhachHangs.SingleAsync(x => x.Id == 1);
            device.TaiKhoanId = 2; device.KhachHangId = 22; device.NgayCapNhat = f.Clock.Now.AddSeconds(1).UtcDateTime;
            await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear();
        };
        await f.Dispatcher.DispatchOnceAsync();
        Assert.True((await f.Db.ThietBiKhachHangs.AsNoTracking().SingleAsync(x => x.Id == 1)).TrangThai);
    }
    [Fact]
    public async Task TransientFailureBacksOffAndStopsAfterFiveAttempts()
    {
        await using var f = new Fixture(); var message = await f.AddNotification(); f.Sender.Outcome = NotificationPushOutcome.Retry;
        await f.Dispatcher.DispatchOnceAsync();
        var first = await f.Saved(message.ThongBaoId); Assert.Equal("Pending", first.PushStatus);
        Assert.Equal(f.Clock.Now.UtcDateTime.AddMinutes(1), first.NextPushAt);
        Assert.Equal(0, await f.Dispatcher.DispatchOnceAsync());
        for (var i = 1; i < 5; i++) { f.Clock.Now = f.Clock.Now.AddHours(1); await f.Dispatcher.DispatchOnceAsync(); }
        var last = await f.Saved(message.ThongBaoId); Assert.Equal("Failed", last.PushStatus); Assert.Equal(5, last.PushAttempts);
        f.Clock.Now = f.Clock.Now.AddHours(1); Assert.Equal(0, await f.Dispatcher.DispatchOnceAsync());
    }
    [Fact]
    public async Task SenderExceptionIsRetriedWithoutLosingInbox()
    {
        await using var f = new Fixture(); var message = await f.AddNotification(); f.Sender.Throw = true;
        await f.Dispatcher.DispatchOnceAsync();
        var saved = await f.Saved(message.ThongBaoId); Assert.Equal("Pending", saved.PushStatus); Assert.Equal("Test body", saved.NoiDung);
    }
    [Fact]
    public async Task ActiveLeaseIsSkippedAndExpiredLeaseIsRecovered()
    {
        await using var f = new Fixture(); var message = await f.AddNotification();
        var row = await f.Db.ThongBaos.SingleAsync(); row.PushLeaseId = "other-worker"; row.PushLeaseUntil = f.Clock.Now.AddMinutes(1).UtcDateTime;
        await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear(); Assert.Equal(0, await f.Dispatcher.DispatchOnceAsync());
        f.Clock.Now = f.Clock.Now.AddMinutes(2); Assert.Equal(1, await f.Dispatcher.DispatchOnceAsync());
        Assert.Equal("Sent", (await f.Saved(message.ThongBaoId)).PushStatus);
    }
    [Fact]
    public async Task OrphanCustomerNotificationCannotBecomeBroadcastOrPrivatePush()
    {
        await using var f = new Fixture(); var message = await f.AddNotification();
        var row = await f.Db.ThongBaos.SingleAsync(); row.TaiKhoanId = null;
        await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear(); await f.Dispatcher.DispatchOnceAsync();
        Assert.Equal("NoDevices", (await f.Saved(message.ThongBaoId)).PushStatus); Assert.Empty(f.Sender.Calls);
    }
    [Fact]
    public async Task ExpiredFifthLeaseCannotCauseSixthAttempt()
    {
        await using var f = new Fixture(); var message = await f.AddNotification();
        var row = await f.Db.ThongBaos.SingleAsync(); row.PushAttempts = 5;
        row.PushLeaseId = "dead-worker"; row.PushLeaseUntil = f.Clock.Now.AddMinutes(-1).UtcDateTime;
        await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear(); await f.Dispatcher.DispatchOnceAsync();
        var saved = await f.Saved(message.ThongBaoId);
        Assert.Equal("Failed", saved.PushStatus); Assert.Equal(5, saved.PushAttempts); Assert.Empty(f.Sender.Calls);
    }
    [Fact]
    public async Task TargetWithoutEligibleDeviceBecomesTerminalNoDevices()
    {
        await using var f = new Fixture(); var message = await f.AddNotification();
        var row = await f.Db.ThongBaos.SingleAsync(); row.TaiKhoanId = 4; row.KhachHangId = 44;
        await f.Db.SaveChangesAsync(); f.Db.ChangeTracker.Clear(); await f.Dispatcher.DispatchOnceAsync();
        Assert.Equal("NoDevices", (await f.Saved(message.ThongBaoId)).PushStatus); Assert.Empty(f.Sender.Calls);
    }
}
