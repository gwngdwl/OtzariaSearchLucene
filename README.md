# OtzariaSearch

מנוע חיפוש טקסט מלא עבור מאגר הספרים של **אוצריא**, מבוסס על [Lucene.NET](https://lucenenet.apache.org/) 4.8.

## תכונות

- 🔍 חיפוש טקסט חופשי ב-**5.45 מיליון** שורות תוכן
- 📚 תמיכה ב-**230,000+** ספרים
- 🇮🇱 **Hebrew Analyzer** מותאם – הסרת ניקוד, טעמים ותגיות HTML
- 🎯 סינון לפי **ספר** או **קטגוריה**
- ⚡ חיפוש ב-**~100ms**
- 🎨 פלט צבעוני עם highlight של מילות החיפוש

## דרישות

- .NET 10 SDK (לבנייה)
- גישה לקובץ `seforim.db`

## התקנה ושימוש

### בניית אינדקס (פעם אחת)

```powershell
dotnet run -- index --db "C:\אוצריא\אוצריא\seforim.db" --output "./search_index"
```

### חיפוש

```powershell
# חיפוש בסיסי
dotnet run -- search "בראשית ברא" --limit 10

# סינון לפי קטגוריה
dotnet run -- search "שבת" --category "תלמוד"

# סינון לפי ספר
dotnet run -- search "תפילין" --book "משנה תורה"

# wildcard search (requires explicit flag)
dotnet run -- search "ברא*" --wildcard

# מידע על האינדקס
dotnet run -- info
```

### תחביר Wildcard

- `*` - מתאים לכל רצף תווים
- `?` - מתאים לתו יחיד
- `\*` או `\?` - חיפוש תו ליטרלי במקום wildcard
- מצב wildcard מופעל רק עם `--wildcard`
- מונח wildcard חייב להכיל לפחות תו אחד שאינו wildcard (למשל `*` לבד יוחזר כשגיאה)

### בניית בינארי יחיד

```powershell
dotnet publish -c Release -o ./publish
```

לאחר הבנייה, אפשר להשתמש ב-`.exe` ישירות:

```powershell
.\publish\OtzariaSearch.exe search "בראשית ברא" --index "./search_index"
```

## מבנה הפרויקט

```
├── Program.cs                 # CLI: index / search / info
├── Analyzers/
│   └── HebrewAnalyzer.cs      # הסרת ניקוד, טעמים ו-HTML
├── Indexing/
│   └── IndexBuilder.cs        # SQLite → Lucene index
└── Search/
    └── SearchEngine.cs        # חיפוש, סינון ו-snippets
```

## טכנולוגיות

- **C# / .NET 10**
- **Lucene.NET 4.8** – מנוע חיפוש
- **Microsoft.Data.Sqlite** – קריאה מה-DB
- **System.CommandLine** – ממשק CLI
