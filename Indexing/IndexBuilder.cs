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
    private readonly string _dbPath;
    private readonly string _indexPath;
    private const string LineQuery = "SELECT id, bookId, lineIndex, content, heRef FROM line ORDER BY bookId, lineIndex";

    public IndexBuilder(string dbPath, string indexPath) { _dbPath = dbPath; _indexPath = indexPath; }

    public void Build()
    {
        var stopwatch = Stopwatch.StartNew();
        if (!File.Exists(_dbPath))
        {
            Console.Error.WriteLine($"Error: Database file not found: {_dbPath}");
            return;
        }

        System.IO.Directory.CreateDirectory(_indexPath);
        using var analyzer = new HebrewAnalyzer(AppLuceneVersion);
        using var writer = new IndexWriter(
            FSDirectory.Open(_indexPath),
            new IndexWriterConfig(AppLuceneVersion, analyzer) { OpenMode = OpenMode.CREATE, RAMBufferSizeMB = 256 });
        using var connection = new SqliteConnection(new SqliteConnectionStringBuilder { DataSource = _dbPath, Mode = SqliteOpenMode.ReadOnly }.ToString());
        connection.Open();

        Console.WriteLine("Loading book metadata...");
        var books = LoadBooks(connection);
        Console.WriteLine($"  Loaded {books.Count:N0} books.");
        Console.WriteLine("Loading categories...");
        var categoryPaths = LoadCategoryPaths(connection);
        Console.WriteLine($"  Loaded {categoryPaths.Count:N0} categories.");
        var totalLines = GetTotalLineCount(connection);
        Console.WriteLine($"Total lines to index: {totalLines:N0}");
        Console.WriteLine();

        long indexed = 0;
        long lastProgress = -1;
        using var lineCmd = connection.CreateCommand();
        lineCmd.CommandText = LineQuery;
        using var reader = lineCmd.ExecuteReader();
        while (reader.Read())
        {
            var lineId = reader.GetInt64(0);
            var bookId = reader.GetInt64(1);
            var lineIndex = reader.GetInt32(2);
            var content = ReadString(reader, 3);
            if (string.IsNullOrWhiteSpace(content)) { indexed++; continue; }
            var heRef = ReadString(reader, 4);
            books.TryGetValue(bookId, out var bookInfo);
            var bookTitle = bookInfo?.Title ?? "";
            var categoryPath = "";
            if (bookInfo is { CategoryId: > 0 } info && categoryPaths.TryGetValue(info.CategoryId, out var path)) categoryPath = path ?? "";

            writer.AddDocument(new Document
            {
                new StoredField("lineId", lineId),
                new StoredField("heRef", heRef),
                new StoredField("lineIndex", lineIndex),
                new Int64Field("bookId", bookId, Field.Store.YES),
                new StringField("bookTitle", bookTitle, Field.Store.YES),
                new StringField("categoryPath", categoryPath, Field.Store.YES),
                new TextField("content", HebrewTextUtils.StripHtml(content), Field.Store.YES),
                new TextField("bookTitleSearch", bookTitle, Field.Store.NO),
            });
            indexed++;
            var progress = indexed * 100 / totalLines;
            if (progress == lastProgress) continue;
            lastProgress = progress;
            Console.Write($"\rIndexing: {progress}% ({indexed:N0}/{totalLines:N0})");
        }

        Console.WriteLine();
        Console.WriteLine("Committing index...");
        writer.Commit();

        stopwatch.Stop();
        Console.WriteLine();
        Console.WriteLine($"Done! Indexed {indexed:N0} lines in {stopwatch.Elapsed.TotalSeconds:F1}s");
        Console.WriteLine($"Index location: {Path.GetFullPath(_indexPath)}");
    }

    private static string ReadString(SqliteDataReader reader, int ordinal) => reader.IsDBNull(ordinal) ? "" : reader.GetString(ordinal);

    private static Dictionary<long, BookInfo> LoadBooks(SqliteConnection connection)
    {
        var books = new Dictionary<long, BookInfo>();
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT id, title, categoryId FROM book";
        using var reader = cmd.ExecuteReader();
        while (reader.Read()) books[reader.GetInt64(0)] = new BookInfo(ReadString(reader, 1), reader.IsDBNull(2) ? 0 : reader.GetInt64(2));
        return books;
    }

    private static Dictionary<long, string> LoadCategoryPaths(SqliteConnection connection)
    {
        var categories = new Dictionary<long, (string Title, long? ParentId)>();
        using var cmd = connection.CreateCommand();
        cmd.CommandText = "SELECT id, title, parentId FROM category";
        using var reader = cmd.ExecuteReader();
        while (reader.Read())
        {
            categories[reader.GetInt64(0)] = (ReadString(reader, 1), reader.IsDBNull(2) ? null : reader.GetInt64(2));
        }
        var paths = new Dictionary<long, string>(categories.Count);
        foreach (var id in categories.Keys) paths[id] = BuildCategoryPath(id, categories);
        return paths;
    }

    private static string BuildCategoryPath(long id, Dictionary<long, (string Title, long? ParentId)> categories)
    {
        var parts = new List<string>();
        long? current = id;
        var safety = 20;
        while (current.HasValue && safety-- > 0)
        {
            if (!categories.TryGetValue(current.Value, out var cat)) break;
            parts.Add(cat.Title);
            current = cat.ParentId;
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
