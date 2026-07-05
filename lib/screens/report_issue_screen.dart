import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/dispute_service.dart';
import '../services/reservation_service.dart';

/// US41: "Reportar un problema" — formulario (categoría + descripción) que
/// llama a POST /community-trust/reservations/{id}/disputes.
class ReportIssueScreen extends StatefulWidget {
  final ReservationData reservation;
  const ReportIssueScreen({super.key, required this.reservation});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _descriptionCtrl = TextEditingController();
  String _category = 'VEHICULO';
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  static const _categories = [
    {'code': 'VEHICULO', 'label': 'Estado del vehículo'},
    {'code': 'PAGO', 'label': 'Problema de pago'},
    {'code': 'COMPORTAMIENTO', 'label': 'Comportamiento del cliente/propietario'},
    {'code': 'OTRO', 'label': 'Otro'},
  ];

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_descriptionCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Describe el problema antes de enviar.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final user = await AuthService.getCurrentUser();
      if (user == null) {
        setState(() {
          _submitting = false;
          _error = 'No hay sesión activa.';
        });
        return;
      }
      await DisputeService.reportIssue(
        reservationId: widget.reservation.id,
        reporterId: user.userId,
        category: _category,
        description: _descriptionCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } on DisputeException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = 'No se pudo conectar al servidor.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(onTap: () => context.pop(), child: const Icon(Icons.arrow_back, color: Colors.black)),
        title: const Text('Reportar un problema', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SafeArea(
        child: _submitted ? _buildSuccessState() : _buildFormState(),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      key: const Key('report_issue_success'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Reporte enviado', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
            const SizedBox(height: 8),
            const Text(
              'Tu reporte quedó registrado con estado "abierto". Nuestro equipo lo revisará.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            CustomButton(label: 'Volver', onPressed: () => context.pop()),
          ],
        ),
      ),
    );
  }

  Widget _buildFormState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reserva ${widget.reservation.reservationCode}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
          const SizedBox(height: 20),
          const Text('Categoría', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('report_issue_category_selector'),
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((c) {
              final selected = _category == c['code'];
              return ChoiceChip(
                label: Text(c['label']!),
                selected: selected,
                onSelected: (_) => setState(() => _category = c['code']!),
                selectedColor: kCyan.withValues(alpha: 0.2),
                labelStyle: TextStyle(color: selected ? Colors.black : Colors.grey.shade700, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Descripción', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('report_issue_description_field'),
            controller: _descriptionCtrl,
            maxLines: 5,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: 'Describe lo ocurrido con el mayor detalle posible...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('report_issue_error'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('report_issue_submit_button'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
