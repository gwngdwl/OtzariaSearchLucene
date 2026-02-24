import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ui/models/search_result.dart';
import 'package:flutter_ui/models/highlight_span.dart';
import 'package:flutter_ui/ui/widgets/search_result_card.dart';

void main() {
  group('SearchResultCard', () {
    testWidgets('displays all required fields', (WidgetTester tester) async {
      // Arrange
      final result = SearchResult(
        rank: 1,
        bookTitle: 'בראשית',
        reference: 'א:א',
        category: 'תנ״ך',
        snippet: 'בראשית ברא אלהים את השמים ואת הארץ',
        score: 95.5,
        highlights: [],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify all fields are displayed
      expect(find.text('#1'), findsOneWidget); // rank
      expect(find.text('בראשית'), findsOneWidget); // bookTitle
      expect(find.text('א:א'), findsOneWidget); // reference
      expect(find.text('תנ״ך'), findsOneWidget); // category
      expect(
        find.text('בראשית ברא אלהים את השמים ואת הארץ'),
        findsOneWidget,
      ); // snippet
      expect(find.textContaining('95.5'), findsOneWidget); // score
    });

    testWidgets('displays snippet without highlights correctly', (
      WidgetTester tester,
    ) async {
      // Arrange
      final result = SearchResult(
        rank: 2,
        bookTitle: 'שמות',
        reference: 'ב:ג',
        category: 'תנ״ך',
        snippet: 'ואלה שמות בני ישראל',
        score: 88.0,
        highlights: [],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert
      expect(find.text('ואלה שמות בני ישראל'), findsOneWidget);
    });

    testWidgets('displays snippet with highlights correctly', (
      WidgetTester tester,
    ) async {
      // Arrange
      final result = SearchResult(
        rank: 3,
        bookTitle: 'ויקרא',
        reference: 'ג:ד',
        category: 'תנ״ך',
        snippet: 'ויקרא אל משה וידבר ה אליו',
        score: 92.3,
        highlights: [
          const HighlightSpan(start: 0, end: 5, text: 'ויקרא'),
          const HighlightSpan(start: 9, end: 13, text: 'משה'),
        ],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify the card is rendered (RichText is used for highlights)
      expect(find.byType(SearchResultCard), findsOneWidget);
      expect(
        find.byType(RichText),
        findsWidgets,
      ); // Multiple RichText widgets exist
    });

    testWidgets('uses RTL text direction', (WidgetTester tester) async {
      // Arrange
      final result = SearchResult(
        rank: 4,
        bookTitle: 'במדבר',
        reference: 'ד:ה',
        category: 'תנ״ך',
        snippet: 'וידבר ה אל משה במדבר סיני',
        score: 85.0,
        highlights: [],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify Directionality widget is present with RTL
      final directionality = tester.widget<Directionality>(
        find.descendant(
          of: find.byType(SearchResultCard),
          matching: find.byType(Directionality),
        ),
      );
      expect(directionality.textDirection, TextDirection.rtl);
    });

    testWidgets('displays card with proper visual separation', (
      WidgetTester tester,
    ) async {
      // Arrange
      final result = SearchResult(
        rank: 5,
        bookTitle: 'דברים',
        reference: 'ה:ו',
        category: 'תנ״ך',
        snippet: 'אלה הדברים אשר דבר משה',
        score: 90.0,
        highlights: [],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify Card widget is used for visual separation
      expect(find.byType(Card), findsOneWidget);
      final card = tester.widget<Card>(find.byType(Card));
      expect(card.elevation, 2);
      expect(
        card.margin,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      );
    });

    testWidgets('handles multiple highlights in correct order', (
      WidgetTester tester,
    ) async {
      // Arrange
      final result = SearchResult(
        rank: 6,
        bookTitle: 'תהלים',
        reference: 'א:א',
        category: 'כתובים',
        snippet: 'אשרי האיש אשר לא הלך בעצת רשעים',
        score: 87.5,
        highlights: [
          const HighlightSpan(start: 0, end: 4, text: 'אשרי'),
          const HighlightSpan(start: 11, end: 15, text: 'אשר'),
        ],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify RichText is used for rendering highlights
      expect(
        find.byType(RichText),
        findsWidgets,
      ); // Multiple RichText widgets exist
    });

    testWidgets('displays icons for reference and category', (
      WidgetTester tester,
    ) async {
      // Arrange
      final result = SearchResult(
        rank: 7,
        bookTitle: 'משלי',
        reference: 'א:ב',
        category: 'כתובים',
        snippet: 'לדעת חכמה ומוסר',
        score: 82.0,
        highlights: [],
      );

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SearchResultCard(result: result)),
        ),
      );

      // Assert - verify icons are present
      expect(find.byIcon(Icons.bookmark_outline), findsOneWidget);
      expect(find.byIcon(Icons.category_outlined), findsOneWidget);
    });
  });
}
