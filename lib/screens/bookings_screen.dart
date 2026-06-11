import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/common_widgets.dart';
import 'explore_screen.dart';

class BookingsScreen extends StatefulWidget {
  const BookingsScreen({super.key});
  @override
  State<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends State<BookingsScreen> {
  int _tab = 1;
  int _filter = 0; // 0=Próximas 1=Activas 2=Pasadas

  final _upcoming = [
    _Booking(
      carName: 'Tesla Model 3',
      carSub: 'Long Range · 2024',
      imageUrl: 'https://images.unsplash.com/photo-1560958089-b8a1929cea89?w=400&q=80',
      pickupDate: '12 May · 10:00',
      returnDate: '14 May · 18:00',
      owner: 'Lucía M.',
      address: 'Calle Goya 24',
      status: 'Próxima',
      total: 123.40,
      isActive: true,
    ),
  ];

  final _past = [
    _Booking(
      carName: 'Mini Cooper S',
      carSub: '',
      imageUrl: 'https://images.unsplash.com/photo-1617469767933-0d27272fb22c?w=400&q=80',
      pickupDate: '28 abr',
      returnDate: '30 abr',
      owner: 'Andrés R.',
      address: '',
      status: 'Completada',
      total: 76,
      isActive: false,
    ),
    _Booking(
      carName: 'Volkswagen Golf',
      carSub: '',
      imageUrl: 'https://images.unsplash.com/photo-1541899481282-d53bffe3c35d?w=400&q=80',
      pickupDate: '12 abr',
      returnDate: '13 abr',
      owner: 'María S.',
      address: '',
      status: 'Completada',
      total: 32,
      isActive: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  const Text('Mis reservas',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.black)),
                  const Spacer(),
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Icon(Icons.calendar_month_outlined,
                        size: 20, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Filtros
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: ['Próximas', 'Activas', 'Pasadas']
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _filter = e.key),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: _filter == e.key
                                      ? Colors.black
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  e.value,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: _filter == e.key
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  if (_filter == 0 || _filter == 1) ...[
                    // Reserva activa/próxima destacada
                    _ActiveBookingCard(booking: _upcoming[0]),
                    const SizedBox(height: 24),
                  ],
                  if (_filter == 0 || _filter == 2) ...[
                    const Text('Anteriores',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.black)),
                    const SizedBox(height: 12),
                    ..._past.map((b) => _PastBookingCard(booking: b)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNav(
          current: _tab, onTap: (i) => setState(() => _tab = i)),
    );
  }
}

// ── Card reserva activa ───────────────────────────────────────────────────────
class _ActiveBookingCard extends StatelessWidget {
  final _Booking booking;
  const _ActiveBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: kCyan.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                            color: kCyan, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    const Text('Próxima',
                        style: TextStyle(
                            color: kCyan,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ]),
                ),
                const Spacer(),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: booking.imageUrl,
                    width: 80,
                    height: 55,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 55,
                        color: Colors.grey[800],
                        child: const Icon(Icons.directions_car,
                            color: Colors.white38)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(booking.carName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(booking.carSub,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _DateChip(label: 'Recoge', date: booking.pickupDate),
                Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: Colors.white24,
                  ),
                ),
                _DateChip(label: 'Devuelve', date: booking.returnDate),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.person, size: 18, color: Colors.white70),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.owner,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    Text(booking.address,
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Abrir',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateChip extends StatelessWidget {
  final String label, date;
  const _DateChip({required this.label, required this.date});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Colors.white38, fontSize: 11)),
      Text(date,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    ],
  );
}

// ── Card reserva pasada ───────────────────────────────────────────────────────
class _PastBookingCard extends StatelessWidget {
  final _Booking booking;
  const _PastBookingCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: booking.imageUrl,
              width: 64,
              height: 48,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                  width: 64,
                  height: 48,
                  color: Colors.grey[200],
                  child: const Icon(Icons.directions_car, color: Colors.grey)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(booking.carName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black)),
                Text(
                  '${booking.pickupDate} — ${booking.returnDate} · ${booking.total.toInt()} €',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

// ── Modelo ────────────────────────────────────────────────────────────────────
class _Booking {
  final String carName, carSub, imageUrl, pickupDate, returnDate;
  final String owner, address, status;
  final double total;
  final bool isActive;
  const _Booking({
    required this.carName,
    required this.carSub,
    required this.imageUrl,
    required this.pickupDate,
    required this.returnDate,
    required this.owner,
    required this.address,
    required this.status,
    required this.total,
    required this.isActive,
  });
}

// ── Bottom nav ────────────────────────────────────────────────────────────────
class _BottomNav extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.current, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.explore_outlined, 'Explorar'),
      (Icons.calendar_today_outlined, 'Reservas'),
      (Icons.chat_bubble_outline, 'Mensajes'),
      (Icons.person_outline, 'Perfil'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: items.asMap().entries.map((e) {
            final active = e.key == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(e.key),
                child: Container(
                  color: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(e.value.$1,
                          color: active ? Colors.black : Colors.grey, size: 22),
                      const SizedBox(height: 4),
                      Text(e.value.$2,
                          style: TextStyle(
                              fontSize: 11,
                              color: active ? Colors.black : Colors.grey)),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}