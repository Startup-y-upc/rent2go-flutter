import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _kCyan = Color(0xFF00E5FF);
const _kDarkBg = Color(0xFF0D1B2A);

/// Pantalla de Ayuda / Preguntas Frecuentes.
///
/// Reutiliza el mismo lenguaje visual que TermsScreen (AppBar oscuro con
/// acento cian, tarjetas de encabezado de sección, tipografía) para que la
/// app se sienta consistente entre pantallas de contenido informativo.
/// El contenido es estático (no depende del backend) porque son preguntas
/// frecuentes de producto, no datos transaccionales.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _kDarkBg,
        foregroundColor: Colors.white,
        title: const Text('Ayuda'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          key: const Key('help_content_list'),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: const [
            _FaqSection(
              question: '¿Qué es la cobertura (coverage plan) y cómo funciona?',
              answer:
                  'El plan de cobertura NO es el seguro completo del vehículo: es una '
                  'protección ADICIONAL, opcional, que se contrata junto con la reserva y '
                  'que protege tanto al arrendatario (quien alquila) como al propietario '
                  'durante el período específico del alquiler.\n\n'
                  'Al reservar, pagas un monto adicional por día (según el plan elegido) '
                  'sumado al precio del alquiler del vehículo. Si durante el alquiler ocurre '
                  'un accidente, robo o daño, el plan contratado determina cuánto pagas tú '
                  'de tu bolsillo (el "deducible") y cuánto asume la aseguradora/plataforma.\n\n'
                  'Para el propietario del vehículo, esto reduce su riesgo financiero al '
                  'prestarlo: la aseguradora/plataforma cubre la reparación según el plan '
                  'contratado, en vez de que el propietario tenga que reclamar directamente '
                  'al arrendatario el monto completo del daño.',
            ),
            _FaqSection(
              question: '¿Cuáles son los planes de cobertura disponibles?',
              answer:
                  'Los precios y deducibles exactos de cada plan se muestran en la pantalla '
                  'de reserva (pueden variar según configuración vigente). En general:\n\n'
                  '• Sin cobertura (NONE): no se contrata protección adicional. El '
                  'arrendatario asume el 100% del costo de cualquier daño, pérdida o robo.\n\n'
                  '• Cobertura Básica (BASIC): protege frente a responsabilidad civil y '
                  'daños menores al vehículo. Ante un incidente cubierto, el arrendatario '
                  'paga solo un deducible; el resto lo cubre la aseguradora/plataforma.\n\n'
                  '• Cobertura Estándar (STANDARD): protege responsabilidad civil, daños '
                  'por colisión y robo del vehículo, con un deducible menor que el plan '
                  'Básico.\n\n'
                  '• Cobertura Premium (PREMIUM): protección integral durante todo el '
                  'alquiler — responsabilidad civil, colisión, robo y asistencia en '
                  'carretera — sin deducible: los costos de incidentes cubiertos los asume '
                  'completamente la aseguradora/plataforma.',
            ),
            _FaqSection(
              question: '¿Puedo cambiar mi plan de cobertura después de reservar?',
              answer:
                  'El plan de cobertura se selecciona durante la creación de la reserva y '
                  'queda asociado a esa reserva específica. Si necesitas modificarlo, '
                  'contacta al soporte de Rent2Go antes de que la reserva sea confirmada.',
            ),
            _FaqSection(
              question: '¿Cómo contacto con soporte?',
              answer:
                  'Puedes escribirnos a info@rent2go.pe o a través de nuestros canales de '
                  'redes sociales indicados en la sección de Términos y Condiciones.',
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  final String question;
  final String answer;
  const _FaqSection({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _kDarkBg,
              borderRadius: BorderRadius.circular(8),
              border: const Border(left: BorderSide(color: _kCyan, width: 4)),
            ),
            child: Text(
              question,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            answer,
            style: const TextStyle(fontSize: 14, height: 1.6, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
