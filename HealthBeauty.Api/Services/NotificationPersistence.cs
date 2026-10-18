using HealthBeauty.Api.Models;
using Microsoft.EntityFrameworkCore;

namespace HealthBeauty.Api.Services;

public static class NotificationPersistence
{
    public static async Task<bool> TrySaveAsync(Klcn021HealthBeautyContext db, CancellationToken ct)
    {
        try { await db.SaveChangesAsync(ct); return true; }
        catch (DbUpdateConcurrencyException)
        {
            // EF's SQL transaction rolls back both business changes and staged notifications.
            db.ChangeTracker.Clear();
            return false;
        }
    }
}
