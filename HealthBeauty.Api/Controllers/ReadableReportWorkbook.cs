using System.IO.Compression;
using System.Xml.Linq;

namespace HealthBeauty.Api.Services;

public static class ReadableReportWorkbook
{
    public static byte[] Create(IReadOnlyList<string> headers, IEnumerable<IReadOnlyList<object?>> rows)
    {
        var original = ReportingWorkbook.Create("Doanh thu", headers, rows);
        using var output = new MemoryStream();
        output.Write(original);
        using (var zip = new ZipArchive(output, ZipArchiveMode.Update, leaveOpen: true))
        {
            var entry = zip.GetEntry("xl/worksheets/sheet1.xml")!;
            XDocument sheet;
            using (var input = entry.Open()) sheet = XDocument.Load(input);
            XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
            var columns = new XElement(ns + "cols", Enumerable.Range(1, headers.Count).Select(index =>
                new XElement(ns + "col", new XAttribute("min", index), new XAttribute("max", index),
                    new XAttribute("width", index == 1 ? 38 : index == 2 ? 36 : 24), new XAttribute("customWidth", 1))));
            sheet.Root!.Element(ns + "sheetData")!.AddBeforeSelf(columns);
            entry.Delete();
            using var stream = zip.CreateEntry("xl/worksheets/sheet1.xml").Open();
            sheet.Save(stream);
        }
        return output.ToArray();
    }
}
