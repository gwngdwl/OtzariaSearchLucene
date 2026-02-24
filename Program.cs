using System.CommandLine;
using System.CommandLine.Parsing;
using OtzariaSearch.Bridge;
using OtzariaSearch.Indexing;

// Configure console for Hebrew/UTF-8 output
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

    using var bridge = new BridgeService(indexPath);
    string json = bridge.Search(query, limit, book, category);
    Console.WriteLine(json);
});

// ── INFO COMMAND ───────────────────────────────────────────────────
var infoCommand = new Command("info", "Show information about the search index");
infoCommand.Add(infoIndexOption);
infoCommand.SetAction((parseResult) =>
{
    string indexPath = parseResult.GetValue(infoIndexOption)!;
    using var bridge = new BridgeService(indexPath);
    string json = bridge.GetInfo();
    Console.WriteLine(json);
});

// ── ROOT COMMAND ───────────────────────────────────────────────────
var rootCommand = new RootCommand("OtzariaSearch - Lucene search engine for the Otzaria book library");
rootCommand.Add(indexCommand);
rootCommand.Add(searchCommand);
rootCommand.Add(infoCommand);

var config = new CommandLineConfiguration(rootCommand);
return await config.InvokeAsync(args);
