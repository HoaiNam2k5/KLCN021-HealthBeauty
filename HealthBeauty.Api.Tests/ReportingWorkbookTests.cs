using System.Globalization;
using System.IO.Compression;
using System.Xml.Linq;
using HealthBeauty.Api.Services;
using Xunit;

namespace HealthBeauty.Api.Tests;

public class ReportingWorkbookTests
{
    private static readonly XNamespace Ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    private static XDocument Sheet(byte[] bytes)
    {
        using var zip = new ZipArchive(new MemoryStream(bytes));
        using var stream = zip.GetEntry("xl/worksheets/sheet1.xml")!.Open();
        return XDocument.Load(stream);
    }
    [Fact]
    public void RoundTripPreservesUnicodeAndEscapesTextWithoutFormulaExecution()
    {
        var text = " Đánh giá & <tốt> 😀\u0001\ud800 ";
        var doc = Sheet(ReportingWorkbook.Create("Báo cáo", new[] { "Tên", "Ghi chú" }, new[] { new object?[] { text, "=HYPERLINK(\"https://example.org\")" } }));
        var cells = doc.Descendants(Ns + "c").Skip(2).ToArray();
        Assert.Equal(" Đánh giá & <tốt> 😀 ", cells[0].Descendants(Ns + "t").Single().Value);
        Assert.Equal("inlineStr", cells[1].Attribute("t")!.Value);
        Assert.StartsWith("=HYPERLINK", cells[1].Value);
        Assert.Empty(doc.Descendants(Ns + "f"));
    }
    [Fact]
    public void NumericBooleanAndDatesRemainTypedRegardlessOfCulture()
    {
        var original = CultureInfo.CurrentCulture;
        try {
            CultureInfo.CurrentCulture = CultureInfo.GetCultureInfo("vi-VN");
            var date = new DateTime(2026, 10, 18, 0, 0, 0, DateTimeKind.Utc);
            var offset = new DateTimeOffset(2026, 10, 18, 7, 0, 0, TimeSpan.FromHours(7));
            var doc = Sheet(ReportingWorkbook.Create("Data", new[] { "A", "B", "C", "D", "E", "F" }, new[] { new object?[] { 12.5m, true, date, offset, double.NaN, null } }));
            var cells = doc.Descendants(Ns + "row").Last().Elements().ToArray();
            Assert.Equal("12.5", cells[0].Value); Assert.Null(cells[0].Attribute("t"));
            Assert.Equal("b", cells[1].Attribute("t")!.Value); Assert.Equal("1", cells[1].Value);
            Assert.Equal(date.ToString("O"), cells[2].Value); Assert.EndsWith("+07:00", cells[3].Value);
            Assert.Equal("inlineStr", cells[4].Attribute("t")!.Value); Assert.Equal("NaN", cells[4].Value);
            Assert.Equal("", cells[5].Value);
        } finally { CultureInfo.CurrentCulture = original; }
    }
    [Theory]
    [InlineData("")]
    [InlineData("bad/name")]
    [InlineData("bad\\name")]
    [InlineData("'name")]
    [InlineData("name'")]
    [InlineData("12345678901234567890123456789012")]
    public void RejectsInvalidSheetNames(string name) => Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create(name, new[] { "A" }, Array.Empty<IReadOnlyList<object?>>()));
    [Fact]
    public void RejectsInvalidHeaderAndRowCounts()
    {
        Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create("A", Array.Empty<string>(), Array.Empty<IReadOnlyList<object?>>()));
        Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create("A", Enumerable.Repeat("x", 101).ToArray(), Array.Empty<IReadOnlyList<object?>>()));
        Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create("A", new[] { "x" }, new[] { Array.Empty<object?>() }));
        Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create("A", new[] { "x" }, Enumerable.Repeat<IReadOnlyList<object?>>(new object?[] { 1 }, ReportingWorkbook.MaximumRows + 1)));
    }
    [Fact]
    public void RejectsLongCellsButAcceptsExactLimit()
    {
        var value = new string('x', 32767);
        Assert.Equal(value, Sheet(ReportingWorkbook.Create("A", new[] { "x" }, new[] { new object?[] { value } })).Descendants(Ns + "t").Last().Value);
        Assert.Throws<ArgumentException>(() => ReportingWorkbook.Create("A", new[] { "x" }, new[] { new object?[] { value + "x" } }));
    }
    [Fact]
    public void PackageRelationshipsAndContentTypesUseCorrectNamespaces()
    {
        using var zip = new ZipArchive(new MemoryStream(ReportingWorkbook.Create("A", new[] { "x" }, Array.Empty<IReadOnlyList<object?>>() )));
        Assert.Equal(5, zip.Entries.Count);
        foreach (var path in new[] { "_rels/.rels", "xl/_rels/workbook.xml.rels", "[Content_Types].xml" }) {
            using var stream = zip.GetEntry(path)!.Open(); var root = XDocument.Load(stream).Root!;
            Assert.All(root.Elements(), child => Assert.Equal(root.Name.Namespace, child.Name.Namespace));
        }
    }
}
