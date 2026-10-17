namespace HealthBeauty.Api.Models;

public sealed class PasswordResetChallenge
{
    public int TaiKhoanId { get; set; }
    public string ChallengeId { get; set; } = null!;
    public string Version { get; set; } = null!;
    public string? OtpHash { get; set; }
    public DateTime ExpiresAt { get; set; }
    public int Attempts { get; set; }
    public DateTime LastRequestedAt { get; set; }
    public DateTime SendWindowStartedAt { get; set; }
    public int SendCount { get; set; }
    public DateTime? UsedAt { get; set; }
    public string? SecurityStampAtIssue { get; set; }
    public Taikhoan TaiKhoan { get; set; } = null!;
}
