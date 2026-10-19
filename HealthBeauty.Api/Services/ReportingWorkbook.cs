using System.Globalization;
using System.IO.Compression;
using System.Text;
using System.Xml;

namespace HealthBeauty.Api.Services;

public static class ReportingWorkbook
{
    public const int MaximumRows = 10000;
    private const string Ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
    public static byte[] Create(string sheetName, IReadOnlyList<string> headers, IEnumerable<IReadOnlyList<object?>> rows)
    {
        ArgumentNullException.ThrowIfNull(sheetName);
        ArgumentNullException.ThrowIfNull(headers);
        ArgumentNullException.ThrowIfNull(rows);
        if (sheetName.Length is < 1 or > 31 || sheetName.IndexOfAny("[]:*?/\\".ToCharArray()) >= 0 || sheetName.StartsWith('\'') || sheetName.EndsWith('\'') || Clean(sheetName) != sheetName)
            throw new ArgumentException("Invalid worksheet name.", nameof(sheetName));
        if (headers.Count is < 1 or > 100) throw new ArgumentException("Expected between 1 and 100 columns.", nameof(headers));
        using var buffer = new MemoryStream();
        using (var zip = new ZipArchive(buffer, ZipArchiveMode.Create, true))
        {
            Part(zip, "[Content_Types].xml", w => {
                w.WriteStartElement("Types", "http://schemas.openxmlformats.org/package/2006/content-types");
                Tag(w, "Default", ("Extension", "rels"), ("ContentType", "application/vnd.openxmlformats-package.relationships+xml"));
                Tag(w, "Default", ("Extension", "xml"), ("ContentType", "application/xml"));
                Tag(w, "Override", ("PartName", "/xl/workbook.xml"), ("ContentType", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"));
                Tag(w, "Override", ("PartName", "/xl/worksheets/sheet1.xml"), ("ContentType", "application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"));
                w.WriteEndElement();
            });
            Relations(zip, "_rels/.rels", "officeDocument", "xl/workbook.xml");
            Relations(zip, "xl/_rels/workbook.xml.rels", "worksheet", "worksheets/sheet1.xml");
            Part(zip, "xl/workbook.xml", w => {
                w.WriteStartElement("workbook", Ns); w.WriteStartElement("sheets", Ns); w.WriteStartElement("sheet", Ns);
                w.WriteAttributeString("name", sheetName); w.WriteAttributeString("sheetId", "1");
                w.WriteAttributeString("r", "id", "http://schemas.openxmlformats.org/officeDocument/2006/relationships", "rId1");
                w.WriteEndElement(); w.WriteEndElement(); w.WriteEndElement();
            });
            Part(zip, "xl/worksheets/sheet1.xml", w => {
                w.WriteStartElement("worksheet", Ns); w.WriteStartElement("sheetData", Ns);
                Row(w, headers.Select(h => (object?)h).ToArray());
                var count = 0;
                foreach (var row in rows) {
                    if (++count > MaximumRows) throw new ArgumentException("Report exceeds the maximum row count.", nameof(rows));
                    if (row is null || row.Count != headers.Count) throw new ArgumentException("Row columns do not match headers.", nameof(rows));
                    Row(w, row);
                }
                w.WriteEndElement(); w.WriteEndElement();
            });
        }
        return buffer.ToArray();
    }
    private static void Row(XmlWriter w, IReadOnlyList<object?> cells)
    {
        w.WriteStartElement("row", Ns);
        foreach (var value in cells) {
            w.WriteStartElement("c", Ns);
            if (value is bool boolean) {
                w.WriteAttributeString("t", "b"); w.WriteElementString("v", Ns, boolean ? "1" : "0");
            } else if (value is byte or sbyte or short or ushort or int or uint or long or ulong or decimal || value is float f && float.IsFinite(f) || value is double d && double.IsFinite(d)) {
                w.WriteElementString("v", Ns, ((IFormattable)value).ToString(null, CultureInfo.InvariantCulture));
            } else {
                var text = Clean(value switch {
                    null => "",
                    DateTime date => date.ToString("O", CultureInfo.InvariantCulture),
                    DateTimeOffset date => date.ToString("O", CultureInfo.InvariantCulture),
                    IFormattable formatted => formatted.ToString(null, CultureInfo.InvariantCulture) ?? "",
                    _ => value.ToString() ?? ""
                });
                if (text.Length > 32767) throw new ArgumentException("A cell exceeds 32767 characters.");
                w.WriteAttributeString("t", "inlineStr"); w.WriteStartElement("is", Ns); w.WriteStartElement("t", Ns);
                w.WriteAttributeString("xml", "space", "http://www.w3.org/XML/1998/namespace", "preserve"); w.WriteString(text);
                w.WriteEndElement(); w.WriteEndElement();
            }
            w.WriteEndElement();
        }
        w.WriteEndElement();
    }
    private static string Clean(string value)
    {
        var text = new StringBuilder(value.Length);
        for (var i = 0; i < value.Length; i++) {
            if (char.IsHighSurrogate(value[i]) && i + 1 < value.Length && char.IsLowSurrogate(value[i + 1])) {
                text.Append(value[i]); text.Append(value[++i]);
            } else if (XmlConvert.IsXmlChar(value[i])) text.Append(value[i]);
        }
        return text.ToString();
    }
    private static void Part(ZipArchive zip, string path, Action<XmlWriter> action)
    {
        using var stream = zip.CreateEntry(path, CompressionLevel.Optimal).Open();
        using var writer = XmlWriter.Create(stream, new XmlWriterSettings { Encoding = new UTF8Encoding(false) });
        action(writer);
    }
    private static void Tag(XmlWriter w, string name, params (string Name, string Value)[] attributes)
    {
        w.WriteStartElement(name, name == "Relationship" ? "http://schemas.openxmlformats.org/package/2006/relationships" : "http://schemas.openxmlformats.org/package/2006/content-types");
        foreach (var attr in attributes) w.WriteAttributeString(attr.Name, attr.Value);
        w.WriteEndElement();
    }
    private static void Relations(ZipArchive zip, string path, string type, string target) => Part(zip, path, w => {
        w.WriteStartElement("Relationships", "http://schemas.openxmlformats.org/package/2006/relationships");
        Tag(w, "Relationship", ("Id", "rId1"), ("Type", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/" + type), ("Target", target));
        w.WriteEndElement();
    });
}
