using System.Globalization;
using System.Text.Json;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Services;

public sealed class AppointmentReminderService(
    Klcn021HealthBeautyContext db, TimeProvider clock, IOptions<AppointmentReminderOptions> options)
{
    public async Task<int> ProcessOnceAsync(CancellationToken ct = default)
    {
        if (!options.Value.Enabled) return 0;
        var now = clock.GetLocalNow().DateTime;
        var end = now.AddMinutes(Math.Clamp(options.Value.LeadMinutes, 1, 1440));
        var cursor = 0;
        var created = 0;
        // Page through existing reminders as well, so they never starve later appointments.
        while (created < 100)
        {
            var candidates = await db.Lichhens.AsNoTracking()
                .Where(x => x.LichHenId > cursor && x.TrangThai == "DaXacNhan" &&
                    x.NgayGioHen > now && x.NgayGioHen <= end)
                .OrderBy(x => x.LichHenId).Take(100).Select(x => x.LichHenId).ToListAsync(ct);
            if (candidates.Count == 0) break;
            foreach (var id in candidates)
            {
                ct.ThrowIfCancellationRequested();
                cursor = id;
                var appointment = await db.Lichhens.SingleOrDefaultAsync(x => x.LichHenId == id, ct);
                now = clock.GetLocalNow().DateTime;
                end = now.AddMinutes(Math.Clamp(options.Value.LeadMinutes, 1, 1440));
                if (appointment is null) continue;
                try
                {
                    if (appointment.TrangThai != "DaXacNhan" || appointment.NgayGioHen <= now || appointment.NgayGioHen > end)
                        continue;
                    var accountId = await db.Khachhangs.Where(x => x.KhachHangId == appointment.KhachHangId &&
                            x.TaiKhoanId != null && x.TaiKhoan!.TrangThai)
                        .Select(x => x.TaiKhoanId).SingleOrDefaultAsync(ct);
                    if (accountId is null) continue;
                    var key = FormattableString.Invariant($"appointment-reminder:{id}:{appointment.NgayGioHen.Ticks}:{appointment.KhachHangId}");
                    if (await db.ThongBaos.AnyAsync(x => x.EventKey == key, ct)) continue;
                    var utc = clock.GetUtcNow().UtcDateTime;
                    var notification = new ThongBao
                    {
                        TaiKhoanId = accountId, KhachHangId = appointment.KhachHangId,
                        TieuDe = "Nhắc lịch hẹn HealthBeauty",
                        NoiDung = $"Anh/chị có lịch hẹn lúc {appointment.NgayGioHen:HH:mm dd/MM/yyyy}. Vui lòng đến đúng giờ.",
                        LoaiThongBao = "LichHen", EventKey = key, NgayTao = utc, NextPushAt = utc,
                        DuLieuKemTheo = JsonSerializer.Serialize(new Dictionary<string, string>
                        {
                            ["type"] = "APPOINTMENT", ["event"] = "REMINDER",
                            ["appointmentId"] = id.ToString(CultureInfo.InvariantCulture),
                            ["appointmentAt"] = appointment.NgayGioHen.ToString("O", CultureInfo.InvariantCulture)
                        })
                    };
                    db.ThongBaos.Add(notification);
                    // Force a rowversion-guarded update in the same SaveChanges transaction as the notice.
                    // A concurrently cancelled/rescheduled appointment makes the whole save roll back.
                    db.Entry(appointment).Property(x => x.TrangThai).IsModified = true;
                    try { await db.SaveChangesAsync(ct); created++; }
                    catch (DbUpdateConcurrencyException) { db.Entry(notification).State = EntityState.Detached; }
                    catch (DbUpdateException ex) when (ex.InnerException is SqlException { Number: 2601 or 2627 })
                    { db.Entry(notification).State = EntityState.Detached; }
                }
                finally { db.Entry(appointment).State = EntityState.Detached; }
                if (created >= 100) break;
            }
        }
        return created;
    }
}

public sealed class AppointmentReminderWorker(IServiceScopeFactory scopes,
    IOptions<AppointmentReminderOptions> options, ILogger<AppointmentReminderWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopes.CreateScope();
                await scope.ServiceProvider.GetRequiredService<AppointmentReminderService>().ProcessOnceAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception ex) { logger.LogError(ex, "Appointment reminder processing failed."); }
            try { await Task.Delay(TimeSpan.FromSeconds(Math.Clamp(options.Value.PollSeconds, 10, 3600)), stoppingToken); }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
        }
    }
}

public static class AppointmentReminderRegistration
{
    public static IServiceCollection AddAppointmentReminders(this IServiceCollection services, IConfiguration configuration)
    {
        services.Configure<AppointmentReminderOptions>(configuration.GetSection(AppointmentReminderOptions.SectionName));
        services.AddScoped<AppointmentReminderService>();
        services.AddHostedService<AppointmentReminderWorker>();
        return services;
    }
}
