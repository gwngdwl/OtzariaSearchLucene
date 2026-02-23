using Lucene.Net.Analysis;
using Lucene.Net.Analysis.Core;
using Lucene.Net.Analysis.Standard;
using Lucene.Net.Util;
using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace OtzariaSearch.Analyzers;

/// <summary>
/// Custom Hebrew analyzer that handles nikud (vowels) removal, 
/// te'amim (cantillation marks) removal, and HTML stripping.
/// </summary>
public sealed class HebrewAnalyzer : Analyzer
{
    private readonly LuceneVersion _matchVersion;

    public HebrewAnalyzer(LuceneVersion matchVersion)
    {
        _matchVersion = matchVersion;
    }

    protected override TokenStreamComponents CreateComponents(string fieldName, TextReader reader)
    {
        var tokenizer = new StandardTokenizer(_matchVersion, reader);
        TokenStream stream = new LowerCaseFilter(_matchVersion, tokenizer);
        stream = new NikudFilter(stream);
        return new TokenStreamComponents(tokenizer, stream);
    }

    /// <summary>
    /// Override to strip HTML before tokenization.
    /// </summary>
    protected override TextReader InitReader(string fieldName, TextReader reader)
    {
        // Read all text, strip HTML, then return as a new reader
        string text = reader.ReadToEnd();
        text = StripHtml(text);
        return new StringReader(text);
    }

    private static string StripHtml(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;
        return Regex.Replace(input, "<[^>]+>", " ");
    }
}

/// <summary>
/// Token filter that removes Hebrew nikud (vowels) and te'amim (cantillation marks).
/// Unicode ranges:
///   - Hebrew points (nikud): U+05B0 - U+05BD, U+05BF, U+05C1, U+05C2, U+05C4, U+05C5, U+05C7
///   - Hebrew cantillation (te'amim): U+0591 - U+05AF
/// </summary>
public sealed class NikudFilter : TokenFilter
{
    private readonly Lucene.Net.Analysis.TokenAttributes.ICharTermAttribute _termAttr;

    public NikudFilter(TokenStream input) : base(input)
    {
        _termAttr = AddAttribute<Lucene.Net.Analysis.TokenAttributes.ICharTermAttribute>();
    }

    public override bool IncrementToken()
    {
        if (!m_input.IncrementToken())
            return false;

        char[] buffer = _termAttr.Buffer;
        int length = _termAttr.Length;
        int newLen = 0;

        for (int i = 0; i < length; i++)
        {
            char c = buffer[i];
            if (!IsNikudOrTeamim(c))
            {
                buffer[newLen++] = c;
            }
        }

        _termAttr.Length = newLen;
        return true;
    }

    private static bool IsNikudOrTeamim(char c)
    {
        // Cantillation marks (te'amim): U+0591 - U+05AF
        if (c >= '\u0591' && c <= '\u05AF') return true;
        // Hebrew points (nikud): U+05B0 - U+05BD
        if (c >= '\u05B0' && c <= '\u05BD') return true;
        // Additional nikud marks
        if (c == '\u05BF') return true; // HEBREW POINT RAFE
        if (c == '\u05C1') return true; // HEBREW POINT SHIN DOT
        if (c == '\u05C2') return true; // HEBREW POINT SIN DOT
        if (c == '\u05C4') return true; // HEBREW MARK UPPER DOT
        if (c == '\u05C5') return true; // HEBREW MARK LOWER DOT
        if (c == '\u05C7') return true; // HEBREW POINT QAMATS QATAN
        return false;
    }
}

/// <summary>
/// Utility class for Hebrew text normalization (used outside of Lucene pipeline).
/// </summary>
public static class HebrewTextUtils
{
    /// <summary>
    /// Remove nikud and te'amim from text.
    /// </summary>
    public static string RemoveNikud(string text)
    {
        if (string.IsNullOrEmpty(text)) return text;

        var sb = new StringBuilder(text.Length);
        foreach (char c in text)
        {
            if (!IsNikudOrTeamim(c))
                sb.Append(c);
        }
        return sb.ToString();
    }

    /// <summary>
    /// Strip HTML tags from text.
    /// </summary>
    public static string StripHtml(string text)
    {
        if (string.IsNullOrEmpty(text)) return text;
        return Regex.Replace(text, "<[^>]+>", " ");
    }

    /// <summary>
    /// Full normalization: strip HTML + remove nikud.
    /// </summary>
    public static string Normalize(string text)
    {
        return RemoveNikud(StripHtml(text));
    }

    private static bool IsNikudOrTeamim(char c)
    {
        if (c >= '\u0591' && c <= '\u05AF') return true;
        if (c >= '\u05B0' && c <= '\u05BD') return true;
        if (c == '\u05BF' || c == '\u05C1' || c == '\u05C2' ||
            c == '\u05C4' || c == '\u05C5' || c == '\u05C7') return true;
        return false;
    }
}
