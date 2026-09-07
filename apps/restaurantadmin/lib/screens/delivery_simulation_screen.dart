import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fmap;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Delivery Route Simulation Screen
/// Runs the solver with synthetic orders and visualizes the result on a map.
/// Can operate client-side (haversine) or call the simulate-delivery edge function.
class DeliverySimulationScreen extends StatefulWidget {
  final SupabaseClient supabaseClient;

  const DeliverySimulationScreen({super.key, required this.supabaseClient});

  @override
  State<DeliverySimulationScreen> createState() =>
      _DeliverySimulationScreenState();
}

class _DeliverySimulationScreenState extends State<DeliverySimulationScreen>
    with SingleTickerProviderStateMixin {
  // Restaurant: Minnesheimstraße 5, 5023 Salzburg
  static const double _restaurantLat = 47.81328;
  static const double _restaurantLng = 13.06882;

  // Controls
  int _numOrders = 8;
  int _numDrivers = 2;
  bool _useRealShifts = false;
  TimeOfDay _shiftTime = const TimeOfDay(hour: 19, minute: 0);
  int _seed = 42;
  double _lateWeight = 10;
  double _earlyWeight = 1;
  double _driveWeight = 0.5;

  // State
  bool _isRunning = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  // Map
  final fmap.MapController _mapController = fmap.MapController();

  // Colors per driver
  static const List<Color> _driverColors = [
    Color(0xFFE53935), // Red
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Orange
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
  ];

  // Custom orders
  final List<Map<String, dynamic>> _customOrders = [];
  bool _useCustomOrders = false;

  // Animation
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _runSimulation() async {
    setState(() {
      _isRunning = true;
      _errorMessage = null;
    });

    try {
      final body = <String, dynamic>{
        'num_orders': _numOrders,
        'seed': _seed,
        'weight_overrides': {
          'late_weight': _lateWeight,
          'early_weight': _earlyWeight,
          'drive_weight': _driveWeight,
        },
      };

      if (_useRealShifts) {
        final now = DateTime.now();
        final targetDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          _shiftTime.hour,
          _shiftTime.minute,
        );
        body['target_time'] = targetDateTime.toIso8601String();
      } else {
        body['num_drivers'] = _numDrivers;
      }

      if (_useCustomOrders && _customOrders.isNotEmpty) {
        body['custom_orders'] = _customOrders;
        body.remove('num_orders');
      }

      final response = await widget.supabaseClient.functions.invoke(
        'simulate-delivery',
        body: body,
      );

      if (response.status != 200) {
        throw Exception('Server error: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _result = data;
          _isRunning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isRunning = false;
        });
      }
    }
  }

  void _addCustomOrder() {
    final nameController = TextEditingController();
    final latController =
        TextEditingController(text: '47.81');
    final lngController =
        TextEditingController(text: '13.06');
    final targetController = TextEditingController(text: '25');
    final prepController = TextEditingController(text: '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_location, color: Colors.blue[600]),
            const SizedBox(width: 8),
            const Text('Add Simulated Order'),
          ],
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Customer Name',
                  hintText: 'e.g. Test Nonntal',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: targetController,
                decoration: InputDecoration(
                  labelText: 'Target delivery (min from now)',
                  hintText: 'e.g. 25',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: prepController,
                decoration: InputDecoration(
                  labelText: 'Prep time (min from now, empty = ready)',
                  hintText: 'e.g. 5 (or leave empty)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final name = nameController.text.trim().isEmpty
                  ? 'Custom #${_customOrders.length + 1}'
                  : nameController.text.trim();
              final lat = double.tryParse(latController.text) ?? 47.81;
              final lng = double.tryParse(lngController.text) ?? 13.06;
              final target = int.tryParse(targetController.text) ?? 25;
              final prep = int.tryParse(prepController.text);

              setState(() {
                _customOrders.add({
                  'name': name,
                  'lat': lat,
                  'lng': lng,
                  'target_minutes_from_now': target,
                  if (prep != null) 'prep_minutes_from_now': prep,
                });
                _useCustomOrders = true;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Add Order'),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Route Simulation',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(() => _result = null),
              tooltip: 'Reset',
            ),
        ],
      ),
      body: _result == null ? _buildSetupView() : _buildResultsView(),
    );
  }

  // ============================================================
  // SETUP VIEW
  // ============================================================

  Widget _buildSetupView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.science, color: Colors.white, size: 28),
                    SizedBox(width: 12),
                    Text(
                      'Route Solver Simulation',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Generate random orders in Salzburg and watch the solver optimize delivery routes for your drivers in real-time.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Controls
          _buildControlCard(),

          const SizedBox(height: 16),

          // Weight tuning
          _buildWeightsCard(),

          const SizedBox(height: 16),

          // Custom orders
          _buildCustomOrdersCard(),

          const SizedBox(height: 24),

          // Run button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRunning ? null : _runSimulation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 4,
              ),
              child: _isRunning
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Running Solver...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.play_arrow, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Run Simulation',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),

          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[900]!.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[400]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, color: Colors.blue[300], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Simulation Parameters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Orders slider
          _buildSliderRow(
            label: 'Orders',
            value: _numOrders.toDouble(),
            min: 1,
            max: 20,
            divisions: 19,
            icon: Icons.receipt_long,
            color: Colors.amber,
            suffix: _numOrders == 1 ? 'order' : 'orders',
            enabled: !_useCustomOrders,
            onChanged: (v) => setState(() => _numOrders = v.round()),
          ),

          const SizedBox(height: 16),

          // Driver mode toggle: Synthetic count vs Real roster at time
          Row(
            children: [
              Icon(Icons.badge, size: 18, color: Colors.green[400]),
              const SizedBox(width: 8),
              Text(
                'Drivers Pool',
                style: TextStyle(
                  color: Colors.grey[300],
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('Count', style: TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('On-Shift', style: TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_useRealShifts},
                onSelectionChanged: (set) {
                  setState(() => _useRealShifts = set.first);
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (!_useRealShifts)
            // Drivers slider
            _buildSliderRow(
              label: 'Drivers',
              value: _numDrivers.toDouble(),
              min: 1,
              max: 6,
              divisions: 5,
              icon: Icons.local_shipping,
              color: Colors.green,
              suffix: _numDrivers == 1 ? 'driver' : 'drivers',
              onChanged: (v) => setState(() => _numDrivers = v.round()),
            )
          else
            // Time picker for roster shift
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: Colors.green[300]),
                  const SizedBox(width: 8),
                  Text(
                    'Query active roster at:',
                    style: TextStyle(color: Colors.grey[300], fontSize: 12),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _shiftTime,
                      );
                      if (picked != null) {
                        setState(() => _shiftTime = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green[900]?.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green),
                      ),
                      child: Text(
                        '${_shiftTime.hour.toString().padLeft(2, '0')}:${_shiftTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Seed
          _buildSliderRow(
            label: 'Seed',
            value: _seed.toDouble(),
            min: 1,
            max: 100,
            divisions: 99,
            icon: Icons.casino,
            color: Colors.purple,
            suffix: '',
            onChanged: (v) => setState(() => _seed = v.round()),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required IconData icon,
    required Color color,
    required String suffix,
    bool enabled = true,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: TextStyle(
              color: enabled ? Colors.grey[300] : Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: enabled ? color : Colors.grey[700],
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: enabled ? color : Colors.grey[600],
              overlayColor: color.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: enabled ? onChanged : null,
            ),
          ),
        ),
        SizedBox(
          width: 65,
          child: Text(
            '${value.round()} $suffix',
            style: TextStyle(
              color: enabled ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.balance, color: Colors.orange[300], size: 20),
              const SizedBox(width: 8),
              const Text(
                'Cost Function Weights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Adjust how the solver prioritizes lateness, earliness, and driving efficiency.',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),

          _buildWeightSlider(
            label: 'Late penalty',
            value: _lateWeight,
            min: 0,
            max: 30,
            color: Colors.red[400]!,
            onChanged: (v) => setState(() => _lateWeight = v),
          ),
          const SizedBox(height: 10),
          _buildWeightSlider(
            label: 'Early penalty',
            value: _earlyWeight,
            min: 0,
            max: 10,
            color: Colors.blue[400]!,
            onChanged: (v) => setState(() => _earlyWeight = v),
          ),
          const SizedBox(height: 10),
          _buildWeightSlider(
            label: 'Drive cost',
            value: _driveWeight,
            min: 0,
            max: 5,
            color: Colors.teal[400]!,
            onChanged: (v) => setState(() => _driveWeight = v),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: color,
              inactiveTrackColor: const Color(0xFF334155),
              thumbColor: color,
              trackHeight: 3,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(1),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildCustomOrdersCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_location_alt, color: Colors.cyan[300], size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Custom Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_customOrders.isNotEmpty)
                Switch(
                  value: _useCustomOrders,
                  onChanged: (v) => setState(() => _useCustomOrders = v),
                  activeColor: Colors.cyan,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _customOrders.isEmpty
                ? 'Add custom orders with specific coordinates and target times, or use random generation.'
                : '${_customOrders.length} custom order${_customOrders.length == 1 ? '' : 's'} configured',
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          if (_customOrders.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._customOrders.asMap().entries.map((entry) {
              final idx = entry.key;
              final order = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: Colors.cyan[300],
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${order['name']} — target: +${order['target_minutes_from_now']}min'
                        '${order['prep_minutes_from_now'] != null ? ' (prep: +${order['prep_minutes_from_now']}min)' : ' (ready)'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: Colors.red, size: 16),
                      onPressed: () {
                        setState(() {
                          _customOrders.removeAt(idx);
                          if (_customOrders.isEmpty) {
                            _useCustomOrders = false;
                          }
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addCustomOrder,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Custom Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyan[300],
                side: BorderSide(color: Colors.cyan[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULTS VIEW
  // ============================================================

  Widget _buildResultsView() {
    if (_result == null) return const SizedBox.shrink();

    final stats = _result!['stats'] as Map<String, dynamic>? ?? {};
    final routes = (_result!['routes'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final orders = (_result!['orders'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final restaurant = _result!['simulation']?['restaurant'] as Map<String, dynamic>? ??
        {'lat': _restaurantLat, 'lng': _restaurantLng};

    return Column(
      children: [
        // Stats bar
        _buildStatsBar(stats),

        // Main content
        Expanded(
          child: Row(
            children: [
              // Map
              Expanded(
                flex: 3,
                child: _buildMapView(routes, orders, restaurant),
              ),

              // Route details panel
              SizedBox(
                width: 360,
                child: _buildRouteDetailsPanel(routes, stats),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsBar(Map<String, dynamic> stats) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
      ),
      child: Row(
        children: [
          _buildStatChip(
            'Solver',
            '${stats['solver_time_ms'] ?? 0}ms',
            Icons.speed,
            Colors.blue,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Routes',
            '${stats['routes_created'] ?? 0}',
            Icons.route,
            Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Avg Late',
            '${(stats['avg_lateness_min'] as num? ?? 0).toStringAsFixed(1)}m',
            Icons.schedule,
            (stats['avg_lateness_min'] as num? ?? 0) > 0
                ? Colors.orange
                : Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Max Late',
            '${(stats['max_lateness_min'] as num? ?? 0).toStringAsFixed(1)}m',
            Icons.warning_amber,
            (stats['max_lateness_min'] as num? ?? 0) > 5
                ? Colors.red
                : Colors.green,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Driving',
            '${(stats['total_driving_min'] as num? ?? 0).toStringAsFixed(0)}m',
            Icons.directions_car,
            Colors.teal,
          ),
          const SizedBox(width: 12),
          _buildStatChip(
            'Cost',
            '${(stats['total_cost'] as num? ?? 0).toStringAsFixed(0)}',
            Icons.analytics,
            Colors.purple,
          ),
          const Spacer(),
          if ((stats['unassigned_count'] as num? ?? 0) > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red[900]!.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[400]!),
              ),
              child: Text(
                '${stats['unassigned_count']} unassigned!',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _runSimulation,
            icon: const Icon(Icons.replay, size: 16),
            label: const Text('Re-run'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              textStyle: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMapView(
    List<Map<String, dynamic>> routes,
    List<Map<String, dynamic>> orders,
    Map<String, dynamic> restaurant,
  ) {
    final restaurantLat = (restaurant['lat'] as num?)?.toDouble() ?? _restaurantLat;
    final restaurantLng = (restaurant['lng'] as num?)?.toDouble() ?? _restaurantLng;

    // Build markers
    final markers = <fmap.Marker>[];

    // Restaurant marker
    markers.add(
      fmap.Marker(
        point: latlong.LatLng(restaurantLat, restaurantLng),
        width: 44,
        height: 44,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.restaurant, color: Colors.red, size: 24),
          ),
        ),
      ),
    );

    // Order markers — color by assigned driver
    final orderDriverMap = <String, int>{}; // orderId → driverIndex
    for (int rIdx = 0; rIdx < routes.length; rIdx++) {
      final stops = (routes[rIdx]['stops'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final stop in stops) {
        final oid = stop['order_id'] as String?;
        if (oid != null) {
          orderDriverMap[oid] = rIdx;
        }
      }
    }

    for (final order in orders) {
      final loc = order['location'] as Map<String, dynamic>?;
      if (loc == null) continue;
      final lat = (loc['lat'] as num?)?.toDouble();
      final lng = (loc['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;

      final oid = order['id'] as String? ?? '';
      final driverIdx = orderDriverMap[oid];
      final isAssigned = driverIdx != null;
      final color = isAssigned
          ? _driverColors[driverIdx % _driverColors.length]
          : Colors.grey;
      final isReady = order['is_ready'] as bool? ?? true;

      markers.add(
        fmap.Marker(
          point: latlong.LatLng(lat, lng),
          width: 36,
          height: 36,
          child: Tooltip(
            message:
                '${order['customer_name'] ?? oid}\n${isReady ? "Ready" : "Preparing"}\nTarget: ${_formatTime(order['target_time'] as String?)}',
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isReady ? Colors.white : Colors.amber,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  oid.replaceAll('SIM-', ''),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Build polylines per route
    final polylines = <fmap.Polyline>[];
    for (int rIdx = 0; rIdx < routes.length; rIdx++) {
      final allStops =
          (routes[rIdx]['all_stops'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      if (allStops.isEmpty) continue;

      final color = _driverColors[rIdx % _driverColors.length];
      final points = <latlong.LatLng>[];

      for (final stop in allStops) {
        final loc = stop['location'] as Map<String, dynamic>?;
        if (loc == null) continue;
        final lat = (loc['lat'] as num?)?.toDouble();
        final lng = (loc['lng'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;
        points.add(latlong.LatLng(lat, lng));
      }

      if (points.length >= 2) {
        polylines.add(
          fmap.Polyline(
            points: points,
            color: color.withOpacity(0.8),
            strokeWidth: 4,
          ),
        );
      }
    }

    return fmap.FlutterMap(
      mapController: _mapController,
      options: fmap.MapOptions(
        initialCenter: latlong.LatLng(restaurantLat, restaurantLng),
        initialZoom: 13.0,
      ),
      children: [
        fmap.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.pixelscale.restaurantadmin',
        ),
        fmap.PolylineLayer(polylines: polylines),
        fmap.MarkerLayer(markers: markers),
      ],
    );
  }

  Widget _buildRouteDetailsPanel(
    List<Map<String, dynamic>> routes,
    Map<String, dynamic> stats,
  ) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(left: BorderSide(color: Color(0xFF334155))),
      ),
      child: Column(
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: Color(0xFF334155))),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Route Details',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${routes.length} routes',
                    style: const TextStyle(
                      color: Color(0xFF22C55E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Route list
          Expanded(
            child: routes.isEmpty
                ? Center(
                    child: Text(
                      'No routes generated',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: routes.length,
                    itemBuilder: (context, rIdx) {
                      final route = routes[rIdx];
                      final color =
                          _driverColors[rIdx % _driverColors.length];
                      final stops = (route['stops'] as List?)
                              ?.cast<Map<String, dynamic>>() ??
                          [];
                      final driverName =
                          route['driver_name'] as String? ?? 'Driver ?';
                      final departure = route['departure'] as String?;
                      final returnTime =
                          route['return_time'] as String?;
                      final drivingMin = (route['total_driving_minutes']
                                  as num?)
                              ?.toDouble() ??
                          0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: color.withOpacity(0.3), width: 1.5),
                        ),
                        child: Column(
                          children: [
                            // Route header
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Icon(
                                        Icons.local_shipping,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          driverName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          '${stops.length} stops • ${drivingMin.toStringAsFixed(0)} min driving',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatTime(departure),
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 10,
                                        ),
                                      ),
                                      Text(
                                        '→ ${_formatTime(returnTime)}',
                                        style: TextStyle(
                                          color: Colors.grey[400],
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Stops list
                            ...stops.asMap().entries.map((entry) {
                              final sIdx = entry.key;
                              final stop = entry.value;
                              final isLate =
                                  (stop['lateness_min'] as num? ?? 0) >
                                      0.5;
                              final lateness =
                                  (stop['lateness_min'] as num?)
                                          ?.toDouble() ??
                                      0;
                              final isReady =
                                  stop['is_ready'] as bool? ?? true;

                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: sIdx < stops.length - 1
                                        ? const BorderSide(
                                            color: Color(0xFF1E293B))
                                        : BorderSide.none,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    // Sequence number
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${sIdx + 1}',
                                          style: TextStyle(
                                            color: color,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  stop['customer_name'] as String? ??
                                                      stop['order_id'] as String? ??
                                                      '?',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                  overflow: TextOverflow
                                                      .ellipsis,
                                                ),
                                              ),
                                              if (!isReady) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 4,
                                                      vertical: 1),
                                                  decoration:
                                                      BoxDecoration(
                                                    color: Colors
                                                        .amber[900]!
                                                        .withOpacity(
                                                            0.3),
                                                    borderRadius:
                                                        BorderRadius
                                                            .circular(3),
                                                  ),
                                                  child: const Text(
                                                    'PREP',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.amber,
                                                      fontSize: 8,
                                                      fontWeight:
                                                          FontWeight
                                                              .bold,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'ETA ${_formatTime(stop['planned_arrival'] as String?)} • Target ${_formatTime(stop['target_time'] as String?)}',
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isLate)
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.red[900]!
                                              .withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '+${lateness.toStringAsFixed(0)}m',
                                          style: const TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 6,
                                            vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green[900]!
                                              .withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'On time',
                                          style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatTime(String? isoString) {
    if (isoString == null) return '—';
    try {
      final dt = DateTime.parse(isoString).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '—';
    }
  }
}
