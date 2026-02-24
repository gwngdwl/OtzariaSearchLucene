using System.Text.Json;
using System.Text.Json.Serialization;
using OtzariaSearch.Search;

namespace OtzariaSearch.Bridge;

/// <summary>
/// Bridge service that provides a stable JSON interface between the C# search engine
/// and external clients (e.g., Flutter UI).
/// 
/// This class ensures a fixed, well-defined contract for communication:
/// - Input: search parameters (query, limit, filters)
/// - Output: structured JSON response
/// 
/// All output goes through this class, ensuring the format never changes
/// without updating both sides of the bridge.
/// </summary>
public sealed class BridgeService : IDisposable
{
    private readonly SearchEngine _engine;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = false,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
        Encoder = System.Text.Encodings.Web.JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public BridgeService(string indexPath)
    {
        _engine = new SearchEngine(indexPath);
    }

    /// <summary>
    /// Executes a search and returns the result as a JSON string.
    /// This is the single entry point for all search requests from external clients.
    /// </summary>
    public string Search(string query, int limit = 50, string? book = null, string? category = null)
    {
        try
        {
            var results = _engine.Search(query, limit, book, category);

            var response = new BridgeResponse
            {
                Status = "success",
                Query = query,
                TotalHits = results.TotalHits,
                ElapsedMs = (int)results.Elapsed.TotalMilliseconds,
                Results = results.Results.Select((r, index) => new BridgeResult
                {
                    Rank = index + 1,
                    LineId = r.LineId,
                    BookId = r.BookId,
                    BookTitle = r.BookTitle,
                    CategoryPath = r.CategoryPath,
                    HeRef = r.HeRef,
                    LineIndex = r.LineIndex,
                    Snippet = r.Snippet,
                    Score = r.Score,
                }).ToList(),
            };

            return JsonSerializer.Serialize(response, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new BridgeResponse
            {
                Status = "error",
                Message = ex.Message,
            }, JsonOptions);
        }
    }

    /// <summary>
    /// Returns index info as a JSON string.
    /// </summary>
    public string GetInfo()
    {
        try
        {
            return JsonSerializer.Serialize(new
            {
                status = "success",
                totalDocuments = _engine.TotalDocuments,
            }, JsonOptions);
        }
        catch (Exception ex)
        {
            return JsonSerializer.Serialize(new
            {
                status = "error",
                message = ex.Message,
            }, JsonOptions);
        }
    }

    public void Dispose()
    {
        _engine.Dispose();
    }
}

/// <summary>
/// The JSON response structure returned by the bridge.
/// This contract must remain stable — any changes here require
/// a corresponding update in the Flutter OutputParser.
/// </summary>
public class BridgeResponse
{
    public string Status { get; set; } = "";
    public string? Message { get; set; }
    public string? Query { get; set; }
    public int? TotalHits { get; set; }
    public int? ElapsedMs { get; set; }
    public List<BridgeResult>? Results { get; set; }
}

/// <summary>
/// A single search result in the bridge response.
/// </summary>
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
