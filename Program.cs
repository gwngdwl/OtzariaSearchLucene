using System.CommandLine;
using System.CommandLine.Parsing;
using OtzariaSearch.Analyzers;
using OtzariaSearch.Indexing;
using OtzariaSearch.Search;

// Configure console for Hebrew output
Console.OutputEncoding = System.Text.Encoding.UTF8;
Console.InputEncoding = System.Text.Encoding.UTF8;

// ── OPTIONS & ARGUMENTS ────────────────────────────────────────────

// Index command options
var dbOption = new Option<string>("--db") { Required = true, Description = "Path to seforim.db database file" };
var outputOption = new Option<string>("--output") { Description = "Output directory for the search index" };
outputOption.DefaultValueFactory = _ => "./search_index";

// Search command options
var queryArgument = new Argument<string>("query") { Description = "Search query text" };
var indexOption = new Option<string>("--index") { Description = "Path to the search index directory" };
indexOption.DefaultValueFactory = _ => "./search_index";
var limitOption = new Option<int>("--limit") { Description = "Maximum number of results to return" };
limitOption.DefaultValueFactory = _ => 50;
var bookOption = new Option<string?>("--book") { Description = "Filter results by exact book title" };
var categoryOption = new Option<string?>("--category") { Description = "Filter results by category (partial match)" };

// Info command options
var infoIndexOption = new Option<string>("--index") { Description = "Path to the search index directory" };
infoIndexOption.DefaultValueFactory = _ => "./search_index";

// ── INDEX COMMAND ──────────────────────────────────────────────────
var indexCommand = new Command("index", "Build search index from the database");
indexCommand.Add(dbOption);
indexCommand.Add(outputOption);
indexCommand.SetAction((parseResult) =>
{
    string db = parseResult.GetValue(dbOption)!;
    string output = parseResult.GetValue(outputOption)!;

    Console.WriteLine("╔══════════════════════════════════════════╗");
    Console.WriteLine("║     OtzariaSearch - Index Builder        ║");
    Console.WriteLine("╚══════════════════════════════════════════╝");
    Console.WriteLine();
    Console.WriteLine($"  Database: {db}");
    Console.WriteLine($"  Output:   {output}");
    Console.WriteLine();

    var builder = new IndexBuilder(db, output);
    builder.Build();
});

// ── SEARCH COMMAND ─────────────────────────────────────────────────
var searchCommand = new Command("search", "Search the indexed library");
searchCommand.Add(queryArgument);
searchCommand.Add(indexOption);
searchCommand.Add(limitOption);
searchCommand.Add(bookOption);
searchCommand.Add(categoryOption);
searchCommand.SetAction((parseResult) =>
{
    string query = parseResult.GetValue(queryArgument)!;
    string indexPath = parseResult.GetValue(indexOption)!;
    int limit = parseResult.GetValue(limitOption);
    string? book = parseResult.GetValue(bookOption);
    string? category = parseResult.GetValue(categoryOption);

    try
    {
        using var engine = new SearchEngine(indexPath);

        Console.WriteLine();
        Console.ForegroundColor = ConsoleColor.Cyan;
        Console.Write("  Searching: ");
        Console.ResetColor();
        Console.WriteLine($"\"{query}\"");

        if (!string.IsNullOrWhiteSpace(book))
        {
            Console.ForegroundColor = ConsoleColor.DarkYellow;
            Console.Write("  Book:      ");
            Console.ResetColor();
            Console.WriteLine(book);
        }
        if (!string.IsNullOrWhiteSpace(category))
        {
            Console.ForegroundColor = ConsoleColor.DarkYellow;
            Console.Write("  Category:  ");
            Console.ResetColor();
            Console.WriteLine(category);
        }

        Console.WriteLine();

        var results = engine.Search(query, limit, book, category);

        // Header
        Console.ForegroundColor = ConsoleColor.Green;
        Console.Write($"  {results.TotalHits:N0} results found");
        Console.ResetColor();
        Console.WriteLine($" ({results.Elapsed.TotalMilliseconds:F0}ms)");
        Console.WriteLine($"  Showing top {Math.Min(results.Results.Count, limit)} results:");
        Console.WriteLine();
        Console.WriteLine("  " + new string('─', 70));

        int rank = 0;
        foreach (var result in results.Results)
        {
            rank++;

            // Rank + Book title
            Console.ForegroundColor = ConsoleColor.Yellow;
            Console.Write($"  [{rank}] ");
            Console.ForegroundColor = ConsoleColor.White;
            Console.Write(result.BookTitle);
            Console.ResetColor();

            // HeRef
            if (!string.IsNullOrWhiteSpace(result.HeRef))
            {
                Console.ForegroundColor = ConsoleColor.DarkGray;
                Console.Write($" | {result.HeRef}");
                Console.ResetColor();
            }

            Console.WriteLine();

            // Category
            if (!string.IsNullOrWhiteSpace(result.CategoryPath))
            {
                Console.ForegroundColor = ConsoleColor.DarkCyan;
                Console.Write($"      [{result.CategoryPath}]");
                Console.ResetColor();
                Console.WriteLine();
            }

            // Snippet with highlighted query
            Console.Write("      ");
            WriteHighlightedSnippet(result.Snippet, query);
            Console.WriteLine();

            // Score
            Console.ForegroundColor = ConsoleColor.DarkGray;
            Console.WriteLine($"      Score: {result.Score:F4}");
            Console.ResetColor();

            Console.WriteLine("  " + new string('─', 70));
        }

        if (results.TotalHits > limit)
        {
            Console.ForegroundColor = ConsoleColor.DarkYellow;
            Console.WriteLine($"  ... and {results.TotalHits - limit:N0} more results. Use --limit to see more.");
            Console.ResetColor();
        }

        Console.WriteLine();
    }
    catch (DirectoryNotFoundException ex)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.Error.WriteLine($"  Error: {ex.Message}");
        Console.Error.WriteLine("  Please run 'index' command first to build the search index.");
        Console.ResetColor();
    }
});

// ── INFO COMMAND ───────────────────────────────────────────────────
var infoCommand = new Command("info", "Show information about the search index");
infoCommand.Add(infoIndexOption);
infoCommand.SetAction((parseResult) =>
{
    string indexPath = parseResult.GetValue(infoIndexOption)!;
    try
    {
        using var engine = new SearchEngine(indexPath);
        Console.WriteLine();
        Console.WriteLine($"  Index path: {Path.GetFullPath(indexPath)}");
        Console.WriteLine($"  Total documents: {engine.TotalDocuments:N0}");
        Console.WriteLine();
    }
    catch (DirectoryNotFoundException ex)
    {
        Console.ForegroundColor = ConsoleColor.Red;
        Console.Error.WriteLine($"  Error: {ex.Message}");
        Console.ResetColor();
    }
});

// ── ROOT COMMAND ───────────────────────────────────────────────────
var rootCommand = new RootCommand("OtzariaSearch - Lucene search engine for the Otzaria book library");
rootCommand.Add(indexCommand);
rootCommand.Add(searchCommand);
rootCommand.Add(infoCommand);

var config = new CommandLineConfiguration(rootCommand);
return await config.InvokeAsync(args);

// ── Helper methods ─────────────────────────────────────────────────
static void WriteHighlightedSnippet(string snippet, string query)
{
    // Normalize for matching
    string normalizedSnippet = HebrewTextUtils.RemoveNikud(snippet);
    string normalizedQuery = HebrewTextUtils.RemoveNikud(query);
    string[] queryWords = normalizedQuery.Split(' ', StringSplitOptions.RemoveEmptyEntries);

    // Find all positions of query words in the normalized text
    var highlights = new List<(int Start, int End)>();
    foreach (var word in queryWords)
    {
        int pos = 0;
        while ((pos = normalizedSnippet.IndexOf(word, pos, StringComparison.OrdinalIgnoreCase)) >= 0)
        {
            highlights.Add((pos, pos + word.Length));
            pos += word.Length;
        }
    }

    if (highlights.Count == 0)
    {
        Console.Write(snippet);
        return;
    }

    // Sort highlights and merge overlapping ones
    highlights.Sort((a, b) => a.Start.CompareTo(b.Start));
    var merged = new List<(int Start, int End)> { highlights[0] };
    for (int i = 1; i < highlights.Count; i++)
    {
        var last = merged[^1];
        if (highlights[i].Start <= last.End)
            merged[^1] = (last.Start, Math.Max(last.End, highlights[i].End));
        else
            merged.Add(highlights[i]);
    }

    // Write with highlights
    int current = 0;
    foreach (var (start, end) in merged)
    {
        // Write normal text before highlight
        if (current < start)
            Console.Write(snippet[current..Math.Min(start, snippet.Length)]);

        // Write highlighted text
        if (start < snippet.Length)
        {
            Console.ForegroundColor = ConsoleColor.Black;
            Console.BackgroundColor = ConsoleColor.Yellow;
            Console.Write(snippet[start..Math.Min(end, snippet.Length)]);
            Console.ResetColor();
        }

        current = Math.Min(end, snippet.Length);
    }

    // Write remaining text
    if (current < snippet.Length)
        Console.Write(snippet[current..]);
}
