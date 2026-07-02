import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

const _kCyan = Color(0xFF00E5FF);

/// Reads and displays the canonical Terms & Conditions content, bundled as a
/// static asset (assets/legal/terms-and-conditions.md) — no network fetch,
/// no backend endpoint. Canonical source: docs/legal/terms-and-conditions.md
/// (see docs/legal/check-parity.md before editing that source).
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
        backgroundColor: const Color(0xFF0D1B2A),
        foregroundColor: Colors.white,
        title: const Text('Términos y Condiciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _contentFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: _kCyan));
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
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
                        onPressed: _retry,
                        style: ElevatedButton.styleFrom(backgroundColor: _kCyan, foregroundColor: Colors.black),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: SelectableText(
                snapshot.data!,
                style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
              ),
            );
          },
        ),
      ),
    );
  }
}
