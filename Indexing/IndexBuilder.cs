using Lucene.Net.Analysis;
using Lucene.Net.Documents;
using Lucene.Net.Index;
using Lucene.Net.Store;
using Lucene.Net.Util;
using Microsoft.Data.Sqlite;
using OtzariaSearch.Analyzers;
using System.Diagnostics;

namespace OtzariaSearch.Indexing;

public sealed class IndexBuilder
{
    private const LuceneVersion AppLuceneVersion = LuceneVersion.LUCENE_48;
    private const int BatchSize = 10_000;

    private readonly string _dbPath;
    private readonly string _indexPath;

    public IndexBuilder(string dbPath, string indexPath)
    {
        _dbPath = dbPath;
        _indexPath = indexPath;
    }

    public void Build()
    {
        var stopwatch = Stopwatch.StartNew();

        if (!File.Exists(_dbPath))
        {
            Console.Error.WriteLine($"Error: Database file not found: {_dbPath}");
            return;
        }

        // Ensure index directory exists
        System.IO.Directory.CreateDirectory(_indexPath);

        using var analyzer = new HebrewAnalyzer(AppLuceneVersion);
        using var indexDir = FSDirectory.Open(_indexPath);

        var indexConfig = new IndexWriterConfig(AppLuceneVersion, analyzer)
        {
            OpenMode = OpenMode.CREATE, // always recreate
            RAMBufferSizeMB = 256       // larger buffer for faster indexing
        };

        using var writer = new IndexWriter(indexDir, indexConfig);

        var connStr = new SqliteConnectionStringBuilder
        {
            DataSource = _dbPath,
            Mode = SqliteOpenMode.ReadOnly
        }.ToString();

        using var connection = new SqliteConnection(connStr);
        connection.Open();

        // Pre-load book metadata
        Console.WriteLine("Loading book metadata...");
        var books = LoadBooks(connection);
        Console.WriteLine($"  Loaded {books.Count:N0} books.");

        // Pre-load category paths
        Console.WriteLine("Loading categories...");
        var categoryPaths = LoadCategoryPaths(connection);
        Console.WriteLine($"  Loaded {categoryPaths.Count:N0} categories.");

        // Get total line count for progress
        long totalLines = GetTotalLineCount(connection);
        Console.WriteLine($"Total lines to index: {totalLines:N0}");
        Console.WriteLine();

        // Index lines in batches
        long indexed = 0;
        long lastProgress = -1;

        using var lineCmd = connection.CreateCommand();
        lineCmd.CommandText = "SELECT id, bookId, lineIndex, content, heRef FROM line ORDER BY bookId, lineIndex";

        using var reader = lineCmd.ExecuteReader();

        while (reader.Read())
        {
            long lineId = reader.GetInt64(0);
            long bookId = reader.GetInt64(1);
            int lineIndex = reader.GetInt32(2);
            string content = reader.IsDBNull(3) ? "" : reader.GetString(3);
            string heRef = reader.IsDBNull(4) ? "" : reader.GetString(4);

            // Skip empty lines
            if (string.IsNullOrWhiteSpace(content)) 
            {
                indexed++;
                continue;
            }

            // Get book info
            books.TryGetValue(bookId, out var bookInfo);
            string bookTitle = bookInfo?.Title ?? "";
            long categoryId = bookInfo?.CategoryId ?? 0;
            string categoryPath = "";
            if (categoryId > 0)
                categoryPaths.TryGetValue(categoryId, out categoryPath!);
            categoryPath ??= "";

            // Strip HTML for plain text content
            string plainContent = HebrewTextUtils.StripHtml(content);

            var doc = new Document
            {
                // Stored only (for display)
                new StoredField("lineId", lineId),
                new StoredField("heRef", heRef),
                new StoredField("lineIndex", lineIndex),

                // Indexed + stored (for filtering + display)
                new Int64Field("bookId", bookId, Field.Store.YES),
                new StringField("bookTitle", bookTitle, Field.Store.YES),
                new StringField("categoryPath", categoryPath, Field.Store.YES),

                // Full-text searchable + stored (main content)
                new TextField("content", plainContent, Field.Store.YES),

                // Searchable book title (for searching by title too)
                new TextField("bookTitleSearch", bookTitle, Field.Store.NO),
            };

            writer.AddDocument(doc);

            indexed++;

            // Progress indicator
            long progress = indexed * 100 / totalLines;
            if (progress != lastProgress)
            {
                lastProgress = progress;
                Console.Write($"\rIndexing: {progress}% ({indexed:N0}/{totalLines:N0})");
            }
        }

        Console.WriteLine();
        Console.WriteLine("Committing index...");
        writer.Commit();

        stopwatch.Stop();
        Console.WriteLine();
        Console.WriteLine($"Done! Indexed {indexed:N0} lines in {stopwatch.Elapsed.TotalSeconds:F1}s");
        Console.WriteLine($"Index location: {Path.GetFullPath(_indexPath)}");
    }

    private static Dictionary<long, BookInfo> LoadBooks(SqliteConnection connection)
    {
        var books = new Dictionary<long, BookInfo>();
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT id, title, categoryId FROM book";

        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            long id = reader.GetInt64(0);
            string title = reader.IsDBNull(1) ? "" : reader.GetString(1);
            long categoryId = reader.IsDBNull(2) ? 0 : reader.GetInt64(2);
            books[id] = new BookInfo(title, categoryId);
        }
        return books;
    }

    private static Dictionary<long, string> LoadCategoryPaths(SqliteConnection connection)
    {
        // Load all categories
        var categories = new Dictionary<long, (string Title, long? ParentId)>();
        using (var cmd = connection.CreateCommand())
        {
            cmd.CommandText = "SELECT id, title, parentId FROM category";
            using var reader = cmd.ExecuteReader();
            while (reader.Read())
            {
                long id = reader.GetInt64(0);
                string title = reader.IsDBNull(1) ? "" : reader.GetString(1);
                long? parentId = reader.IsDBNull(2) ? null : reader.GetInt64(2);
                categories[id] = (title, parentId);
            }
        }

        // Build full paths
        var paths = new Dictionary<long, string>();
        foreach (var (id, _) in categories)
        {
            paths[id] = BuildCategoryPath(id, categories);
        }
        return paths;
    }

    private static string BuildCategoryPath(long id, Dictionary<long, (string Title, long? ParentId)> categories)
    {
        var parts = new List<string>();
        long? current = id;
        int safety = 20; // prevent infinite loops

        while (current.HasValue && safety-- > 0)
        {
            if (categories.TryGetValue(current.Value, out var cat))
            {
                parts.Add(cat.Title);
                current = cat.ParentId;
            }
            else break;
        }

        parts.Reverse();
        return string.Join("/", parts);
    }

    private static long GetTotalLineCount(SqliteConnection connection)
    {
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT COUNT(*) FROM line";
        return (long)cmd.ExecuteScalar()!;
    }

    private record BookInfo(string Title, long CategoryId);
}
