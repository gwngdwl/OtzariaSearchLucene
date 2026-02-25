using System.CommandLine;
using System.CommandLine.Parsing;
using OtzariaSearch.Bridge;
using OtzariaSearch.Indexing;

Console.OutputEncoding = Console.InputEncoding = System.Text.Encoding.UTF8;
static Option<string> StringOpt(string name, string description, string? defaultValue = null, bool required = false) { var option = new Option<string>(name) { Description = description, Required = required }; if (defaultValue is not null) option.DefaultValueFactory = _ => defaultValue; return option; }
static Option<int> IntOpt(string name, string description, int defaultValue) { var option = new Option<int>(name) { Description = description }; option.DefaultValueFactory = _ => defaultValue; return option; }
static Command Cmd(string name, string description, Action<ParseResult> action, params object[] symbols) { var command = new Command(name, description); foreach (var symbol in symbols) if (symbol is Option option) command.Add(option); else if (symbol is Argument argument) command.Add(argument); command.SetAction(action); return command; }

var dbOption = StringOpt("--db", "Path to seforim.db database file", required: true);
var outputOption = StringOpt("--output", "Output directory for the search index", "./search_index");
var queryArgument = new Argument<string>("query") { Description = "Search query text" };
var indexOption = StringOpt("--index", "Path to the search index directory", "./search_index");
var limitOption = IntOpt("--limit", "Maximum number of results to return", 50);
var bookOption = new Option<string?>("--book") { Description = "Filter results by exact book title" };
var categoryOption = new Option<string?>("--category") { Description = "Filter results by category (partial match)" };
var infoIndexOption = StringOpt("--index", "Path to the search index directory", "./search_index");

var indexCommand = Cmd("index", "Build search index from the database", parseResult => { var db = parseResult.GetValue(dbOption)!; var output = parseResult.GetValue(outputOption)!; Console.WriteLine($"╔══════════════════════════════════════════╗\n║     OtzariaSearch - Index Builder        ║\n╚══════════════════════════════════════════╝\n\n  Database: {db}\n  Output:   {output}\n"); new IndexBuilder(db, output).Build(); }, dbOption, outputOption);
var searchCommand = Cmd("search", "Search the indexed library", parseResult => { var query = parseResult.GetValue(queryArgument)!; var indexPath = parseResult.GetValue(indexOption)!; var limit = parseResult.GetValue(limitOption); var book = parseResult.GetValue(bookOption); var category = parseResult.GetValue(categoryOption); using var bridge = new BridgeService(indexPath); Console.WriteLine(bridge.Search(query, limit, book, category)); }, queryArgument, indexOption, limitOption, bookOption, categoryOption);
var infoCommand = Cmd("info", "Show information about the search index", parseResult => { using var bridge = new BridgeService(parseResult.GetValue(infoIndexOption)!); Console.WriteLine(bridge.GetInfo()); }, infoIndexOption);

var rootCommand = new RootCommand("OtzariaSearch - Lucene search engine for the Otzaria book library");
rootCommand.Add(indexCommand); rootCommand.Add(searchCommand); rootCommand.Add(infoCommand);
return await new CommandLineConfiguration(rootCommand).InvokeAsync(args);
