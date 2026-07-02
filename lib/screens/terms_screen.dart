import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

const _kCyan = Color(0xFF00E5FF);
const _kDarkBg = Color(0xFF0D1B2A);

/// Reads and displays the canonical Terms & Conditions content, bundled as a
/// static asset (assets/legal/terms-and-conditions.md) — no network fetch,
/// no backend endpoint. Canonical source: docs/legal/terms-and-conditions.md
/// (see docs/legal/check-parity.md before editing that source).
///
/// Rendering: the document only uses a limited markdown subset (H2 headings,
/// bold spans, bullet lists, links, a metadata line, a horizontal rule).
/// Given no markdown-rendering package is already a project dependency and
/// the app otherwise favors dependency-minimalism (see pubspec.yaml), this
/// subset is hand-parsed into real widgets instead of pulling in a general
/// markdown package — no legal text is altered, only how it is displayed.
class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  late Future<String> _contentFuture;

  @override
  void initState() {
    super.initState();
    _contentFuture = _loadTerms();
  }

  Future<String> _loadTerms() {
    return rootBundle.loadString('assets/legal/terms-and-conditions.md');
  }

  void _retry() {
    setState(() {
      _contentFuture = _loadTerms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _kDarkBg,
        foregroundColor: Colors.white,
        title: const Text('Términos y Condiciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          key: const Key('terms_content_future_builder'),
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                key: Key('terms_loading_indicator'),
                child: CircularProgressIndicator(color: _kCyan),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                key: const Key('terms_error_state'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 12),
                      const Text(
                        'No se pudo cargar el contenido de Términos y Condiciones.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        key: const Key('terms_retry_button'),
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(backgroundColor: _kCyan, foregroundColor: Colors.black),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final blocks = _MarkdownParser.parse(snapshot.data!);
            return ListView.builder(
              key: const Key('terms_content_list'),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: blocks.length,
              itemBuilder: (context, index) => blocks[index],
            );
          },
        ),
      ),
    );
  }
}

/// Minimal markdown-subset parser for this document only: H1/H2 headings,
/// bold spans (`**text**`), bullet list items (`- text`), inline links
/// (`[text](url)`), a plain metadata line, and `---` horizontal rules.
/// Not a general-purpose markdown engine — intentionally scoped to what
/// docs/legal/terms-and-conditions.md actually uses.
class _MarkdownParser {
  static List<Widget> parse(String source) {
    final lines = source.split('\n');
    final widgets = <Widget>[];
    final bulletBuffer = <String>[];

    void flushBullets() {
      if (bulletBuffer.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: bulletBuffer
                .map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2, right: 8),
                            child: Icon(Icons.circle, size: 6, color: _kDarkBg),
                          ),
                          Expanded(
                            child: _richTextFromInline(
                              item,
                              const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      );
      bulletBuffer.clear();
    }

    for (final rawLine in lines) {
      final line = rawLine.trimRight();

      if (line.startsWith('- ')) {
        bulletBuffer.add(line.substring(2).trim());
        continue;
      }
      flushBullets();

      if (line.trim().isEmpty) continue;

      if (line.startsWith('# ')) {
        widgets.add(_titleBlock(line.substring(2).trim()));
      } else if (line.startsWith('## ')) {
        widgets.add(_sectionHeading(line.substring(3).trim()));
      } else if (line.trim() == '---') {
        widgets.add(const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: Color(0xFFD5DEE6), thickness: 1),
        ));
      } else if (line.startsWith('**Última actualización:**')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _richTextFromInline(
            line,
            const TextStyle(fontSize: 13, color: Colors.black54, fontStyle: FontStyle.italic),
          ),
        ));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _richTextFromInline(
            line,
            const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
        ));
      }
    }
    flushBullets();
    return widgets;
  }

  static Widget _titleBlock(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _kDarkBg),
      ),
    );
  }

  /// Section headings get visual grouping (card-like container, primary
  /// color accent) to match the app's dark-header/cyan-accent convention
  /// used elsewhere (see common_widgets.dart's kCyan / dark AppBar usage).
  static Widget _sectionHeading(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _kDarkBg,
          borderRadius: BorderRadius.circular(8),
          border: const Border(left: BorderSide(color: _kCyan, width: 4)),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  /// Renders bold spans (`**...**`) and links (`[text](url)`) inline within
  /// a single paragraph/bullet line, preserving plain text around them.
  /// Links are styled (underlined, accent color) but not made tappable —
  /// adding a URL-launch dependency solely for two static contact links in
  /// a legal document is disproportionate versus the project's existing
  /// dependency-minimalism convention (no url_launcher in pubspec.yaml).
  static Widget _richTextFromInline(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*|\[(.+?)\]\((.+?)\)');
    int cursor = 0;

    for (final match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.bold, color: _kDarkBg),
        ));
      } else if (match.group(2) != null) {
        final linkText = match.group(2)!;
        spans.add(TextSpan(
          text: linkText,
          style: const TextStyle(color: Color(0xFF0077B6), decoration: TextDecoration.underline),
        ));
      }
      cursor = match.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
