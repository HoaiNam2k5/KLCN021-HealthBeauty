using System.Text;
using HealthBeauty.Api.Models;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

if (builder.Environment.IsDevelopment())
{
    // Optional machine-local settings; environment and command-line overrides win.
    builder.Configuration.AddJsonFile("appsettings.Development.local.json", optional: true, reloadOnChange: false);
    builder.Configuration.AddEnvironmentVariables();
    builder.Configuration.AddCommandLine(args);
}

var jwtKey = builder.Configuration["Jwt:Key"];
if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
    throw new InvalidOperationException("Configure Jwt:Key with a secret of at least 32 characters using User Secrets or an environment variable.");

PasswordRecoveryService.ValidateConfiguration(builder.Configuration);

// Add services to the container.

builder.Services.Configure<BankTransferOptions>(builder.Configuration.GetSection(BankTransferOptions.Section));
builder.Services.AddScoped<DatabasePermissionFilter>();
builder.Services.AddControllers(options => options.Filters.AddService<DatabasePermissionFilter>());
builder.Services.AddDbContext<Klcn021HealthBeautyContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));
builder.Services.AddScoped<IPasswordService, PasswordService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<AccountTokenValidation>();
builder.Services.AddScoped<IGoogleIdentityVerifier, GoogleIdentityVerifier>();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<PasswordRecoveryService>();
builder.Services.AddScoped<INotificationService, NotificationService>();
builder.Services.AddNotificationPush(builder.Configuration, builder.Environment);
builder.Services.AddAppointmentReminders(builder.Configuration);
builder.Services.AddCloudinaryImages(builder.Configuration);
builder.Services.AddPasswordRecoveryEmail(builder.Configuration);
builder.Services.AddPasswordRecoveryRateLimiting();
builder.Services.AddMobileAuthenticationRateLimiting();
builder.Services.AddLoginTwoFactor(builder.Configuration);
var jwt = builder.Configuration.GetSection("Jwt");
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer(options =>
{
    options.EventsType = typeof(AccountTokenValidation);
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer = true, ValidIssuer = jwt["Issuer"],
        ValidateAudience = true, ValidAudience = jwt["Audience"],
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
        ValidateLifetime = true, ClockSkew = TimeSpan.FromSeconds(30)
    };
});
builder.Services.AddAuthorization();
if (builder.Environment.IsDevelopment())
    builder.Services.AddCors(options => options.AddPolicy(DevelopmentClientCors.PolicyName, DevelopmentClientCors.Configure));
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

if (app.Environment.IsDevelopment())
    app.UseCors(DevelopmentClientCors.PolicyName);

app.UseRateLimiter();

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
