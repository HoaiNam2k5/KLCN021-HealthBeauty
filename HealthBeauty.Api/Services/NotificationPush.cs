using System.Globalization;
using System.Text.Json;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using HealthBeauty.Api.Configuration;
using HealthBeauty.Api.Models;
using Microsoft.Extensions.Options;

namespace HealthBeauty.Api.Services;

public enum NotificationPushOutcome { Sent, Unregistered, Retry, Failed }

public interface INotificationPushSender
{
    bool IsConfigured { get; }
    Task<IReadOnlyList<NotificationPushOutcome>> SendAsync(ThongBao notification,
        IReadOnlyList<string> tokens, CancellationToken cancellationToken);
}

// Sending requires explicit opt-in and a private service account file; no automatic credential discovery.
public sealed class FirebaseNotificationPushSender : INotificationPushSender, IDisposable
{
    private readonly FirebaseOptions options;
    private readonly IHostEnvironment environment;
    private readonly ILogger<FirebaseNotificationPushSender> logger;
    private readonly object gate = new();
    private FirebaseApp? app;
    private bool initialized;

    public FirebaseNotificationPushSender(IOptions<FirebaseOptions> options, IHostEnvironment environment,
        ILogger<FirebaseNotificationPushSender> logger)
    {
        this.options = options.Value;
        this.environment = environment;
        this.logger = logger;
    }

    public bool IsConfigured => GetApp() is not null;

    private FirebaseApp? GetApp()
    {
        lock (gate)
        {
            if (initialized) return app;
            initialized = true;
            var configuredPath = string.IsNullOrWhiteSpace(options.CredentialsPath) ? options.CredentialFile : options.CredentialsPath;
            if (!options.Enabled || string.IsNullOrWhiteSpace(configuredPath)) return null;
            try
            {
                var path = Path.IsPathRooted(configuredPath) ? configuredPath :
                    Path.Combine(environment.ContentRootPath, configuredPath);
                using var document = JsonDocument.Parse(File.ReadAllText(path));
                if (!document.RootElement.TryGetProperty("type", out var type) || type.GetString() != "service_account")
                    throw new InvalidOperationException("A service account credential is required.");
                app = FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromFile(path),
                    ProjectId = string.IsNullOrWhiteSpace(options.ProjectId) ? null : options.ProjectId
                }, "healthbeauty-push-" + Guid.NewGuid().ToString("N"));
            }
            catch (Exception exception) when (exception is not OutOfMemoryException)
            {
                logger.LogWarning("Firebase push unavailable; check private credentials ({ErrorType}). Inbox remains available.",
                    exception.GetType().Name);
            }
            return app;
        }
    }

    public static MulticastMessage BuildMessage(ThongBao notification, IReadOnlyList<string> tokens)
    {
        if (tokens.Count is < 1 or > 500) throw new ArgumentOutOfRangeException(nameof(tokens));
        var data = new Dictionary<string, string>
        {
            ["notificationId"] = notification.ThongBaoId.ToString(CultureInfo.InvariantCulture),
            ["type"] = notification.LoaiThongBao
        };
        if (!string.IsNullOrWhiteSpace(notification.DuLieuKemTheo))
        {
            data["payload"] = notification.DuLieuKemTheo;
            try
            {
                using var document = JsonDocument.Parse(notification.DuLieuKemTheo);
                if (document.RootElement.ValueKind == JsonValueKind.Object)
                    foreach (var property in document.RootElement.EnumerateObject())
                        if (property.Name != "notificationId" && property.Name != "payload" &&
                            property.Value.ValueKind == JsonValueKind.String)
                            data[property.Name] = property.Value.GetString()!;
            }
            catch (JsonException) { /* Legacy payload stays available as a raw string. */ }
        }
        return new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification { Title = notification.TieuDe, Body = notification.NoiDung },
            Data = data,
            Android = new AndroidConfig
            {
                Notification = new AndroidNotification { ChannelId = "spa_notifications", Sound = "default" }
            },
            Apns = new ApnsConfig { Aps = new Aps { Sound = "default" } }
        };
    }

    public static NotificationPushOutcome Classify(MessagingErrorCode? code) => code switch
    {
        MessagingErrorCode.Unregistered => NotificationPushOutcome.Unregistered,
        MessagingErrorCode.Unavailable or MessagingErrorCode.Internal or MessagingErrorCode.QuotaExceeded
            => NotificationPushOutcome.Retry,
        _ => NotificationPushOutcome.Failed
    };

    public async Task<IReadOnlyList<NotificationPushOutcome>> SendAsync(ThongBao notification,
        IReadOnlyList<string> tokens, CancellationToken cancellationToken)
    {
        var firebase = GetApp() ?? throw new InvalidOperationException("Firebase push is not configured.");
        using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeout.CancelAfter(TimeSpan.FromSeconds(45));
        try
        {
            var result = await FirebaseMessaging.GetMessaging(firebase)
                .SendEachForMulticastAsync(BuildMessage(notification, tokens), timeout.Token);
            return result.Responses.Select(x => x.IsSuccess ? NotificationPushOutcome.Sent :
                Classify(x.Exception?.MessagingErrorCode)).ToArray();
        }
        catch (FirebaseMessagingException exception)
        {
            return Enumerable.Repeat(Classify(exception.MessagingErrorCode), tokens.Count).ToArray();
        }
        catch (OperationCanceledException) when (!cancellationToken.IsCancellationRequested)
        {
            return Enumerable.Repeat(NotificationPushOutcome.Retry, tokens.Count).ToArray();
        }
    }

    public void Dispose()
    {
        lock (gate) { app?.Delete(); app = null; }
    }
}

public static class NotificationPushRegistration
{
    public static IServiceCollection AddNotificationPush(this IServiceCollection services,
        IConfiguration configuration, IHostEnvironment environment)
    {
        services.Configure<FirebaseOptions>(configuration.GetSection(FirebaseOptions.SectionName));
        services.AddSingleton<INotificationPushSender, FirebaseNotificationPushSender>();
        services.AddScoped<NotificationPushDispatcher>();
        services.AddHostedService<NotificationPushWorker>();
        return services;
    }
}
