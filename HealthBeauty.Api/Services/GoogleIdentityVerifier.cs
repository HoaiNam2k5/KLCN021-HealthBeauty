using System.ComponentModel.DataAnnotations;
using Google.Apis.Auth;

namespace HealthBeauty.Api.Services;

public sealed record VerifiedGoogleIdentity(
    string Subject, string Email, bool EmailVerified, string? Name, string? Picture, string? HostedDomain);

public interface IGoogleIdentityVerifier
{
    bool IsConfigured { get; }
    Task<VerifiedGoogleIdentity?> VerifyAsync(string idToken, CancellationToken cancellationToken);
}

// This boundary always verifies the signature; it must never be replaced by a JWT decoder in production.
public interface IGoogleIdTokenValidator
{
    Task<GoogleJsonWebSignature.Payload> ValidateAsync(string idToken, IReadOnlyList<string> audiences,
        CancellationToken cancellationToken);
}

public sealed class GoogleSignedIdTokenValidator : IGoogleIdTokenValidator
{
    public Task<GoogleJsonWebSignature.Payload> ValidateAsync(string idToken, IReadOnlyList<string> audiences,
        CancellationToken cancellationToken) => GoogleJsonWebSignature.ValidateAsync(idToken,
            new GoogleJsonWebSignature.ValidationSettings { Audience = audiences }).WaitAsync(cancellationToken);
}

public sealed class GoogleIdentityVerifier : IGoogleIdentityVerifier
{
    public const int MaximumTokenLength = 16384;
    private readonly string[] audiences;
    private readonly IGoogleIdTokenValidator validator;
    private readonly TimeProvider clock;

    public GoogleIdentityVerifier(IConfiguration configuration, IGoogleIdTokenValidator? validator = null,
        TimeProvider? clock = null)
    {
        audiences = configuration.GetSection("Authentication:Google:ClientIds").Get<string[]>()?
            .Where(value => !string.IsNullOrWhiteSpace(value)).Select(value => value.Trim())
            .Distinct(StringComparer.Ordinal).ToArray() ?? [];
        this.validator = validator ?? new GoogleSignedIdTokenValidator();
        this.clock = clock ?? TimeProvider.System;
    }

    public bool IsConfigured => audiences.Length > 0;

    public async Task<VerifiedGoogleIdentity?> VerifyAsync(string idToken, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        if (!IsConfigured || string.IsNullOrWhiteSpace(idToken) || idToken.Length > MaximumTokenLength) return null;
        GoogleJsonWebSignature.Payload payload;
        try
        {
            payload = await validator.ValidateAsync(idToken, audiences, cancellationToken);
        }
        catch (InvalidJwtException) { return null; }
        catch (FormatException) { return null; }
        catch (ArgumentException) { return null; }

        // Check the signed claims as well, so tests and alternate validation adapters cannot silently omit them.
        if (payload.Issuer is not ("accounts.google.com" or "https://accounts.google.com")
            || payload.AudienceAsList?.Any(audience => audiences.Contains(audience, StringComparer.Ordinal)) != true
            || !payload.ExpirationTimeSeconds.HasValue
            || payload.ExpirationTimeSeconds.Value <= clock.GetUtcNow().ToUnixTimeSeconds()
            || !payload.EmailVerified || string.IsNullOrWhiteSpace(payload.Subject) || payload.Subject.Length > 255
            || string.IsNullOrWhiteSpace(payload.Email) || payload.Email.Length > 255
            || !new EmailAddressAttribute().IsValid(payload.Email)) return null;

        return new VerifiedGoogleIdentity(payload.Subject, payload.Email.Trim().ToLowerInvariant(), true,
            payload.Name, payload.Picture, payload.HostedDomain);
    }
}
