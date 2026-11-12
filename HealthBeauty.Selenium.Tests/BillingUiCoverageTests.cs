using System.Diagnostics;
using System.Text.Json;
using OpenQA.Selenium;
using OpenQA.Selenium.Chrome;
using OpenQA.Selenium.Support.UI;
using Xunit;

namespace HealthBeauty.Selenium.Tests;

public sealed class BillingFixture : IDisposable
{
    private readonly Process server;
    public string BaseUrl { get; }
    public BillingFixture()
    {
        var root = new DirectoryInfo(AppContext.BaseDirectory);
        while (root != null && !File.Exists(Path.Combine(root.FullName, "KLCN021_HealthBeauty.sln"))) root = root.Parent;
        if (root == null) throw new InvalidOperationException("Missing project root");
        var start = new ProcessStartInfo("node") { UseShellExecute = false, RedirectStandardOutput = true, RedirectStandardError = true, CreateNoWindow = true };
        start.ArgumentList.Add(Path.Combine(root.FullName, "HealthBeauty.Selenium.Tests", "billing-fixture.mjs"));
        start.ArgumentList.Add(Path.Combine(root.FullName, "HealthBeauty.Web", "dist"));
        server = Process.Start(start) ?? throw new InvalidOperationException("Fixture did not start");
        var ready = server.StandardOutput.ReadLineAsync().WaitAsync(TimeSpan.FromSeconds(15)).GetAwaiter().GetResult();
        if (ready == null || !ready.StartsWith("READY ")) throw new InvalidOperationException("Fixture not ready");
        BaseUrl = "http://127.0.0.1:" + int.Parse(ready[6..]);
    }
    public void Command(string path) { using var c = new HttpClient(); c.GetStringAsync(BaseUrl + "/__fixture/" + path).GetAwaiter().GetResult(); }
    public void Dispose() { if (!server.HasExited) server.Kill(true); server.Dispose(); }
}

public sealed class BillingUiCoverageTests : IClassFixture<BillingFixture>, IDisposable
{
    private readonly BillingFixture fixture;
    private readonly ChromeDriver browser;
    private readonly WebDriverWait wait;
    public BillingUiCoverageTests(BillingFixture fixture)
    {
        this.fixture = fixture;
        fixture.Command("reset");
        var options = new ChromeOptions();
        options.AddArguments("--headless=new", "--disable-gpu", "--no-sandbox", "--window-size=1366,1000", "--host-resolver-rules=MAP * ~NOTFOUND, EXCLUDE 127.0.0.1");
        var binary = Environment.GetEnvironmentVariable("HEALTHBEAUTY_SELENIUM_CHROME") ?? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "ms-playwright", "chromium-1223", "chrome-win64", "chrome.exe");
        options.BinaryLocation = binary;
        browser = new ChromeDriver(options);
        wait = new WebDriverWait(browser, TimeSpan.FromSeconds(15));
    }
    private IWebElement Find(By by) => wait.Until(d => d.FindElements(by).FirstOrDefault(e => e.Displayed)!);
    private void LoginAndOpen(string path)
    {
        browser.Navigate().GoToUrl(fixture.BaseUrl + "/login");
        Find(By.CssSelector("input[autocomplete='username']")).SendKeys("billing@example.test");
        Find(By.CssSelector("input[autocomplete='current-password']")).SendKeys("FixtureOnly123!");
        Find(By.CssSelector("button[type='submit']")).Click();
        wait.Until(d => !d.Url.Contains("/login"));
        browser.Navigate().GoToUrl(fixture.BaseUrl + path);
    }
    private IWebElement ContentContaining(string text) => wait.Until(d => d.FindElements(By.CssSelector(".ant-modal-body, .ant-drawer-body"))
        .FirstOrDefault(e => e.Displayed && e.Text.Contains(text, StringComparison.Ordinal))!);

    [Fact]
    public void PAY01_UnpaidInvoiceShowsCustomerServiceAmountAndStatus()
    {
        LoginAndOpen("/billing");
        var row = Find(By.CssSelector("tr[data-row-key='801']"));
        Assert.Contains("Khách hàng hóa đơn kiểm thử", row.Text);
        Assert.Contains("300.000", row.Text);
        Assert.Contains("Chờ thanh toán", row.Text);
        row.Click();
        var detail = ContentContaining("Chăm sóc da kiểm thử hóa đơn");
        Assert.Contains("Khách hàng hóa đơn kiểm thử", detail.Text);
        Assert.Contains("300.000", detail.Text);
    }

    [Fact]
    public void PAY02_TransferInstructionsMatchUnpaidInvoice()
    {
        LoginAndOpen("/billing?invoiceId=801&collect=1");
        var modal = ContentContaining("HB801");
        Assert.Contains("000111222", modal.Text);
        Assert.Contains("TAI KHOAN GIA LAP", modal.Text);
        Assert.Contains("300.000", modal.Text);
        var qr = Find(By.CssSelector("img[alt='VietQR SePay']"));
        Assert.Contains("amount=300000", qr.GetAttribute("src"));
        Assert.Contains("des=HB801", qr.GetAttribute("src"));
    }

    [Fact]
    public void PAY07_ExternalPaidSnapshotUpdatesModalListAndPaymentMethod()
    {
        LoginAndOpen("/billing?invoiceId=801&collect=1");
        ContentContaining("HB801");
        fixture.Command("paid"); // Simulates a server response change, not a real webhook/payment.
        ContentContaining("Hóa đơn đã được thanh toán");
        Assert.Empty(browser.FindElements(By.CssSelector("img[alt='VietQR SePay']")).Where(e => e.Displayed));
        Find(By.XPath("//button[.//span[normalize-space()='Đóng cửa sổ']]")).Click();
        var paidRow = wait.Until(d => d.FindElements(By.CssSelector("tr[data-row-key='801']"))
            .FirstOrDefault(e => e.Displayed && e.Text.Contains("Đã thanh toán") && e.Text.Contains("Chuyển khoản"))!);
        Assert.DoesNotContain("Quét QR", paidRow.Text);
        Assert.Contains("300.000", paidRow.Text);
    }

    [Fact]
    public void PAY02_MismatchedTransferAmountDoesNotDisplayQr()
    {
        fixture.Command("mismatch");
        LoginAndOpen("/billing?invoiceId=801&collect=1");
        ContentContaining("Hóa đơn hoặc số tiền đã thay đổi");
        Assert.Empty(browser.FindElements(By.CssSelector("img[alt='VietQR SePay']")).Where(e => e.Displayed));
    }
    public void Dispose() => browser.Quit();
}
