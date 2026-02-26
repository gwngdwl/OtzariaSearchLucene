using System.Text.Json;
using System.Text.Json.Serialization;
using OtzariaSearch.Search;

namespace OtzariaSearch.Bridge;

public sealed class BridgeService : IDisposable
{
    private readonly SearchEngine _engine;
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNamingPolicy = JsonNamingPolicy.CamelCase, WriteIndented = false, DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull, Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping };
    public BridgeService(string indexPath) => _engine = new SearchEngine(indexPath);
    private static string Json(object value) => JsonSerializer.Serialize(value, JsonOptions);

    public string Search(string query, int limit = 50, string? book = null, string? category = null, bool wildcard = false)
    {
        try
        {
            var results = _engine.Search(query, limit, book, category, wildcard);
            return Json(new BridgeResponse
            {
                Status = "success",
                Query = query,
                TotalHits = results.TotalHits,
                ElapsedMs = (int)results.Elapsed.TotalMilliseconds,
                Results = results.Results.Select((r, i) => new BridgeResult
                {
                    Rank = i + 1,
                    LineId = r.LineId,
                    BookId = r.BookId,
                    BookTitle = r.BookTitle,
                    CategoryPath = r.CategoryPath,
                    HeRef = r.HeRef,
                    LineIndex = r.LineIndex,
                    Snippet = r.Snippet,
                    Score = r.Score
                }).ToList()
            });
        }
        catch (Exception ex)
        {
            return Json(new BridgeResponse { Status = "error", Message = ex.Message });
        }
    }

    public string GetInfo()
    {
        try
        {
            return Json(new { status = "success", totalDocuments = _engine.TotalDocuments });
        }
        catch (Exception ex)
        {
            return Json(new { status = "error", message = ex.Message });
        }
    }

    public void Dispose() => _engine.Dispose();
}

public class BridgeResponse
{
    public string Status { get; set; } = "";
    public string? Message { get; set; }
    public string? Query { get; set; }
    public int? TotalHits { get; set; }
    public int? ElapsedMs { get; set; }
    public List<BridgeResult>? Results { get; set; }
}

public class BridgeResult
{
    public int Rank { get; set; }
    public long LineId { get; set; }
    public long BookId { get; set; }
    public string BookTitle { get; set; } = "";
    public string CategoryPath { get; set; } = "";
    public string HeRef { get; set; } = "";
    public int LineIndex { get; set; }
    public string Snippet { get; set; } = "";
    public float Score { get; set; }
}
