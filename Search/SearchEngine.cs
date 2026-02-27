using Lucene.Net.Analysis;
using Lucene.Net.Documents;
using Lucene.Net.Index;
using Lucene.Net.QueryParsers.Classic;
using Lucene.Net.Search;
using Lucene.Net.Search.Highlight;
using Lucene.Net.Store;
using Lucene.Net.Util;
using OtzariaSearch.Analyzers;
using System.Text;

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
        if (!System.IO.Directory.Exists(indexPath)) throw new DirectoryNotFoundException($"Index directory not found: {indexPath}");
        _indexDir = FSDirectory.Open(indexPath);
        _reader = DirectoryReader.Open(_indexDir);
        _searcher = new IndexSearcher(_reader);
        _analyzer = new HebrewAnalyzer(AppLuceneVersion);
    }

    public SearchResults Search(string queryText, int limit = 100000, string? bookFilter = null, string? categoryFilter = null, bool wildcard = false)
    {
        if (string.IsNullOrWhiteSpace(queryText))
            return new SearchResults([], 0, TimeSpan.Zero);

        var stopwatch = System.Diagnostics.Stopwatch.StartNew();
        var parser = new QueryParser(AppLuceneVersion, "content", _analyzer)
        {
            DefaultOperator = Operator.AND,
            AllowLeadingWildcard = wildcard
        };
        Query query = parser.Parse(BuildQueryInput(queryText, wildcard));
        if (!string.IsNullOrWhiteSpace(bookFilter) || !string.IsNullOrWhiteSpace(categoryFilter))
        {
            var filtered = new BooleanQuery { { query, Occur.MUST } };
            if (!string.IsNullOrWhiteSpace(bookFilter)) filtered.Add(new TermQuery(new Term("bookTitle", bookFilter)), Occur.MUST);
            if (!string.IsNullOrWhiteSpace(categoryFilter)) filtered.Add(new WildcardQuery(new Term("categoryPath", $"*{categoryFilter}*")), Occur.MUST);
            query = filtered;
        }

        var topDocs = _searcher.Search(query, limit);

        // Set up Lucene Highlighter
        var scorer = new QueryScorer(query, "content");
        var formatter = new SimpleHTMLFormatter("<mark>", "</mark>");
        var highlighter = new Highlighter(formatter, scorer)
        {
            TextFragmenter = new SimpleSpanFragmenter(scorer, 240)
        };

        var results = topDocs.ScoreDocs.Select(scoreDoc =>
        {
            var doc = _searcher.Doc(scoreDoc.Doc);
            var content = doc.Get("content") ?? "";

            // Use Lucene Highlighter for snippet generation
            string snippet;
            try
            {
                var tokenStream = _analyzer.GetTokenStream("content", content);
                var highlighted = highlighter.GetBestFragment(tokenStream, content);
                snippet = highlighted ?? (content.Length <= 240 ? content : content[..240] + "...");
            }
            catch
            {
                snippet = content.Length <= 240 ? content : content[..240] + "...";
            }

            return new SearchResult
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
            };
        }).ToList();

        stopwatch.Stop();
        return new SearchResults(results, topDocs.TotalHits, stopwatch.Elapsed);
    }

    public int TotalDocuments => _reader.NumDocs;

    private static string BuildQueryInput(string queryText, bool wildcard)
    {
        if (!wildcard)
            return QueryParserBase.Escape(queryText);

        var normalizedQuery = HebrewTextUtils.RemoveNikud(queryText);
        ValidateWildcardTerms(normalizedQuery);
        return EscapeLuceneSyntaxExceptWildcards(normalizedQuery);
    }

    private static void ValidateWildcardTerms(string queryText)
    {
        foreach (var term in queryText.Split(' ', StringSplitOptions.RemoveEmptyEntries))
        {
            var hasWildcard = false;
            var hasRegularChars = false;
            var escaped = false;

            foreach (var c in term)
            {
                if (escaped)
                {
                    hasRegularChars = true;
                    escaped = false;
                    continue;
                }

                if (c == '\\')
                {
                    escaped = true;
                    continue;
                }

                if (c is '*' or '?')
                {
                    hasWildcard = true;
                    continue;
                }

                hasRegularChars = true;
            }

            if (escaped)
            {
                hasRegularChars = true;
            }

            if (hasWildcard && !hasRegularChars)
            {
                throw new ArgumentException($"Invalid wildcard term '{term}'. Wildcard terms must include at least one non-wildcard character.");
            }
        }
    }

    private static string EscapeLuceneSyntaxExceptWildcards(string queryText)
    {
        var escaped = new StringBuilder(queryText.Length * 2);

        for (var i = 0; i < queryText.Length; i++)
        {
            var c = queryText[i];
            if (c == '\\')
            {
                if (i + 1 < queryText.Length && (queryText[i + 1] == '*' || queryText[i + 1] == '?'))
                {
                    escaped.Append('\\');
                    escaped.Append(queryText[i + 1]);
                    i++;
                    continue;
                }

                escaped.Append("\\\\");
                continue;
            }

            if (c is '*' or '?')
            {
                escaped.Append(c);
                continue;
            }

            if (IsLuceneSpecial(c))
            {
                escaped.Append('\\');
            }

            escaped.Append(c);
        }

        return escaped.ToString();
    }

    private static bool IsLuceneSpecial(char c) =>
        c is '+' or '-' or '&' or '|' or '!' or '(' or ')' or '{' or '}' or '[' or ']' or '^' or '"' or '~' or ':' or '/';

    public void Dispose() { _reader.Dispose(); _indexDir.Dispose(); _analyzer.Dispose(); }
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
