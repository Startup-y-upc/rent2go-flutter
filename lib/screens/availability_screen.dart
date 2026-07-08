import 'package:flutter/material.dart';
import '../models/vehicle_models.dart';
import '../services/vehicle_service.dart';
import '../services/auth_service.dart';
import '../widgets/common_widgets.dart';

/// US13 (definir disponibilidad) / US15 (consultar disponibilidad) — Owner.
/// Permite al propietario ver los rangos de fechas bloqueados/reservados de
/// un vehículo propio y bloquear manualmente nuevos rangos (mantenimiento,
/// uso personal), consumiendo los 3 endpoints de AvailabilityController que
/// hasta ahora no tenían ningún cliente.
class AvailabilityScreen extends StatefulWidget {
  final VehicleData vehicle;
  const AvailabilityScreen({super.key, required this.vehicle});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  List<AvailabilityBlock> _blocks = [];
  bool _loading = true;
  bool _saving = false;
  String? _errorMsg;
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final blocks = await VehicleService.getAvailabilityBlocks(widget.vehicle.id);
      if (mounted) setState(() { _blocks = blocks; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _errorMsg = 'No se pudo cargar la disponibilidad.'; });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _selectedRange,
    );
    if (picked != null) setState(() => _selectedRange = picked);
  }

  Future<void> _blockRange() async {
    if (_selectedRange == null) return;
    setState(() => _saving = true);
    try {
      final user = await AuthService.getCurrentUser();
      await VehicleService.blockAvailability(
        vehicleId: widget.vehicle.id,
        startDate: _selectedRange!.start,
        endDate: _selectedRange!.end,
        requestedBy: user?.userId ?? 0,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rango bloqueado correctamente')),
        );
        setState(() { _selectedRange = null; _saving = false; });
        _load();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _unblock(AvailabilityBlock block) async {
    try {
      await VehicleService.unblockAvailabilityRange(
        vehicleId: widget.vehicle.id,
        startDate: block.startDate,
        endDate: block.endDate,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rango liberado')),
        );
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo liberar el rango.')),
        );
      }
    }
  }

  String _fmt(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD9E5E3),
        elevation: 0,
        foregroundColor: Colors.black,
        title: Text('Disponibilidad · ${widget.vehicle.make} ${widget.vehicle.model}',
            style: const TextStyle(fontSize: 16, color: Colors.black)),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  key: const Key('block_range_card'),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Bloquear un rango de fechas',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                      const SizedBox(height: 4),
                      const Text('Usa esto para mantenimiento o uso personal del vehículo.',
                          style: TextStyle(color: Colors.black54, fontSize: 12)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        key: const Key('pick_range_button'),
                        onPressed: _pickRange,
                        icon: const Icon(Icons.date_range_outlined, size: 18),
                        label: Text(_selectedRange == null
                            ? 'Elegir rango de fechas'
                            : '${_fmt(_selectedRange!.start)} - ${_fmt(_selectedRange!.end)}'),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('confirm_block_button'),
                          onPressed: _selectedRange == null || _saving ? null : _blockRange,
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                          child: _saving
                              ? const SizedBox(height: 18, width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Bloquear fechas'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Fechas bloqueadas / reservadas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                const SizedBox(height: 10),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: kCyan))
                      : _errorMsg != null
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_errorMsg!, style: TextStyle(color: Colors.grey[600])),
                                  const SizedBox(height: 8),
                                  TextButton(onPressed: _load, child: const Text('Reintentar')),
                                ],
                              ),
                            )
                          : _blocks.isEmpty
                              ? const Center(
                                  key: Key('availability_empty_state'),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.event_available_outlined, size: 40, color: Colors.black26),
                                      SizedBox(height: 8),
                                      Text('Este vehículo está disponible en todas las fechas',
                                          style: TextStyle(color: Colors.black54)),
                                    ],
                                  ),
                                )
                              : ListView.separated(
                                  key: const Key('availability_blocks_list'),
                                  itemCount: _blocks.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                                  itemBuilder: (_, i) {
                                    final b = _blocks[i];
                                    return Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.block, color: Colors.redAccent, size: 18),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text('${_fmt(b.startDate)} — ${_fmt(b.endDate)}',
                                                style: const TextStyle(color: Colors.black87, fontSize: 13)),
                                          ),
                                          TextButton(
                                            onPressed: () => _unblock(b),
                                            child: const Text('Liberar', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
