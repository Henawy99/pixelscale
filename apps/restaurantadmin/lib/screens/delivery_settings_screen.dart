import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DeliverySettingsScreen extends StatefulWidget {
  const DeliverySettingsScreen({super.key});

  @override
  State<DeliverySettingsScreen> createState() => _DeliverySettingsScreenState();
}

class _DeliverySettingsScreenState extends State<DeliverySettingsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _settings;

  // Cost weights
  double _lateWeight = 10;
  double _earlyWeight = 1;
  double _driveWeight = 0.5;
  double _idleWeight = 2;
  double _unassignedWeight = 50;

  // Timing parameters
  int _handoverTimeSecs = 300;
  int _earlyGraceSecs = 600;
  int _bundlingWaitSecs = 240;
  int _planningHorizonSecs = 2700;

  // Solver limits
  int _maxRouteDurationSecs = 3600;
  int _solverTimeLimitMs = 200;
  int _exhaustiveThreshold = 6;
  int _maxStopsPerRoute = 3;
  int _autoAssignDelaySecs = 60;
  double _citySpeedKmh = 25;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final response = await _supabase
          .from('delivery_settings')
          .select('*')
          .limit(1);

      final list = response as List;
      if (list.isNotEmpty) {
        final s = Map<String, dynamic>.from(list.first as Map);
        setState(() {
          _settings = s;
          _lateWeight = (s['late_weight'] as num?)?.toDouble() ?? 10;
          _earlyWeight = (s['early_weight'] as num?)?.toDouble() ?? 1;
          _driveWeight = (s['drive_weight'] as num?)?.toDouble() ?? 0.5;
          _idleWeight = (s['idle_weight'] as num?)?.toDouble() ?? 2;
          _unassignedWeight = (s['unassigned_weight'] as num?)?.toDouble() ?? 50;
          _handoverTimeSecs = (s['handover_time_secs'] as num?)?.toInt() ?? 300;
          _earlyGraceSecs = (s['early_grace_secs'] as num?)?.toInt() ?? 600;
          _bundlingWaitSecs = (s['bundling_wait_secs'] as num?)?.toInt() ?? 240;
          _planningHorizonSecs = (s['planning_horizon_secs'] as num?)?.toInt() ?? 2700;
          _maxRouteDurationSecs = (s['max_route_duration_secs'] as num?)?.toInt() ?? 3600;
          _solverTimeLimitMs = (s['solver_time_limit_ms'] as num?)?.toInt() ?? 200;
          _exhaustiveThreshold = (s['exhaustive_threshold'] as num?)?.toInt() ?? 6;
          _maxStopsPerRoute = (s['max_stops_per_route'] as num?)?.toInt() ?? 3;
          _autoAssignDelaySecs = (s['auto_assign_delay_secs'] as num?)?.toInt() ?? 60;
          _citySpeedKmh = (s['city_speed_kmh'] as num?)?.toDouble() ?? 25;
        });
      }
    } catch (e) {
      debugPrint('[DeliverySettings] Error loading: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_settings == null) return;
    setState(() => _isSaving = true);

    try {
      await _supabase
          .from('delivery_settings')
          .update({
            'late_weight': _lateWeight,
            'early_weight': _earlyWeight,
            'drive_weight': _driveWeight,
            'idle_weight': _idleWeight,
            'unassigned_weight': _unassignedWeight,
            'handover_time_secs': _handoverTimeSecs,
            'early_grace_secs': _earlyGraceSecs,
            'bundling_wait_secs': _bundlingWaitSecs,
            'planning_horizon_secs': _planningHorizonSecs,
            'max_route_duration_secs': _maxRouteDurationSecs,
            'solver_time_limit_ms': _solverTimeLimitMs,
            'exhaustive_threshold': _exhaustiveThreshold,
            'max_stops_per_route': _maxStopsPerRoute,
            'auto_assign_delay_secs': _autoAssignDelaySecs,
            'city_speed_kmh': _citySpeedKmh,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _settings!['id'] as String);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Settings saved! Changes apply on next replan.'),
              ],
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('[DeliverySettings] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Delivery Planner Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2D3748),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_isLoading)
            TextButton.icon(
              onPressed: _isSaving ? null : _saveSettings,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save, color: Colors.white),
              label: Text(
                _isSaving ? 'Saving...' : 'Save',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _settings == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings_suggest, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No delivery settings found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Run the database migration first',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cost Weights Section
                      _buildSectionHeader(
                        'Cost Function Weights',
                        'Controls how the solver prioritizes different goals.',
                        Icons.tune,
                        Colors.blue,
                      ),
                      const SizedBox(height: 8),
                      _buildSliderCard(
                        'Late Delivery Penalty',
                        'Higher = harder penalties for late deliveries',
                        _lateWeight,
                        0,
                        50,
                        (v) => setState(() => _lateWeight = v),
                        icon: Icons.warning_amber,
                        color: Colors.red,
                      ),
                      _buildSliderCard(
                        'Early Delivery Penalty',
                        'Higher = avoid arriving too early',
                        _earlyWeight,
                        0,
                        20,
                        (v) => setState(() => _earlyWeight = v),
                        icon: Icons.schedule,
                        color: Colors.orange,
                      ),
                      _buildSliderCard(
                        'Driving Time Penalty',
                        'Higher = prefer shorter routes',
                        _driveWeight,
                        0,
                        10,
                        (v) => setState(() => _driveWeight = v),
                        icon: Icons.directions_car,
                        color: Colors.blue,
                      ),
                      _buildSliderCard(
                        'Idle Time Penalty',
                        'Higher = avoid drivers waiting at store',
                        _idleWeight,
                        0,
                        20,
                        (v) => setState(() => _idleWeight = v),
                        icon: Icons.hourglass_empty,
                        color: Colors.purple,
                      ),
                      _buildSliderCard(
                        'Unassigned Order Penalty',
                        'Higher = always assign orders even if late',
                        _unassignedWeight,
                        0,
                        100,
                        (v) => setState(() => _unassignedWeight = v),
                        icon: Icons.assignment_late,
                        color: Colors.red,
                      ),

                      const SizedBox(height: 24),

                      // Timing Section
                      _buildSectionHeader(
                        'Timing Parameters',
                        'How long each action takes in the plan.',
                        Icons.timer,
                        Colors.green,
                      ),
                      const SizedBox(height: 8),
                      _buildIntCard(
                        'Handover Time',
                        'Time spent at each customer door (seconds)',
                        _handoverTimeSecs,
                        60,
                        900,
                        60,
                        (v) => setState(() => _handoverTimeSecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),
                      _buildIntCard(
                        'Early Grace Period',
                        'How many minutes early is still acceptable',
                        _earlyGraceSecs,
                        0,
                        1800,
                        60,
                        (v) => setState(() => _earlyGraceSecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),
                      _buildIntCard(
                        'Bundling Wait',
                        'Max wait to bundle nearby orders together',
                        _bundlingWaitSecs,
                        0,
                        600,
                        30,
                        (v) => setState(() => _bundlingWaitSecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),
                      _buildIntCard(
                        'Planning Horizon',
                        'How far ahead to look for orders in prep',
                        _planningHorizonSecs,
                        900,
                        7200,
                        300,
                        (v) => setState(() => _planningHorizonSecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),

                      const SizedBox(height: 24),

                      // Solver Section
                      _buildSectionHeader(
                        'Solver Limits',
                        'Controls solver speed vs quality tradeoff.',
                        Icons.memory,
                        Colors.deepPurple,
                      ),
                      const SizedBox(height: 8),
                      _buildIntCard(
                        'Max Route Duration',
                        'Maximum time a driver can be out (seconds)',
                        _maxRouteDurationSecs,
                        1800,
                        7200,
                        300,
                        (v) => setState(() => _maxRouteDurationSecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),
                      _buildIntCard(
                        'Solver Time Limit',
                        'Max time the solver can spend optimizing (ms)',
                        _solverTimeLimitMs,
                        50,
                        2000,
                        50,
                        (v) => setState(() => _solverTimeLimitMs = v),
                        formatSuffix: 'ms',
                      ),
                      _buildIntCard(
                        'Exhaustive Threshold',
                        'Use brute-force if ≤ N unassigned orders',
                        _exhaustiveThreshold,
                        2,
                        10,
                        1,
                        (v) => setState(() => _exhaustiveThreshold = v),
                        formatSuffix: ' orders',
                      ),
                      _buildIntCard(
                        'Max Stops Per Route',
                        'Maximum deliveries per route (food quality)',
                        _maxStopsPerRoute,
                        1,
                        6,
                        1,
                        (v) => setState(() => _maxStopsPerRoute = v),
                        formatSuffix: ' stops',
                      ),
                      _buildIntCard(
                        'Auto-Assign Delay',
                        'Auto-confirm routes after this delay (seconds)',
                        _autoAssignDelaySecs,
                        0,
                        300,
                        10,
                        (v) => setState(() => _autoAssignDelaySecs = v),
                        formatSuffix: 's',
                        displayMinutes: true,
                      ),
                      _buildSliderCard(
                        'City Speed Fallback',
                        'Speed when Distance Matrix API is unavailable (km/h)',
                        _citySpeedKmh,
                        10,
                        60,
                        (v) => setState(() => _citySpeedKmh = v),
                        icon: Icons.speed,
                        color: Colors.teal,
                        decimals: 0,
                        suffix: ' km/h',
                      ),

                      const SizedBox(height: 32),

                      // Save button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveSettings,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_isSaving ? 'Saving...' : 'Save Settings'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2D3748),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSliderCard(
    String title,
    String description,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged, {
    IconData? icon,
    Color color = Colors.blue,
    int decimals = 1,
    String suffix = '',
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${value.toStringAsFixed(decimals)}$suffix',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              description,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                thumbColor: color,
                inactiveTrackColor: color.withValues(alpha: 0.2),
                overlayColor: color.withValues(alpha: 0.1),
                trackHeight: 3,
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntCard(
    String title,
    String description,
    int value,
    int min,
    int max,
    int step,
    ValueChanged<int> onChanged, {
    String formatSuffix = '',
    bool displayMinutes = false,
  }) {
    final displayValue = displayMinutes
        ? '${(value / 60).toStringAsFixed(0)} min ($value$formatSuffix)'
        : '$value$formatSuffix';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 0.5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Stepper buttons
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: value > min ? () => onChanged((value - step).clamp(min, max)) : null,
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.remove,
                        size: 16,
                        color: value > min ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                  ),
                  Container(
                    constraints: const BoxConstraints(minWidth: 70),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    child: Text(
                      displayValue,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  InkWell(
                    onTap: value < max ? () => onChanged((value + step).clamp(min, max)) : null,
                    borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        Icons.add,
                        size: 16,
                        color: value < max ? Colors.grey[700] : Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
