using System.Text.Json;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class AppointmentReminderTests
{
    private sealed class Clock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => new(2026, 10, 18, 3, 0, 0, TimeSpan.Zero);
        public override TimeZoneInfo LocalTimeZone => TimeZoneInfo.CreateCustomTimeZone("TestVN", TimeSpan.FromHours(7), "TestVN", "TestVN");
    }
    private static readonly Clock Time = new();
    private static readonly DateTime Now = Time.GetLocalNow().DateTime;
    private static AppointmentReminderService Service(Klcn021HealthBeautyContext db, bool enabled = true) =>
        new(db, Time, Options.Create(new AppointmentReminderOptions { Enabled = enabled }));
    private static async Task<Klcn021HealthBeautyContext> Database()
    {
        var db = new Klcn021HealthBeautyContext(new DbContextOptionsBuilder<Klcn021HealthBeautyContext>()
            .UseInMemoryDatabase(Guid.NewGuid().ToString()).Options);
        db.Taikhoans.Add(new Taikhoan { TaiKhoanId = 1, Email = "test@example.invalid", MatKhauHash = "unused", TrangThai = true });
        db.Khachhangs.Add(new Khachhang { KhachHangId = 1, TaiKhoanId = 1, HoTen = "Test" });
        await db.SaveChangesAsync(); db.ChangeTracker.Clear(); return db;
    }
    private static Lichhen Appointment(int id, double minutes = 30, string status = "DaXacNhan", int customer = 1) =>
        new() { LichHenId = id, KhachHangId = customer, NgayGioHen = Now.AddMinutes(minutes), TrangThai = status };

    [Theory]
    [InlineData(-1, false)]
    [InlineData(0, false)]
    [InlineData(1, true)]
    [InlineData(60, true)]
    [InlineData(60.001, false)]
    public async Task IncludesOnlyFutureAppointmentsWithinLeadWindow(double minutes, bool expected)
    {
        await using var db = await Database();
        db.Lichhens.Add(Appointment(1, minutes)); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(expected ? 1 : 0, await Service(db).ProcessOnceAsync());
    }
    [Theory]
    [InlineData("ChoXacNhan")]
    [InlineData("DaHuy")]
    [InlineData("HoanThanh")]
    [InlineData("DangThucHien")]
    public async Task UnconfirmedCancelledAndCompletedDoNotReceiveReminder(string status)
    {
        await using var db = await Database(); db.Lichhens.Add(Appointment(1, status: status));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(0, await Service(db).ProcessOnceAsync());
    }
    [Fact]
    public async Task PersistsDedupAcrossServiceRestartAndRescheduledAppointmentGetsNewReminder()
    {
        await using var db = await Database(); db.Lichhens.Add(Appointment(1));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(1, await Service(db).ProcessOnceAsync()); db.ChangeTracker.Clear();
        Assert.Equal(0, await Service(db).ProcessOnceAsync());
        var first = await db.ThongBaos.AsNoTracking().SingleAsync();
        Assert.Equal(Time.GetUtcNow().UtcDateTime, first.NgayTao);
        Assert.Equal(1, first.TaiKhoanId); Assert.Equal("Pending", first.PushStatus);
        var data = JsonSerializer.Deserialize<Dictionary<string, string>>(first.DuLieuKemTheo!)!;
        Assert.Equal("REMINDER", data["event"]); Assert.Equal("1", data["appointmentId"]);
        var appointment = await db.Lichhens.SingleAsync(); appointment.NgayGioHen = Now.AddMinutes(45);
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(1, await Service(db).ProcessOnceAsync());
        Assert.Equal(2, await db.ThongBaos.Select(x => x.EventKey).Distinct().CountAsync());
    }
    [Fact]
    public async Task CustomersWithoutLoginAndInactiveAccountsAreSkipped()
    {
        await using var db = await Database();
        (await db.Taikhoans.SingleAsync()).TrangThai = false;
        db.Khachhangs.Add(new Khachhang { KhachHangId = 2, HoTen = "No login" });
        db.Lichhens.AddRange(Appointment(1), Appointment(2, customer: 2));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(0, await Service(db).ProcessOnceAsync()); Assert.Empty(await db.ThongBaos.ToListAsync());
    }
    [Fact]
    public async Task DisabledCreatesNothing()
    {
        await using var db = await Database(); db.Lichhens.Add(Appointment(1)); await db.SaveChangesAsync();
        Assert.Equal(0, await Service(db, false).ProcessOnceAsync());
    }
    [Fact]
    public async Task AlreadyRemindedFirstPageDoesNotStarveLaterAppointments()
    {
        await using var db = await Database();
        db.Lichhens.AddRange(Enumerable.Range(1, 101).Select(id => Appointment(id)));
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(100, await Service(db).ProcessOnceAsync());
        Assert.Equal(1, await Service(db).ProcessOnceAsync());
        Assert.Equal(101, await db.ThongBaos.CountAsync());
    }

    private sealed class Sender : INotificationPushSender
    {
        public bool IsConfigured => true;
        public int Calls;
        public Task<IReadOnlyList<NotificationPushOutcome>> SendAsync(ThongBao message, IReadOnlyList<string> tokens, CancellationToken ct)
        {
            Calls++;
            return Task.FromResult<IReadOnlyList<NotificationPushOutcome>>(tokens.Select(_ => NotificationPushOutcome.Sent).ToArray());
        }
    }
    [Theory]
    [InlineData("current", true)]
    [InlineData("cancelled", false)]
    [InlineData("rescheduled", false)]
    [InlineData("past", false)]
    [InlineData("customerChanged", false)]
    [InlineData("orphan", false)]
    [InlineData("badJson", false)]
    [InlineData("nonObjectJson", false)]
    [InlineData("badDate", false)]
    [InlineData("nonReminder", true)]
    public async Task DispatcherSuppressesStaleRemindersBeforeNetwork(string change, bool sends)
    {
        await using var db = await Database();
        db.Vaitros.Add(new Vaitro { VaiTroId = 1, TenVaiTro = "Customer" });
        (await db.Taikhoans.SingleAsync()).VaiTroId = 1;
        db.ThietBiKhachHangs.Add(new ThietBiKhachHang { Id = 1, TaiKhoanId = 1, KhachHangId = 1,
            FcmToken = "fake", TrangThai = true, NgayCapNhat = Time.GetUtcNow().UtcDateTime });
        db.Lichhens.Add(Appointment(1)); await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        Assert.Equal(1, await Service(db).ProcessOnceAsync());
        var appointment = await db.Lichhens.SingleAsync();
        var notice = await db.ThongBaos.SingleAsync();
        if (change == "cancelled") appointment.TrangThai = "DaHuy";
        if (change == "rescheduled") appointment.NgayGioHen = Now.AddMinutes(45);
        if (change == "past") appointment.NgayGioHen = Now.AddMinutes(-1);
        if (change == "customerChanged") appointment.KhachHangId = 2;
        if (change == "orphan") db.Lichhens.Remove(appointment);
        if (change == "badJson") notice.DuLieuKemTheo = "{broken";
        if (change == "nonObjectJson") notice.DuLieuKemTheo = "[]";
        if (change == "badDate") notice.DuLieuKemTheo = "{\"appointmentId\":\"1\",\"appointmentAt\":\"wrong\"}";
        if (change == "nonReminder") { notice.EventKey = null; notice.DuLieuKemTheo = "legacy data"; appointment.TrangThai = "DaHuy"; }
        await db.SaveChangesAsync(); db.ChangeTracker.Clear();
        var sender = new Sender();
        var dispatcher = new NotificationPushDispatcher(db, sender, Time,
            Microsoft.Extensions.Logging.Abstractions.NullLogger<NotificationPushDispatcher>.Instance);
        Assert.Equal(1, await dispatcher.DispatchOnceAsync());
        Assert.Equal(sends ? 1 : 0, sender.Calls);
        Assert.Equal(sends ? "Sent" : "Skipped", (await db.ThongBaos.AsNoTracking().SingleAsync()).PushStatus);
    }
}
