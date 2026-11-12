using System.Diagnostics;
using System.Net.Http;
using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using OpenQA.Selenium.Support.UI;
using Xunit;

namespace HealthBeauty.Selenium.Tests;

public sealed class LocalFixture : IDisposable
{
    private readonly Process server;
    public string BaseUrl { get; }
    public LocalFixture()
    {
        var dir = new DirectoryInfo(AppContext.BaseDirectory);
        while (dir != null && !File.Exists(Path.Combine(dir.FullName, "KLCN021_HealthBeauty.sln"))) dir = dir.Parent;
        if (dir == null) throw new InvalidOperationException("Không tìm thấy thư mục dự án HealthBeauty.");
        var script = Path.Combine(dir.FullName, "HealthBeauty.Selenium.Tests", "mock-server.mjs");
        var dist = Path.Combine(dir.FullName, "HealthBeauty.Web", "dist");
        if (!File.Exists(Path.Combine(dist, "index.html"))) throw new InvalidOperationException("Chạy npm run build trong HealthBeauty.Web trước khi kiểm thử.");
        var start = new ProcessStartInfo("node") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        start.ArgumentList.Add(script); start.ArgumentList.Add(dist);
        server = Process.Start(start) ?? throw new InvalidOperationException("Không khởi động được Node fixture.");
        var line = server.StandardOutput.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(15)).GetAwaiter().GetResult();
        if (line is null || !line.StartsWith("READY ") || !int.TryParse(line[6..], out var port)) throw new InvalidOperationException("Fixture cục bộ không sẵn sàng.");
        BaseUrl = $"http://127.0.0.1:{port}";
    }
    public void Reset() { using var client = new HttpClient(); client.GetStringAsync(BaseUrl + "/__fixture/reset").GetAwaiter().GetResult(); }
    public void Dispose() { if (!server.HasExited) server.Kill(entireProcessTree: true); server.Dispose(); }
}

public sealed class WebUiTests : IClassFixture<LocalFixture>, IDisposable
{
    private readonly LocalFixture fixture;
    private readonly ChromeDriver browser;
    private readonly WebDriverWait wait;
    public WebUiTests(LocalFixture fixture)
    {
        this.fixture = fixture;
        fixture.Reset();
        var options = new ChromeOptions();
        options.AddArguments("--headless=new", "--disable-gpu", "--no-sandbox", "--window-size=1366,1000", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1");
        var binary = Environment.GetEnvironmentVariable("HEALTHBEAUTY_SELENIUM_CHROME");
        var localChromium = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ms-playwright", "chromium-1223", "chrome-win64", "chrome.exe");
        if (string.IsNullOrWhiteSpace(binary) && File.Exists(localChromium)) binary = localChromium;
        if (!string.IsNullOrWhiteSpace(binary)) options.BinaryLocation = binary;
        browser = new ChromeDriver(options);
        wait = new WebDriverWait(browser, TimeSpan.FromSeconds(15));
    }
    private IWebElement Find(By selector) => wait.Until(d => { var e = d.FindElements(selector).FirstOrDefault(x => x.Displayed); return e!; });
    private void Open(string path) => browser.Navigate().GoToUrl(fixture.BaseUrl + path);
    private void Login()
    {
        Open("/login");
        Find(By.CssSelector("input[autocomplete='username']")).SendKeys("fixture@example.test");
        Find(By.CssSelector("input[autocomplete='current-password']")).SendKeys("FixtureOnly123!");
        Find(By.CssSelector("button[type='submit']")).Click();
        wait.Until(d => !d.Url.Contains("/login", StringComparison.OrdinalIgnoreCase));
    }
    [Fact]
    public void LoginForm_RejectsEmptyFields()
    {
        Open("/login");
        Find(By.CssSelector("button[type='submit']")).Click();
        wait.Until(d => d.FindElement(By.TagName("body")).Text.Contains("Vui lòng nhập email", StringComparison.Ordinal));
        Assert.Contains("Vui lòng nhập mật khẩu", Find(By.TagName("body")).Text);
    }
    [Fact]
    public void Login_InvalidCredentials_ShowsError()
    {
        Open("/login");
        Find(By.CssSelector("input[autocomplete='username']")).SendKeys("fixture@example.test");
        Find(By.CssSelector("input[autocomplete='current-password']")).SendKeys("wrong-password");
        Find(By.CssSelector("button[type='submit']")).Click();
        Assert.Contains("không chính xác", Find(By.CssSelector(".login-alert")).Text, StringComparison.OrdinalIgnoreCase);
    }
    [Fact]
    public void ProtectedAppointments_WithoutSession_RedirectsToLogin()
    {
        Open("/appointments");
        wait.Until(d => d.Url.Contains("/login", StringComparison.OrdinalIgnoreCase));
        Assert.True(Find(By.CssSelector("input[autocomplete='username']")).Displayed);
    }
    [Fact]
    public void Reception_CanViewAppointmentAndCustomerName()
    {
        Login(); Open("/appointments");
        Assert.Contains("Khách hàng Selenium", Find(By.CssSelector(".appointments-management")).Text);
        Assert.True(Find(By.XPath("//button[.//span[normalize-space()='Xác nhận lịch']]")).Displayed);
    }
    [Fact]
    public async Task Reception_CanConfirmAppointment_InLocalFixture()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[.//span[normalize-space()='Xác nhận lịch']]")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Xác nhận']]")).Click();
        Assert.True(Find(By.XPath("//button[.//span[normalize-space()='Bắt đầu dịch vụ']]")).Displayed);
        using var client = new HttpClient();
        var state = await client.GetStringAsync(fixture.BaseUrl + "/__fixture/state");
        Assert.Contains("DaXacNhan", state);
    }
    [Fact]
    public void Reception_CanViewServices()
    {
        Login(); Open("/services");
        Assert.Contains("Chăm sóc da Selenium", Find(By.CssSelector(".ant-table")).Text);
    }
    [Fact]
    public void Reception_ServiceSearch_FiltersAndRestoresResults()
    {
        Login(); Open("/services");
        Find(By.CssSelector(".ant-table"));
        var search = Find(By.CssSelector(".table-search input"));
        search.SendKeys("not-matching-fixture");
        wait.Until(d => !d.FindElement(By.CssSelector(".ant-table")).Text.Contains("Chăm sóc da Selenium", StringComparison.Ordinal));
        search.SendKeys(Keys.Control + "a");
        search.SendKeys(Keys.Backspace);
        wait.Until(d => d.FindElement(By.CssSelector(".ant-table")).Text.Contains("Chăm sóc da Selenium", StringComparison.Ordinal));
    }
    [Fact]
    public void AUTH03_LoginWithFixtureAccount_OpensManagement()
    {
        Login();
        Assert.DoesNotContain("/login", browser.Url, StringComparison.OrdinalIgnoreCase);
        Assert.NotNull(((IJavaScriptExecutor)browser).ExecuteScript("return localStorage.getItem('healthbeauty.refreshToken')"));
    }
    [Fact]
    public async Task DESK03_ConfirmThenRecordCustomerArrival()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[.//span[normalize-space()='Xác nhận lịch']]")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Xác nhận']]")).Click();
        Find(By.XPath("//button[@aria-label='Thao tác khác cho lịch #901']")).Click();
        Find(By.XPath("//*[@role='menuitem' and normalize-space()='Khách đã đến']")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Xác nhận']]")).Click();
        using var client = new HttpClient();
        var state = await client.GetStringAsync(fixture.BaseUrl + "/__fixture/state");
        Assert.Contains("DaDen", state);
    }
    [Fact]
    public void AUTH06_LogoutClearsSessionAndProtectsAppointments()
    {
        Login();
        Find(By.CssSelector("button.account-menu")).Click();
        Find(By.XPath("//*[@role='menuitem' and contains(., 'Đăng xuất')]")).Click();
        wait.Until(d => d.Url.Contains("/login", StringComparison.OrdinalIgnoreCase));
        Assert.Null(((IJavaScriptExecutor)browser).ExecuteScript("return localStorage.getItem('healthbeauty.refreshToken')"));
        Open("/appointments");
        wait.Until(d => d.Url.Contains("/login", StringComparison.OrdinalIgnoreCase));
    }
    [Fact]
    public void AUTH05_ReceptionWithoutAccountPermission_SeesForbiddenPage()
    {
        Login(); Open("/accounts");
        wait.Until(d => d.Url.Contains("/403", StringComparison.OrdinalIgnoreCase));
        Assert.Contains("không có quyền", Find(By.TagName("body")).Text, StringComparison.OrdinalIgnoreCase);
    }
    [Fact]
    public void DESK06_UnconfirmedAppointment_DoesNotOfferLaterTransitions()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[.//span[normalize-space()='Xác nhận lịch']]"));
        Assert.Empty(browser.FindElements(By.XPath("//button[.//span[normalize-space()='Bắt đầu dịch vụ']]")));
        Assert.Empty(browser.FindElements(By.XPath("//button[.//span[normalize-space()='Hoàn thành dịch vụ']]")));
    }
    [Fact]
    public void DESK01_AppointmentDetailsDisplayCustomerAndService()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[.//span[normalize-space()='Xem chi tiết']]")).Click();
        var drawer = wait.Until(d => d.FindElements(By.CssSelector(".ant-drawer-body"))
            .FirstOrDefault(e => e.Displayed && e.Text.Contains("Khách hàng Selenium", StringComparison.Ordinal)
                && e.Text.Contains("Chăm sóc da Selenium", StringComparison.Ordinal))!);
        Assert.Contains("Khách hàng Selenium", drawer.Text);
        Assert.Contains("Chăm sóc da Selenium", drawer.Text);
    }
    [Fact]
    public async Task DESK06_CancellationRequiresReasonAndDoesNotChangeState()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[@aria-label='Thao tác khác cho lịch #901']")).Click();
        Find(By.XPath("//*[@role='menuitem' and normalize-space()='Hủy lịch']")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Hủy lịch hẹn']]")).Click();
        wait.Until(d => d.FindElement(By.CssSelector(".ant-modal-body")).Text.Contains("Vui lòng nhập lý do hủy", StringComparison.Ordinal));
        using var client = new HttpClient();
        var state = await client.GetStringAsync(fixture.BaseUrl + "/__fixture/state");
        Assert.Contains("ChoXacNhan", state);
    }
    [Fact]
    public void LoginForm_RejectsMalformedEmail()
    {
        Open("/login");
        Find(By.CssSelector("input[autocomplete='username']")).SendKeys("not-an-email");
        Find(By.CssSelector("input[autocomplete='current-password']")).SendKeys("FixtureOnly123!");
        Find(By.CssSelector("button[type='submit']")).Click();
        wait.Until(d => d.FindElement(By.TagName("body")).Text.Contains("Email không hợp lệ", StringComparison.Ordinal));
        Assert.Contains("/login", browser.Url, StringComparison.OrdinalIgnoreCase);
    }
    [Fact]
    public async Task DESK04_And_DESK05_TransitionInFixture()
    {
        Login(); Open("/appointments");
        Find(By.XPath("//button[.//span[normalize-space()='Xác nhận lịch']]")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Xác nhận']]")).Click();
        Find(By.XPath("//button[.//span[normalize-space()='Bắt đầu dịch vụ']]")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Xác nhận']]")).Click();
        using var client = new HttpClient();
        var started = await client.GetStringAsync(fixture.BaseUrl + "/__fixture/state");
        Assert.Contains("DangThucHien", started);
        Find(By.XPath("//button[.//span[normalize-space()='Hoàn thành dịch vụ']]")).Click();
        Find(By.XPath("//*[@role='dialog']//button[.//span[normalize-space()='Hoàn thành và lập hóa đơn']]")).Click();
        Find(By.XPath("//button[.//span[normalize-space()='Xem hóa đơn']]"));
        var completed = await client.GetStringAsync(fixture.BaseUrl + "/__fixture/state");
        Assert.Contains("HoanThanh", completed);
    }
    public void Dispose() => browser.Quit();
}
