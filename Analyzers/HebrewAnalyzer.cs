using Lucene.Net.Analysis;
using Lucene.Net.Analysis.Core;
using Lucene.Net.Analysis.Standard;
using Lucene.Net.Util;
using System.Text;
using System.Text.RegularExpressions;

namespace OtzariaSearch.Analyzers;

public sealed class HebrewAnalyzer : Analyzer
{
    private readonly LuceneVersion _matchVersion;
    public HebrewAnalyzer(LuceneVersion matchVersion) => _matchVersion = matchVersion;

    protected override TokenStreamComponents CreateComponents(string fieldName, TextReader reader)
    {
        var tokenizer = new StandardTokenizer(_matchVersion, reader);
        TokenStream stream = new NikudFilter(new LowerCaseFilter(_matchVersion, tokenizer));
        return new TokenStreamComponents(tokenizer, stream);
    }

    protected override TextReader InitReader(string fieldName, TextReader reader) => new StringReader(HebrewTextUtils.StripHtml(reader.ReadToEnd()));
}

public sealed class NikudFilter : TokenFilter
{
    private readonly Lucene.Net.Analysis.TokenAttributes.ICharTermAttribute _termAttr;
    public NikudFilter(TokenStream input) : base(input) => _termAttr = AddAttribute<Lucene.Net.Analysis.TokenAttributes.ICharTermAttribute>();

    public override bool IncrementToken()
    {
        if (!m_input.IncrementToken()) return false;
        var buffer = _termAttr.Buffer;
        var newLen = 0;
        for (var i = 0; i < _termAttr.Length; i++)
        {
            var c = buffer[i];
            if (!HebrewTextUtils.IsNikudOrTeamim(c)) buffer[newLen++] = c;
        }
        _termAttr.Length = newLen;
        return true;
    }
}

public static class HebrewTextUtils
{
    public static string RemoveNikud(string text)
    {
        if (string.IsNullOrEmpty(text)) return text;
        var sb = new StringBuilder(text.Length);
        foreach (var c in text)
        {
            if (!IsNikudOrTeamim(c)) sb.Append(c);
        }
        return sb.ToString();
    }

    public static string StripHtml(string text) => string.IsNullOrEmpty(text) ? text : Regex.Replace(text, "<[^>]+>", " ");
    public static string Normalize(string text) => RemoveNikud(StripHtml(text));

    public static bool IsNikudOrTeamim(char c)
    {
        if (c >= '\u0591' && c <= '\u05AF') return true;
        if (c >= '\u05B0' && c <= '\u05BD') return true;
        return c is '\u05BF' or '\u05C1' or '\u05C2' or '\u05C4' or '\u05C5' or '\u05C7';
    }
}
