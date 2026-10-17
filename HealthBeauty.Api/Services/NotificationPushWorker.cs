using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

// Durable outbox: SQL compare-and-swap leases prevent two workers claiming a row together.
// Delivery is at least once: a retry of a partial batch or an expired lease may repeat successful pushes.
// Clients should deduplicate by notificationId; inbox data remains the source of truth.
public sealed class NotificationPushDispatcher(
    Klcn021HealthBeautyContext db, INotificationPushSender sender, TimeProvider clock,
    ILogger<NotificationPushDispatcher> logger)
{
    public const int MaximumAttempts = 5;
    private static readonly TimeSpan LeaseDuration = TimeSpan.FromMinutes(2);

    public async Task<int> DispatchOnceAsync(CancellationToken cancellationToken = default)
    {
        if (!sender.IsConfigured) return 0;
        var now = clock.GetUtcNow().UtcDateTime;
        await RetireExhaustedAsync(now, cancellationToken);
        var candidates = await db.ThongBaos.AsNoTracking()
            .Where(x => x.PushStatus == "Pending" && x.NextPushAt <= now &&
                (x.PushLeaseUntil == null || x.PushLeaseUntil <= now))
            .OrderBy(x => x.ThongBaoId).Take(10).ToListAsync(cancellationToken);
        var processed = 0;
        foreach (var notification in candidates)
        {
            cancellationToken.ThrowIfCancellationRequested();
            var lease = Guid.NewGuid().ToString("N");
            now = clock.GetUtcNow().UtcDateTime;
            if (!await ClaimAsync(notification.ThongBaoId, lease, now, cancellationToken)) continue;
            notification.PushAttempts = await db.ThongBaos.AsNoTracking()
                .Where(x => x.ThongBaoId == notification.ThongBaoId && x.PushLeaseId == lease)
                .Select(x => x.PushAttempts).SingleAsync(cancellationToken);
            processed++;
            try
            {
                if (notification.PushAttempts > MaximumAttempts)
                {
                    await CompleteAsync(notification.ThongBaoId, lease, "Failed", now, cancellationToken);
                    continue;
                }
                var retry = false;
                var failed = false;
                var sent = false;
                var devicesFound = false;
                var cursor = 0;
                var leaseLost = false;
                while (true)
                {
                    // Query each batch anew so broadcasts do not retain a stale account/token list.
                    var batch = await EligibleDevices(notification).AsNoTracking().Where(x => x.Id > cursor)
                        .OrderBy(x => x.Id).Take(500).ToListAsync(cancellationToken);
                    if (batch.Count == 0) break;
                    cursor = batch[^1].Id;
                    if (!await RenewLeaseAsync(notification.ThongBaoId, lease, cancellationToken))
                    { leaseLost = true; break; }
                    var ids = batch.Select(x => x.Id).ToArray();
                    var current = await EligibleDevices(notification).AsNoTracking()
                        .Where(x => ids.Contains(x.Id)).ToListAsync(cancellationToken);
                    batch = batch.Where(snapshot => current.Any(x => SameBinding(x, snapshot))).ToList();
                    if (batch.Count == 0) continue;
                    devicesFound = true;
                    var result = await sender.SendAsync(notification, batch.Select(x => x.FcmToken).ToArray(), cancellationToken);
                    if (result.Count != batch.Count) throw new InvalidOperationException("Push result count mismatch.");
                    for (var i = 0; i < result.Count; i++)
                    {
                        switch (result[i])
                        {
                            case NotificationPushOutcome.Sent: sent = true; break;
                            case NotificationPushOutcome.Retry: retry = true; break;
                            case NotificationPushOutcome.Unregistered:
                                await DisableUnregisteredAsync(batch[i], cancellationToken);
                                failed = true;
                                break;
                            default: failed = true; break;
                        }
                    }
                }
                if (leaseLost) continue;
                var status = retry && notification.PushAttempts < MaximumAttempts ? "Pending" :
                    !devicesFound ? "NoDevices" : retry || failed ? sent ? "Partial" : "Failed" : "Sent";
                await CompleteAsync(notification.ThongBaoId, lease, status,
                    clock.GetUtcNow().UtcDateTime.Add(RetryDelay(notification.PushAttempts)), cancellationToken);
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
            catch (Exception exception) when (exception is not OutOfMemoryException)
            {
                logger.LogWarning("Notification {NotificationId} push attempt failed ({ErrorType}).",
                    notification.ThongBaoId, exception.GetType().Name);
                await CompleteAsync(notification.ThongBaoId, lease,
                    notification.PushAttempts < MaximumAttempts ? "Pending" : "Failed",
                    clock.GetUtcNow().UtcDateTime.Add(RetryDelay(notification.PushAttempts)), cancellationToken);
            }
        }
        return processed;
    }

    public static TimeSpan RetryDelay(int attempts) =>
        TimeSpan.FromSeconds(Math.Min(3600, 60 * Math.Pow(2, Math.Clamp(attempts - 1, 0, 6))));

    public IQueryable<ThietBiKhachHang> EligibleDevices(ThongBao notification) =>
        from device in db.ThietBiKhachHangs
        join account in db.Taikhoans on device.TaiKhoanId equals account.TaiKhoanId
        join customer in db.Khachhangs on device.KhachHangId equals (int?)customer.KhachHangId
        join role in db.Vaitros on account.VaiTroId equals role.VaiTroId
        where (notification.TaiKhoanId != null || notification.KhachHangId == null) &&
            device.TrangThai && account.TrangThai && role.TenVaiTro == "Customer" &&
            customer.TaiKhoanId == account.TaiKhoanId &&
            (notification.TaiKhoanId == null || account.TaiKhoanId == notification.TaiKhoanId) &&
            (notification.KhachHangId == null || customer.KhachHangId == notification.KhachHangId)
        select device;

    private static bool SameBinding(ThietBiKhachHang current, ThietBiKhachHang snapshot) =>
        current.Id == snapshot.Id && current.TaiKhoanId == snapshot.TaiKhoanId &&
        current.KhachHangId == snapshot.KhachHangId && current.FcmToken == snapshot.FcmToken &&
        current.NgayCapNhat == snapshot.NgayCapNhat;

    private async Task RetireExhaustedAsync(DateTime now, CancellationToken cancellationToken)
    {
        var query = db.ThongBaos.Where(x => x.PushStatus == "Pending" && x.PushAttempts >= MaximumAttempts &&
            (x.PushLeaseUntil == null || x.PushLeaseUntil <= now));
        if (db.Database.IsRelational())
            await query.ExecuteUpdateAsync(set => set.SetProperty(x => x.PushStatus, "Failed")
                .SetProperty(x => x.PushLeaseId, (string?)null).SetProperty(x => x.PushLeaseUntil, (DateTime?)null), cancellationToken);
        else
        {
            var rows = await query.ToListAsync(cancellationToken);
            foreach (var row in rows)
            {
                row.PushStatus = "Failed"; row.PushLeaseId = null; row.PushLeaseUntil = null;
            }
            await db.SaveChangesAsync(cancellationToken);
            foreach (var row in rows) db.Entry(row).State = EntityState.Detached;
        }
    }

    private async Task<bool> ClaimAsync(int id, string lease, DateTime now, CancellationToken cancellationToken)
    {
        var query = db.ThongBaos.Where(x => x.ThongBaoId == id && x.PushStatus == "Pending" &&
            x.PushAttempts < MaximumAttempts && x.NextPushAt <= now && (x.PushLeaseUntil == null || x.PushLeaseUntil <= now));
        var until = now.Add(LeaseDuration);
        if (db.Database.IsRelational())
            return await query.ExecuteUpdateAsync(set => set.SetProperty(x => x.PushLeaseId, lease)
                .SetProperty(x => x.PushLeaseUntil, until).SetProperty(x => x.PushAttempts, x => x.PushAttempts + 1),
                cancellationToken) == 1;
        // EF InMemory test provider only; production SQL always takes the atomic branch above.
        var item = await query.SingleOrDefaultAsync(cancellationToken);
        if (item is null) return false;
        item.PushLeaseId = lease; item.PushLeaseUntil = until; item.PushAttempts++;
        await db.SaveChangesAsync(cancellationToken);
        db.Entry(item).State = EntityState.Detached;
        return true;
    }

    private async Task<bool> RenewLeaseAsync(int id, string lease, CancellationToken cancellationToken)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var until = now.Add(LeaseDuration);
        var query = db.ThongBaos.Where(x => x.ThongBaoId == id && x.PushLeaseId == lease && x.PushLeaseUntil > now);
        if (db.Database.IsRelational())
            return await query.ExecuteUpdateAsync(set => set.SetProperty(x => x.PushLeaseUntil, until), cancellationToken) == 1;
        var item = await query.SingleOrDefaultAsync(cancellationToken);
        if (item is null) return false;
        item.PushLeaseUntil = until; await db.SaveChangesAsync(cancellationToken);
        db.Entry(item).State = EntityState.Detached;
        return true;
    }

    private async Task CompleteAsync(int id, string lease, string status, DateTime next, CancellationToken cancellationToken)
    {
        var query = db.ThongBaos.Where(x => x.ThongBaoId == id && x.PushLeaseId == lease);
        if (db.Database.IsRelational())
            await query.ExecuteUpdateAsync(set => set.SetProperty(x => x.PushStatus, status)
                .SetProperty(x => x.NextPushAt, next).SetProperty(x => x.PushLeaseId, (string?)null)
                .SetProperty(x => x.PushLeaseUntil, (DateTime?)null), cancellationToken);
        else
        {
            var item = await query.SingleOrDefaultAsync(cancellationToken);
            if (item is null) return;
            item.PushStatus = status; item.NextPushAt = next; item.PushLeaseId = null; item.PushLeaseUntil = null;
            await db.SaveChangesAsync(cancellationToken);
            db.Entry(item).State = EntityState.Detached;
        }
    }

    private async Task DisableUnregisteredAsync(ThietBiKhachHang snapshot, CancellationToken cancellationToken)
    {
        var query = db.ThietBiKhachHangs.Where(x => x.Id == snapshot.Id && x.TaiKhoanId == snapshot.TaiKhoanId &&
            x.KhachHangId == snapshot.KhachHangId && x.FcmToken == snapshot.FcmToken &&
            x.NgayCapNhat == snapshot.NgayCapNhat);
        if (db.Database.IsRelational())
            await query.ExecuteUpdateAsync(set => set.SetProperty(x => x.TrangThai, false), cancellationToken);
        else
        {
            var item = await query.SingleOrDefaultAsync(cancellationToken);
            if (item is null) return;
            item.TrangThai = false; await db.SaveChangesAsync(cancellationToken);
            db.Entry(item).State = EntityState.Detached;
        }
    }
}

public sealed class NotificationPushWorker(IServiceScopeFactory scopeFactory,
    ILogger<NotificationPushWorker> logger) : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(5));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = scopeFactory.CreateScope();
                await scope.ServiceProvider.GetRequiredService<NotificationPushDispatcher>().DispatchOnceAsync(stoppingToken);
                if (!await timer.WaitForNextTickAsync(stoppingToken)) break;
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            catch (Exception exception) when (exception is not OutOfMemoryException)
            {
                logger.LogWarning("Notification push worker will retry ({ErrorType}).", exception.GetType().Name);
                try { await Task.Delay(TimeSpan.FromSeconds(5), stoppingToken); }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested) { break; }
            }
        }
    }
}
