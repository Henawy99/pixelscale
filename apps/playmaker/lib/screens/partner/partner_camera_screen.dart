import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:playmakerappstart/models/footballfield_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PartnerCameraScreen extends StatefulWidget {
  final FootballField field;

  const PartnerCameraScreen({Key? key, required this.field}) : super(key: key);

  @override
  State<PartnerCameraScreen> createState() => _PartnerCameraScreenState();
}

class _PartnerCameraScreenState extends State<PartnerCameraScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _schedules = [];
  Map<String, List<Map<String, dynamic>>> _chunksData = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  StreamSubscription? _schedulesSubscription;
  StreamSubscription? _chunksSubscription;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupRealtime();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_hasActiveRecordings()) {
        _loadData();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _schedulesSubscription?.cancel();
    _chunksSubscription?.cancel();
    super.dispose();
  }

  bool _hasActiveRecordings() {
    return _schedules.any((s) =>
        s['status'] == 'recording' ||
        s['status'] == 'processing' ||
        s['status'] == 'uploading');
  }

  void _setupRealtime() {
    _schedulesSubscription = _supabase
        .from('camera_recording_schedules')
        .stream(primaryKey: ['id'])
        .eq('field_id', widget.field.id)
        .listen((data) {
          if (mounted) _loadSchedules();
        });

    _chunksSubscription = _supabase
        .from('camera_recording_chunks')
        .stream(primaryKey: ['id'])
        .listen((data) {
          if (mounted) _updateChunksData(data);
        });
  }

  Future<void> _loadData() async {
    await _loadSchedules();
    await _loadChunksData();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadSchedules() async {
    try {
      final data = await _supabase
          .from('camera_recording_schedules')
          .select('*')
          .eq('field_id', widget.field.id)
          .order('created_at', ascending: false)
          .limit(30);
      if (mounted) {
        setState(() {
          _schedules = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      print('Error loading schedules: $e');
    }
  }

  Future<void> _loadChunksData() async {
    try {
      final ids = _schedules.map((s) => s['id'] as String).toList();
      if (ids.isEmpty) return;
      final data = await _supabase
          .from('camera_recording_chunks')
          .select('*')
          .inFilter('schedule_id', ids);
      if (data != null) {
        _updateChunksData(List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      print('Error loading chunks: $e');
    }
  }

  void _updateChunksData(List<Map<String, dynamic>> chunks) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final chunk in chunks) {
      final sid = chunk['schedule_id'] as String?;
      if (sid != null) {
        grouped.putIfAbsent(sid, () => []).add(chunk);
      }
    }
    if (mounted) setState(() => _chunksData = grouped);
  }

  double _calculateProgress(Map<String, dynamic> schedule) {
    final sid = schedule['id'];
    final totalChunks = schedule['total_chunks'] as int? ?? 1;
    final chunks = _chunksData[sid] ?? [];
    if (schedule['status'] == 'completed') return 1.0;
    if (chunks.isEmpty) return 0.0;
    final done = chunks.where((c) =>
        c['gpu_status'] == 'completed' || c['processed_url'] != null).length;
    return (done / totalChunks).clamp(0.0, 1.0);
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'scheduled': return 'Scheduled';
      case 'recording': return '🔴 Recording…';
      case 'uploading': return '⬆ Uploading…';
      case 'processing': return '⚙ Processing…';
      case 'gpu_processing': return '🤖 AI Processing…';
      case 'completed': return '✅ Ready';
      case 'failed': return '❌ Failed';
      case 'cancelled': return 'Cancelled';
      default: return status.toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'scheduled': return Colors.blue;
      case 'recording': return Colors.red;
      case 'uploading': return Colors.orange;
      case 'processing':
      case 'gpu_processing': return Colors.purple;
      case 'completed': return Colors.green;
      case 'failed': return Colors.red.shade300;
      default: return Colors.black45;
    }
  }

  // ────────────────────────────────────────────────────────────
  // SIMPLE SCHEDULE DIALOG
  // ────────────────────────────────────────────────────────────
  Future<void> _showScheduleDialog() async {
    final now = DateTime.now();
    DateTime startTime = now;
    DateTime endTime = now.add(const Duration(hours: 1));
    bool isCreating = false;

    await showDialog(
      context: context,
      barrierDismissible: !isCreating,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> pickStart() async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: startTime,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (d == null) return;
            final t = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(startTime),
            );
            if (t == null) return;
            setDialogState(() {
              startTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
              if (endTime.isBefore(startTime)) {
                endTime = startTime.add(const Duration(hours: 1));
              }
            });
          }

          Future<void> pickEnd() async {
            final d = await showDatePicker(
              context: ctx,
              initialDate: endTime,
              firstDate: DateTime.now().subtract(const Duration(days: 1)),
              lastDate: DateTime.now().add(const Duration(days: 30)),
            );
            if (d == null) return;
            final t = await showTimePicker(
              context: ctx,
              initialTime: TimeOfDay.fromDateTime(endTime),
            );
            if (t == null) return;
            setDialogState(() {
              endTime = DateTime(d.year, d.month, d.day, t.hour, t.minute);
            });
          }

          Future<void> create() async {
            if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('End time must be after start time')),
              );
              return;
            }
            setDialogState(() => isCreating = true);
            try {
              final durationMinutes = endTime.difference(startTime).inMinutes;
              await _supabase.from('camera_recording_schedules').insert({
                'field_id': widget.field.id,
                'scheduled_date': DateFormat('yyyy-MM-dd').format(startTime),
                'start_time': startTime.toUtc().toIso8601String(),
                'end_time': endTime.toUtc().toIso8601String(),
                'status': 'scheduled',
                'enable_ball_tracking': true, // default on
                'show_field_mask': false,
                'show_red_ball': false,
                'total_chunks': (durationMinutes / 10).ceil().clamp(1, 100),
                'chunk_duration_minutes': 10,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Recording scheduled!'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadData();
              }
            } catch (e) {
              setDialogState(() => isCreating = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            }
          }

          final fmt = (DateTime dt) =>
              DateFormat('EEE, MMM d  HH:mm').format(dt);

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00BF63).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.videocam, color: Color(0xFF00BF63)),
                ),
                const SizedBox(width: 12),
                Text('Schedule Recording',
                    style: GoogleFonts.inter(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TimePickerTile(
                    label: 'Start Time',
                    value: fmt(startTime),
                    icon: Icons.play_arrow_rounded,
                    iconColor: Colors.green,
                    onTap: isCreating ? null : pickStart,
                  ),
                  const SizedBox(height: 12),
                  _TimePickerTile(
                    label: 'End Time',
                    value: fmt(endTime),
                    icon: Icons.stop_rounded,
                    iconColor: Colors.red,
                    onTap: isCreating ? null : pickEnd,
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue.shade600),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Duration: ${endTime.difference(startTime).inMinutes} min  •  '
                            '${(endTime.difference(startTime).inMinutes / 10).ceil()} chunk(s)',
                            style: GoogleFonts.inter(
                                fontSize: 12, color: Colors.blue.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isCreating ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isCreating ? null : create,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00BF63),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: isCreating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Schedule'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Camera Recordings',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleDialog,
        backgroundColor: const Color(0xFF00BF63),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.videocam_rounded),
        label: Text('Schedule', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _schedules.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off_outlined,
                              size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'No recording jobs yet',
                            style: GoogleFonts.inter(
                                fontSize: 16, color: Colors.grey.shade600),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Tap "Schedule" to create your first recording.',
                            style: GoogleFonts.inter(
                                fontSize: 13, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final job = _schedules[index];
                        return _buildJobCard(job);
                      },
                    ),
            ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final progress = _calculateProgress(job);
    final status = job['status'] as String? ?? 'unknown';
    final startTime = DateTime.tryParse(job['start_time'] ?? '')?.toLocal();
    final endTime = DateTime.tryParse(job['end_time'] ?? '')?.toLocal();
    final videoUrl = job['final_video_url'] ?? job['merged_video_url'];
    final statusColor = _getStatusColor(status);

    String timeRange = 'Unknown Date';
    if (startTime != null && endTime != null) {
      final dateStr = DateFormat('EEE, MMM d').format(startTime);
      final s = DateFormat('HH:mm').format(startTime);
      final e = DateFormat('HH:mm').format(endTime);
      timeRange = '$dateStr  •  $s – $e';
    } else if (startTime != null) {
      timeRange = DateFormat('EEE, MMM d • HH:mm').format(startTime);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(timeRange,
                          style: GoogleFonts.inter(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        'ID: ${job['id'].toString().substring(0, 8)}',
                        style: GoogleFonts.inter(
                            fontSize: 11, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getStatusText(status),
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ),
              ],
            ),
            if (status != 'completed' &&
                status != 'cancelled' &&
                status != 'failed') ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${(progress * 100).toInt()}%',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade500),
              ),
            ],
            if (status == 'completed' && videoUrl != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: videoUrl));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Video link copied!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Video Link'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BF63),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Simple helper tile for time selection
class _TimePickerTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: GoogleFonts.inter(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}
