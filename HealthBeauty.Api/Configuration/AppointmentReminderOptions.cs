namespace HealthBeauty.Api.Configuration;

public sealed class AppointmentReminderOptions
{
    public const string SectionName = "AppointmentReminders";
    public bool Enabled { get; set; } = true;
    public int LeadMinutes { get; set; } = 60;
    public int PollSeconds { get; set; } = 60;
}
