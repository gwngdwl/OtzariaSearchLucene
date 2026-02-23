using Lucene.Net.Analysis;
using Lucene.Net.Documents;
using Lucene.Net.Index;
using Lucene.Net.QueryParsers.Classic;
using Lucene.Net.Search;
using Lucene.Net.Store;
using Lucene.Net.Util;
using OtzariaSearch.Analyzers;
using System.Text.RegularExpressions;

namespace OtzariaSearch.Search;

public sealed class SearchEngine : IDisposable
{
    private const LuceneVersion AppLuceneVersion = LuceneVersion.LUCENE_48;

    private readonly FSDirectory _indexDir;
    private readonly DirectoryReader _reader;
    private readonly IndexSearcher _searcher;
    private readonly Analyzer _analyzer;

    public SearchEngine(string indexPath)
    {
        if (!System.IO.Directory.Exists(indexPath))
            throw new DirectoryNotFoundException($"Index directory not found: {indexPath}");

        _indexDir = FSDirectory.Open(indexPath);
        _reader = DirectoryReader.Open(_indexDir);
        _searcher = new IndexSearcher(_reader);
        _analyzer = new HebrewAnalyzer(AppLuceneVersion);
    }

    public SearchResults Search(string queryText, int limit = 50, string? bookFilter = null, string? categoryFilter = null)
    {
        if (string.IsNullOrWhiteSpace(queryText))
            return new SearchResults([], 0, TimeSpan.Zero);

        var stopwatch = System.Diagnostics.Stopwatch.StartNew();

        // Parse the query
        var parser = new QueryParser(AppLuceneVersion, "content", _analyzer);
        parser.DefaultOperator = Operator.AND;
        
        Query query;
        try
        {
            query = parser.Parse(QueryParserBase.Escape(queryText));
        }
        catch
        {
            // Fallback: escape special characters
            query = parser.Parse(QueryParserBase.Escape(queryText));
        }

        // Apply filters if specified
        if (!string.IsNullOrWhiteSpace(bookFilter) || !string.IsNullOrWhiteSpace(categoryFilter))
        {
            var boolQuery = new BooleanQuery
            {
                { query, Occur.MUST }
            };

            if (!string.IsNullOrWhiteSpace(bookFilter))
            {
                var bookQuery = new TermQuery(new Term("bookTitle", bookFilter));
                boolQuery.Add(bookQuery, Occur.MUST);
            }

            if (!string.IsNullOrWhiteSpace(categoryFilter))
            {
                var categoryQuery = new WildcardQuery(new Term("categoryPath", $"*{categoryFilter}*"));
                boolQuery.Add(categoryQuery, Occur.MUST);
            }

            query = boolQuery;
        }

        var topDocs = _searcher.Search(query, limit);
        var results = new List<SearchResult>();

        foreach (var scoreDoc in topDocs.ScoreDocs)
        {
            var doc = _searcher.Doc(scoreDoc.Doc);

            string content = doc.Get("content") ?? "";
            string snippet = CreateSnippet(content, queryText, 120);

            results.Add(new SearchResult
            {
                LineId = long.Parse(doc.Get("lineId") ?? "0"),
                BookId = long.Parse(doc.Get("bookId") ?? "0"),
                BookTitle = doc.Get("bookTitle") ?? "",
                CategoryPath = doc.Get("categoryPath") ?? "",
                HeRef = doc.Get("heRef") ?? "",
                LineIndex = int.Parse(doc.Get("lineIndex") ?? "0"),
                Content = content,
                Snippet = snippet,
                Score = scoreDoc.Score
            });
        }

        stopwatch.Stop();
        return new SearchResults(results, topDocs.TotalHits, stopwatch.Elapsed);
    }

    /// <summary>
    /// Get total number of documents in the index.
    /// </summary>
    public int TotalDocuments => _reader.NumDocs;

    private static string CreateSnippet(string content, string queryText, int contextChars)
    {
        // Normalize for matching
        string normalizedContent = HebrewTextUtils.RemoveNikud(content);
        string normalizedQuery = HebrewTextUtils.RemoveNikud(queryText);

        // Find the query words in content
        string[] queryWords = normalizedQuery.Split(' ', StringSplitOptions.RemoveEmptyEntries);

        int bestPos = -1;
        foreach (var word in queryWords)
        {
            int pos = normalizedContent.IndexOf(word, StringComparison.OrdinalIgnoreCase);
            if (pos >= 0)
            {
                bestPos = pos;
                break;
            }
        }

        if (bestPos < 0)
        {
            // No match found, just return beginning
            return content.Length <= contextChars * 2
                ? content
                : content[..(contextChars * 2)] + "...";
        }

        // Extract snippet around the match
        int start = Math.Max(0, bestPos - contextChars);
        int end = Math.Min(content.Length, bestPos + contextChars);

        string snippet = content[start..end];

        if (start > 0) snippet = "..." + snippet;
        if (end < content.Length) snippet += "...";

        return snippet;
    }

    public void Dispose()
    {
        _reader?.Dispose();
        _indexDir?.Dispose();
        _analyzer?.Dispose();
    }
}

public record SearchResults(List<SearchResult> Results, int TotalHits, TimeSpan Elapsed);

public class SearchResult
{
    public long LineId { get; set; }
    public long BookId { get; set; }
    public string BookTitle { get; set; } = "";
    public string CategoryPath { get; set; } = "";
    public string HeRef { get; set; } = "";
    public int LineIndex { get; set; }
    public string Content { get; set; } = "";
    public string Snippet { get; set; } = "";
    public float Score { get; set; }
}
