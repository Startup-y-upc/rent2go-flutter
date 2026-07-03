import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/payments_service.dart';

/// US48/US49: historial de retiros, consumiendo
/// GET /api/v1/payments/owners/{ownerId}/withdrawals.
class WithdrawalHistoryScreen extends StatefulWidget {
  const WithdrawalHistoryScreen({super.key});

  @override
  State<WithdrawalHistoryScreen> createState() => _WithdrawalHistoryScreenState();
}

class _WithdrawalHistoryScreenState extends State<WithdrawalHistoryScreen> {
  bool _loading = true;
  String? _error;
  List<WithdrawalData> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final user = await AuthService.getCurrentUser();
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No hay sesión activa.';
      });
      return;
    }
    try {
      final paged = await PaymentsService.getWithdrawalHistory(ownerId: user.userId);
      if (!mounted) return;
      setState(() {
        _withdrawals = paged.content;
        _loading = false;
      });
    } on WithdrawalException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el historial de retiros.';
      });
    }
  }

  Color _statusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return Colors.orange;
      case 'COMPLETED':
        return Colors.green;
      case 'REJECTED':
      case 'CANCELLED':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String? status) {
    switch (status?.toUpperCase()) {
      case 'PENDING':
        return 'Pendiente';
      case 'COMPLETED':
        return 'Completado';
      case 'REJECTED':
        return 'Rechazado';
      case 'CANCELLED':
        return 'Cancelado';
      default:
        return status ?? '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1B1B2F),
        elevation: 0,
        leading: IconButton(
          key: const Key('withdrawal_history_back_button'),
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Historial de retiros', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(key: Key('withdrawal_history_loading'), child: CircularProgressIndicator(color: kCyan));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Container(
            key: const Key('withdrawal_history_error'),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.red.shade200)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        ],
      );
    }
    if (_withdrawals.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Center(
            key: Key('withdrawal_history_empty'),
            child: Padding(
              padding: EdgeInsets.only(top: 80),
              child: Column(
                children: [
                  Icon(Icons.account_balance_wallet_outlined, size: 48, color: Colors.grey),
                  SizedBox(height: 12),
                  Text('Aún no has solicitado retiros', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      key: const Key('withdrawal_history_list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _withdrawals.length,
      itemBuilder: (context, index) {
        final w = _withdrawals[index];
        return Container(
          key: Key('withdrawal_history_row_${w.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.arrow_upward, color: _statusColor(w.status)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('\$${w.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    if (w.requestedAt != null)
                      Text(w.requestedAt!, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    if (w.payoutDestinationNote != null && w.payoutDestinationNote!.isNotEmpty)
                      Text(w.payoutDestinationNote!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: _statusColor(w.status).withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Text(_statusLabel(w.status), style: TextStyle(color: _statusColor(w.status), fontWeight: FontWeight.bold, fontSize: 11)),
              ),
            ],
          ),
        );
      },
    );
  }
}
