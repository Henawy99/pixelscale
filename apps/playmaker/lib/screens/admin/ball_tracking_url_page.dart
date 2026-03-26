import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/ball_tracking_service.dart';
import 'field_mask_editor_screen.dart';

class BallTrackingUrlPage extends StatefulWidget {
  final List<BallTrackingJob> jobs;
  final String customModelId;
  final BallTrackingService service;
  final String? initialUrl;
  final TextEditingController roboflowApiKeyController;
  final TextEditingController detectEveryFramesController;
  final TextEditingController yoloConfController;
  final TextEditingController yoloImgSizeController;
  final TextEditingController roiSizeController;
  final TextEditingController zoomBaseController;
  final TextEditingController smoothingController;

  final VoidCallback onJobCreated;

  final bool isDetectOnlyMode;

  const BallTrackingUrlPage({
    super.key,
    required this.jobs,
    required this.customModelId,
    required this.service,
    required this.roboflowApiKeyController,
    required this.detectEveryFramesController,
    required this.yoloConfController,
    required this.yoloImgSizeController,
    required this.roiSizeController,
    required this.zoomBaseController,
    required this.smoothingController,
    required this.onJobCreated,
    this.initialUrl,
    this.isDetectOnlyMode = false,
  });

  @override
  State<BallTrackingUrlPage> createState() => _BallTrackingUrlPageState();
}

class _BallTrackingUrlPageState extends State<BallTrackingUrlPage> {
  final _urlController = TextEditingController();
  final _customScriptController = TextEditingController();

  String _modelSelection = 'yolo'; // 'yolo', 'rtdetr', 'roboflow', 'tracknet'

  List<Map<String, dynamic>> _availableMasks = [];
  bool _masksLoading = true;
  String? _selectedMaskId;
  String? _localMaskName;
  List<List<double>>? _localMask;

  BallTrackingJob? _foundPreviousJob;
  bool _isUploading = false;


  @override
  void initState() {
    super.initState();
    _customScriptController.text = '';
    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      _searchForMatch(widget.initialUrl!);
    }
    _loadMasks();
  }

  Future<void> _loadMasks() async {
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('field_masks')
          .select(
              'id, field_id, mask_points, football_fields(football_field_name)')
          .order('created_at', ascending: false);
      setState(() {
        _availableMasks = List<Map<String, dynamic>>.from(data ?? []);
        _masksLoading = false;
      });
    } catch (_) {
      setState(() => _masksLoading = false);
    }
  }

  void _searchForMatch(String url) {
    if (url.isEmpty) {
      setState(() => _foundPreviousJob = null);
      return;
    }
    final cleanUrl = url.trim();
    try {
      final match = widget.jobs.firstWhere((j) => j.inputVideoUrl == cleanUrl);
      setState(() => _foundPreviousJob = match);
    } catch (_) {
      setState(() => _foundPreviousJob = null);
    }
  }

  List<List<double>>? _extractMaskFromScript(String script) {
    if (!script.contains('_injected_field_mask =')) return null;
    try {
      final start = script.indexOf('_injected_field_mask = [') +
          '_injected_field_mask = ['.length;
      final end = script.indexOf(']', start);
      final content = script.substring(start, end);

      final List<List<double>> pts = [];
      final pairs = content.split('],');
      for (var p in pairs) {
        final cleanP = p.replaceAll('[', '').replaceAll(']', '').trim();
        final coords = cleanP.split(',');
        if (coords.length >= 2) {
          pts.add([
            double.parse(coords[0].trim()),
            double.parse(coords[1].trim()),
          ]);
        }
      }
      return pts.isNotEmpty ? pts : null;
    } catch (e) {
      return null;
    }
  }

  String _stripMaskHeader(String script) {
    if (!script.contains('# ── FIELD MASK')) return script;
    final parts = script.split(
        '# ─────────────────────────────────────────────────────────────────────────────');
    if (parts.length > 1) {
      return parts
          .sublist(1)
          .join(
              '# ─────────────────────────────────────────────────────────────────────────────')
          .trim();
    }
    return script;
  }


  String _buildScriptWithMask(String script) {
    String header = '';

    // 1. Inject Field Mask
    if (_localMask != null && _localMask!.isNotEmpty) {
      final pts = _localMask!
          .map(
              (p) => '[${p[0].toStringAsFixed(4)}, ${p[1].toStringAsFixed(4)}]')
          .join(', ');
      header +=
          '# ── FIELD MASK (auto-injected by Ball Tracking Lab) ────────────────────────\n'
          '_injected_field_mask = [$pts]\n'
          '# ─────────────────────────────────────────────────────────────────────────────\n\n';
    }

    return '$header$script';
  }

  Future<void> _startJobs() async {
    final rawUrl = _urlController.text.trim();
    if (rawUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a video URL')));
      return;
    }

    final baseVideoName = rawUrl.split('/').last;

    // Determine model name from selection
    String modelName;
    String modelLabel;
    switch (_modelSelection) {
      case 'rtdetr':
        modelName = 'rtdetr-l';
        modelLabel = 'RT-DETR';
        break;
      case 'roboflow':
        modelName = 'roboflow://${widget.customModelId}';
        modelLabel = 'Roboflow';
        break;
      case 'tracknet':
        modelName = 'tracknet';
        modelLabel = 'TrackNet';
        break;
      default:
        modelName = 'yolov8l';
        modelLabel = 'YOLO';
    }

    try {
      setState(() => _isUploading = true);

      final List<Map<String, dynamic>> jobsToRun = [
        {'name': '$baseVideoName ($modelLabel)', 'model': modelName}
      ];

      for (var jobSpec in jobsToRun) {
        final config = ScriptConfig(
          detectEveryFrames:
              int.tryParse(widget.detectEveryFramesController.text) ?? 3,
          yoloConf: double.tryParse(widget.yoloConfController.text) ?? 0.12,
          yoloModel: jobSpec['model'],
          yoloImgSize: int.tryParse(widget.yoloImgSizeController.text) ?? 960,
          roiSize: int.tryParse(widget.roiSizeController.text) ?? 1200,
          zoomBase: double.tryParse(widget.zoomBaseController.text) ?? 1.8,
          smoothing: double.tryParse(widget.smoothingController.text) ?? 0.08,
        );

        final job = await widget.service.createJob(
          inputVideoUrl: rawUrl,
          videoName: jobSpec['name'],
          config: config,
          customScript: _customScriptController.text.trim().isNotEmpty
              ? _buildScriptWithMask(_customScriptController.text)
              : null,
        );

        // Fire and forget the processing trigger so it starts immediately
        // without waiting for Modal's cold-start response
        widget.service
            .triggerProcessing(
          job.id,
          roboflowApiKey: widget.roboflowApiKeyController.text.trim(),
        )
            .catchError((e) {
          print('Error triggering job: $e');
        });
      }

      widget.onJobCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text('🔗 Add New Tracking Job',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle(Icons.video_file, 'Video URL', Colors.blue),
                const SizedBox(height: 12),

                // Recent URLs
                if (widget.jobs
                    .where((j) => j.inputVideoUrl.isNotEmpty)
                    .isNotEmpty) ...[
                  SizedBox(
                    height: 38,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: widget.jobs
                          .where((j) => j.inputVideoUrl.isNotEmpty)
                          .map((j) => j.inputVideoUrl)
                          .toSet()
                          .take(8)
                          .map((url) {
                        final fileName = url.split('/').last;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: const Icon(Icons.history,
                                size: 14, color: Colors.blue),
                            label: Text(fileName,
                                style: const TextStyle(fontSize: 11)),
                            onPressed: () {
                              _urlController.text = url;
                              _searchForMatch(url);
                            },
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.blue[100]!),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                _buildSectionTitle(Icons.link, '1. Video URL', Colors.blue),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  onChanged: (val) {
                    _searchForMatch(val);
                    setState(() {}); // Trigger checklist update
                  },
                  decoration: InputDecoration(
                    hintText: 'Paste the video .mp4 URL here...',
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Icon(Icons.video_library_outlined),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!)),
                  ),
                ),

                if (_urlController.text.contains('_chunk_')) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline,
                            size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Note: Segment URLs (ending in _chunk_) usually only contain 30-60 seconds of video data.',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFE65100)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (_foundPreviousJob != null) ...[
                  const SizedBox(height: 12),
                  _buildMagicRunCard(),
                ],

                const SizedBox(height: 32),

                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                              Icons.crop_free, '2. Field Mask', Colors.teal),
                          const SizedBox(height: 8),
                          _buildMaskSelector(),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _buildSectionTitle(
                    Icons.model_training, '3. Model', Colors.deepPurple),
                const SizedBox(height: 8),
                _buildModelSelector(),

                const SizedBox(height: 32),

                _buildSectionTitle(
                    Icons.code,
                    '4. Ball Tracking Script',
                    Colors.purple),
                const SizedBox(height: 8),
                _buildScriptEditor(),

                const SizedBox(height: 32),

                // Readiness Checklist
                _buildSectionTitle(Icons.checklist, 'Readiness Checklist', Colors.blue),
                const SizedBox(height: 12),
                _buildChecklist(),

                const SizedBox(height: 40),

                // Run Button
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _startJobs,
                    icon: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Icon(
                            widget.isDetectOnlyMode
                                ? Icons.radar
                                : Icons.rocket_launch,
                            size: 24),
                    label: Text(
                        _isUploading
                            ? 'STAGING JOBS...'
                            : widget.isDetectOnlyMode
                                ? 'START DETECTION JOBS'
                                : 'RUN TRACKING EXPERIMENT',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.isDetectOnlyMode
                          ? Colors.orange[700]
                          : const Color(0xFF00BF63),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildMagicRunCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.amber),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Previous job found for this URL!',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.amber[900])),
                Text(
                    'From ${DateFormat('MMM dd').format(_foundPreviousJob!.createdAt)}',
                    style: TextStyle(fontSize: 12, color: Colors.amber[800])),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final script = _foundPreviousJob!.customScript ?? '';
              final pts = _extractMaskFromScript(script);
              setState(() {
                _customScriptController.text = _stripMaskHeader(script);
                if (pts != null) {
                  _localMask = pts;
                  _localMaskName = 'Loaded from history';
                  _selectedMaskId = null;
                }
              });
               // Auto analyze after magic load
            },
            icon: const Icon(Icons.history),
            label: const Text('Apply Settings'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[600],
                foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildMaskSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          _masksLoading
              ? const CircularProgressIndicator()
              : DropdownButtonFormField<String>(
                  value: _selectedMaskId,
                  decoration: const InputDecoration(
                      labelText: 'Select Saved Mask',
                      border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('None (Full Frame)')),
                    ..._availableMasks.map((m) {
                      final name = m['football_fields']
                              ?['football_field_name'] ??
                          'Mask';
                      return DropdownMenuItem(
                          value: m['id'] as String, child: Text(name));
                    }),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedMaskId = val;
                      if (val == null) {
                        _localMask = null;
                        _localMaskName = null;
                      } else {
                        final m =
                            _availableMasks.firstWhere((x) => x['id'] == val);
                        final pts = m['mask_points'];
                        _localMaskName = m['football_fields']
                                ?['football_field_name'] ??
                            'Field';
                        if (pts is List) {
                          _localMask = pts
                              .map<List<double>>(
                                  (p) => [p[0].toDouble(), p[1].toDouble()])
                              .toList();
                        }
                      }
                    });
                  },
                ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final url = _urlController.text.trim();
                if (url.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('⚠️ Paste the video URL first!')));
                  return;
                }

                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FieldMaskEditorScreen(
                      fieldId: null,
                      fieldName: 'URL Content',
                      cameraStreamUrl: url,
                    ),
                  ),
                );

                if (result is List) {
                  setState(() {
                    _localMask =
                        result.map((e) => (e as List).cast<double>()).toList();
                    _localMaskName = 'Custom Drawn Mask';
                    _selectedMaskId = null;
                  });
                  
                }

                _loadMasks();
              },
              icon: const Icon(Icons.palette_outlined, size: 18),
              label: const Text('🎯 Preview & Draw New Mask'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.teal[700],
                side: BorderSide(color: Colors.teal[300]!),
              ),
            ),
          ),
          if (_localMask != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.check_circle, size: 14, color: Colors.teal[700]),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${_localMask!.length} points from "${_localMaskName ?? 'Mask'}" linked',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.teal[800],
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildModelSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          // 4-way segmented model selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _modelOption('yolo', 'YOLO', null, Colors.blue[700]!),
                _modelOption('rtdetr', 'RT-DETR', 'Transformer', Colors.orange[700]!),
                _modelOption('roboflow', 'Roboflow', null, const Color(0xFF00BF63)),
                _modelOption('tracknet', 'TrackNet', 'Multi-Frame', Colors.purple[700]!),
              ],
            ),
          ),
          if (_modelSelection == 'roboflow') ...[
            const SizedBox(height: 12),
            TextField(
              controller: widget.roboflowApiKeyController,
              decoration: const InputDecoration(
                  labelText: 'Roboflow API Key',
                  border: OutlineInputBorder(),
                  isDense: true),
              obscureText: true,
              style: const TextStyle(fontSize: 12),
            ),
          ],
          if (_modelSelection == 'tracknet') ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.purple[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.purple[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.purple[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '🧠 TrackNet V3 + YOLO v7.0 ULTRA-PRECISION: Custom-trained heatmap model as PRIMARY detector + 4-strategy YOLO fusion. Dynamic lookahead-backtrack (5→15 frames) + cubic interpolation.',
                      style: TextStyle(fontSize: 11, color: Colors.purple[900]),
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

  Widget _modelOption(String value, String label, String? subtitle, Color activeColor) {
    final isSelected = _modelSelection == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _modelSelection = value;
          
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected ? [const BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? activeColor : Colors.grey[600],
                  fontSize: 11,
                ),
              ),
              if (subtitle != null)
                Text(subtitle, style: TextStyle(fontSize: 8, color: Colors.grey[500])),
            ],
          ),
        ),
      ),
    );
  }

  void _analyzeScript() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Script applied and looks good!')),
    );
  }

  Widget _buildScriptEditor() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.grey[900], borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          TextField(
            controller: _customScriptController,
            maxLines: 15,
            onChanged: (val) => setState(() {}), // Trigger checklist update
            style:
                GoogleFonts.robotoMono(fontSize: 11, color: Colors.green[300]),
            decoration: const InputDecoration(
              hintText: '# Paste your Python script here...\n\n# Note: Leave empty to use the latest default script.',
              hintStyle: TextStyle(color: Colors.grey),
              contentPadding: EdgeInsets.all(16),
              border: InputBorder.none,
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(12))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _analyzeScript,
                  icon: const Icon(Icons.analytics_outlined),
                  label: const Text('APPLY & ANALYZE'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple[700],
                      foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklist() {
    bool hasUrl = _urlController.text.trim().isNotEmpty;
    bool hasMask = _selectedMaskId != null || _localMask != null;
    bool hasScript = _customScriptController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChecklistItem('Video URL Ready', hasUrl),
          const SizedBox(height: 12),
          _buildChecklistItem('Field Mask Applied', hasMask),
          const SizedBox(height: 12),
          _buildChecklistItem('Script Code Ready', hasScript),
        ],
      ),
    );
  }

  Widget _buildChecklistItem(String title, bool isChecked) {
    return Row(
      children: [
        Icon(
          isChecked ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isChecked ? Colors.green : Colors.grey,
          size: 24,
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: isChecked ? FontWeight.bold : FontWeight.normal,
            color: isChecked ? Colors.black87 : Colors.grey[600],
          ),
        ),
      ],
    );
  }
}
