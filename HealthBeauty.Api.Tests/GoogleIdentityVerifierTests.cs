using Google.Apis.Auth;
using HealthBeauty.Api.Services;
using Microsoft.Extensions.Configuration;
using Xunit;

namespace HealthBeauty.Api.Tests;

public sealed class GoogleIdentityVerifierTests
{
    private const string ClientId = "trusted-client.apps.googleusercontent.com";
    private sealed class Clock : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => DateTimeOffset.FromUnixTimeSeconds(2_000_000_000);
    }
    private sealed class Validator : IGoogleIdTokenValidator
    {
        public int Calls { get; private set; }
        public IReadOnlyList<string>? Audiences { get; private set; }
        public GoogleJsonWebSignature.Payload Payload { get; set; } = ValidPayload();
        public Exception? Exception { get; set; }
        public Task<GoogleJsonWebSignature.Payload> ValidateAsync(string idToken, IReadOnlyList<string> audiences,
            CancellationToken cancellationToken)
        {
            Calls++; Audiences = audiences;
            return Exception is null ? Task.FromResult(Payload) : Task.FromException<GoogleJsonWebSignature.Payload>(Exception);
        }
    }
    private static GoogleJsonWebSignature.Payload ValidPayload() => new()
    {
        Subject = "verified-subject", Email = "Customer@Example.com", EmailVerified = true,
        Audience = ClientId, Issuer = "https://accounts.google.com", ExpirationTimeSeconds = 2_000_000_060,
        Name = "Verified customer", Picture = "https://example.com/photo.jpg", HostedDomain = "example.com",
    };
    private static GoogleIdentityVerifier Service(Validator validator, params string[] ids) => new(
        new ConfigurationBuilder().AddInMemoryCollection(ids.Select((id, index) =>
            new KeyValuePair<string, string?>($"Authentication:Google:ClientIds:{index}", id))).Build(), validator, new Clock());

    [Fact]
    public async Task MissingAudienceConfigurationFailsClosedWithoutCallingGoogle()
    {
        var validator = new Validator(); var service = Service(validator);
        Assert.False(service.IsConfigured);
        Assert.Null(await service.VerifyAsync("signed-token", default));
        Assert.Equal(0, validator.Calls);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task EmptyTokenDoesNotCallValidator(string token)
    {
        var validator = new Validator();
        Assert.Null(await Service(validator, ClientId).VerifyAsync(token, default));
        Assert.Equal(0, validator.Calls);
    }

    [Fact]
    public async Task OversizedTokenDoesNotCallValidator()
    {
        var validator = new Validator();
        Assert.Null(await Service(validator, ClientId).VerifyAsync(new string('a', GoogleIdentityVerifier.MaximumTokenLength + 1), default));
        Assert.Equal(0, validator.Calls);
    }

    [Fact]
    public async Task SignedVerifiedClaimsProduceNormalizedIdentityAndPassAudienceAllowlist()
    {
        var validator = new Validator(); var identity = await Service(validator, " " + ClientId + " ", ClientId).VerifyAsync("signed-token", default);
        Assert.NotNull(identity); Assert.Equal("verified-subject", identity.Subject);
        Assert.Equal("customer@example.com", identity.Email); Assert.True(identity.EmailVerified);
        Assert.Equal("Verified customer", identity.Name); Assert.Equal("example.com", identity.HostedDomain);
        Assert.Equal(new[] { ClientId }, validator.Audiences);
    }

    [Theory]
    [InlineData("issuer")]
    [InlineData("audience")]
    [InlineData("missingAudience")]
    [InlineData("expired")]
    [InlineData("missingExpiry")]
    [InlineData("unverifiedEmail")]
    [InlineData("missingEmail")]
    [InlineData("invalidEmail")]
    [InlineData("missingSubject")]
    [InlineData("longSubject")]
    public async Task MissingOrUntrustedSignedClaimsAreRejected(string invalid)
    {
        var validator = new Validator(); var payload = validator.Payload;
        switch (invalid)
        {
            case "issuer": payload.Issuer = "https://attacker.example"; break;
            case "audience": payload.Audience = "another-client"; break;
            case "missingAudience": payload.Audience = null; break;
            case "expired": payload.ExpirationTimeSeconds = 2_000_000_000; break;
            case "missingExpiry": payload.ExpirationTimeSeconds = null; break;
            case "unverifiedEmail": payload.EmailVerified = false; break;
            case "missingEmail": payload.Email = ""; break;
            case "invalidEmail": payload.Email = "not-an-email"; break;
            case "missingSubject": payload.Subject = ""; break;
            case "longSubject": payload.Subject = new string('a', 256); break;
        }
        Assert.Null(await Service(validator, ClientId).VerifyAsync("signed-token", default));
    }

    [Fact]
    public async Task InvalidSignatureReportedByGoogleIsRejected()
    {
        var validator = new Validator { Exception = new InvalidJwtException("invalid signature") };
        Assert.Null(await Service(validator, ClientId).VerifyAsync("signed-token", default));
    }

    [Fact]
    public async Task CancellationIsNotConvertedIntoAuthenticationFailure()
    {
        using var source = new CancellationTokenSource(); source.Cancel();
        var validator = new Validator();
        await Assert.ThrowsAnyAsync<OperationCanceledException>(() => Service(validator, ClientId).VerifyAsync("signed-token", source.Token));
        Assert.Equal(0, validator.Calls);
    }

    [Fact]
    public async Task InfrastructureFailureIsNotAcceptedAsIdentityOrHiddenAsInvalidToken()
    {
        var validator = new Validator { Exception = new HttpRequestException("Google certificate endpoint unavailable") };
        await Assert.ThrowsAsync<HttpRequestException>(() => Service(validator, ClientId).VerifyAsync("signed-token", default));
    }
}
