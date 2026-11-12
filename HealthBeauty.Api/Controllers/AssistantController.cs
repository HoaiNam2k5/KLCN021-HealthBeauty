using System.ComponentModel.DataAnnotations;
using HealthBeauty.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;

namespace HealthBeauty.Api.Controllers;

public sealed record AssistantChatRequest([param: Required, StringLength(1000, MinimumLength = 1)] string Message, List<AssistantTurn>? History = null);

[ApiController, Authorize, Route("api/v1/assistant")]
public sealed class AssistantController(SpaAssistant assistant) : ControllerBase
{
    [HttpPost("chat"), RequestSizeLimit(32768), EnableRateLimiting("spa-assistant")]
    public async Task<IActionResult> Chat(AssistantChatRequest request, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(request.Message) || request.Message.Length > 1000 || request.History?.Count > 6 ||
            (request.History?.Any(t => t is null || t.Role is not ("user" or "assistant") || string.IsNullOrWhiteSpace(t.Text) || t.Text.Length > 500) ?? false)) return BadRequest();
        try { return Ok(await assistant.AskAsync(request.Message.Trim(), request.History ?? [], ct)); }
        catch (AssistantUnavailableException) { return StatusCode(503, new { message = "Trợ lý hiện chưa được cấu hình." }); }
        catch (AssistantTimeoutException) { return StatusCode(504, new { message = "Trợ lý phản hồi chậm. Vui lòng thử lại." }); }
        catch (AssistantProviderException) { return StatusCode(502, new { message = "Trợ lý tạm thời không khả dụng. Vui lòng thử lại." }); }
    }
}
