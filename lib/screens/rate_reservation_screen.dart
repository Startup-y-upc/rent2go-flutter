import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import '../services/dispute_service.dart';
import '../services/reservation_service.dart';

/// US43: "Calificar" — estrellas + comentario, POST /community-trust/reviews.
/// Solo debe abrirse sobre una reserva COMPLETED (verificado por el caller).
class RateReservationScreen extends StatefulWidget {
  final ReservationData reservation;
  const RateReservationScreen({super.key, required this.reservation});

  @override
  State<RateReservationScreen> createState() => _RateReservationScreenState();
}

class _RateReservationScreenState extends State<RateReservationScreen> {
  final _commentCtrl = TextEditingController();
  int _rating = 0;
  ReviewCategoryOption _category = ReviewCategoryOption.rentalExperience;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      setState(() => _error = 'Selecciona una calificación de estrellas.');
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
      // El revisor es quien califica; la contraparte (dueño/arrendatario) es
      // reviewedUserId — se infiere comparando con los IDs de la reserva.
      final reviewedUserId = user.userId == widget.reservation.ownerId
          ? widget.reservation.renterId
          : widget.reservation.ownerId;
      await DisputeService.submitReview(
        reservationId: widget.reservation.id,
        vehicleId: widget.reservation.vehicleId,
        reviewerId: user.userId,
        reviewedUserId: reviewedUserId,
        category: _category,
        rating: _rating,
        comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
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
        title: const Text('Calificar reserva', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 17)),
      ),
      body: SafeArea(
        child: _submitted ? _buildSuccessState() : _buildFormState(),
      ),
    );
  }

  Widget _buildSuccessState() {
    return Center(
      key: const Key('rate_reservation_success'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('¡Gracias por tu calificación!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
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
          const Text('¿Cómo calificarías tu experiencia?', style: TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 12),
          Row(
            key: const Key('rate_reservation_stars'),
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starValue = i + 1;
              return IconButton(
                key: Key('rate_reservation_star_$starValue'),
                iconSize: 36,
                onPressed: () => setState(() => _rating = starValue),
                icon: Icon(
                  starValue <= _rating ? Icons.star : Icons.star_border,
                  color: starValue <= _rating ? Colors.amber : Colors.grey.shade400,
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          const Text('Categoría', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          Wrap(
            key: const Key('rate_reservation_category_selector'),
            spacing: 8,
            runSpacing: 8,
            children: ReviewCategoryOption.values.map((c) {
              final selected = _category == c;
              return ChoiceChip(
                label: Text(c.label),
                selected: selected,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: kCyan.withOpacity(0.2),
                labelStyle: TextStyle(color: selected ? Colors.black : Colors.grey.shade700, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Comentario (opcional)', style: TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('rate_reservation_comment_field'),
            controller: _commentCtrl,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              hintText: 'Cuéntanos más sobre tu experiencia...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, key: const Key('rate_reservation_error'), style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('rate_reservation_submit_button'),
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: kCyan,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Text('Enviar calificación', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
