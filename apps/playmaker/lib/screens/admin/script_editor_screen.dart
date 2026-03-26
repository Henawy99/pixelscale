import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Full-screen editor for pushing pipeline and ball tracking script updates.
/// Provides a side-by-side view of current vs new code.
class ScriptEditorScreen extends StatefulWidget {
  final SupabaseClient supabase;
  final String scriptType; // 'pipeline' or 'ball_tracking'
  final String? initialScript;
  final String? initialVersion;
  final bool initialShowFieldMask;
  final bool initialShowRedBall;
  final int onlineCount;

  const ScriptEditorScreen({
    super.key,
    required this.supabase,
    required this.scriptType,
    this.initialScript,
    this.initialVersion,
    required this.initialShowFieldMask,
    required this.initialShowRedBall,
    required this.onlineCount,
  });

  @override
  State<ScriptEditorScreen> createState() => _ScriptEditorScreenState();
}

class _ScriptEditorScreenState extends State<ScriptEditorScreen> {
  final _scriptController = TextEditingController();
  final _versionController = TextEditingController();
  final _changelogController = TextEditingController();
  
  bool _isUploading = false;
  String? _statusMessage;
  bool _isError = false;
  String? _currentScriptContent;
  bool _isLoadingCurrent = false;
  
  late bool _showFieldMask;
  late bool _showRedBall;

  // BunnyCDN config
  static const String _bunnyStorageZone = 'playmaker-raw';
  static const String _bunnyApiKey = 'ec5feff0-e193-4a2c-a6c0fb04ab00-2198-4f75';
  static const String _bunnyStorageUrl = 'https://storage.bunnycdn.com/$_bunnyStorageZone';
  static const String _bunnyCdnUrl = 'https://playmaker-raw.b-cdn.net';

  @override
  void initState() {
    super.initState();
    _showFieldMask = widget.initialShowFieldMask;
    _showRedBall = widget.initialShowRedBall;
    
    if (widget.initialScript != null) {
      _currentScriptContent = widget.initialScript;
      _scriptController.text = widget.initialScript!;
    }
    
    if (widget.initialVersion != null) {
      _versionController.text = widget.initialVersion!;
    }
    
    _loadCurrentFromDb();
  }

  Future<void> _loadCurrentFromDb() async {
    setState(() {
      _isLoadingCurrent = true;
      _currentScriptContent = null;
    });
    try {
      List? result;
      bool columnExists = true;
      
      try {
        // 1. Try with script_type filter
        final res = await widget.supabase
            .from('pi_script_updates')
            .select()
            .eq('script_type', widget.scriptType)
            .order('pushed_at', ascending: false)
            .limit(1);
        result = res;
      } catch (e) {
        if (e.toString().contains('42703') || e.toString().contains('script_type')) {
          columnExists = false;
        } else {
          rethrow;
        }
      }

      List? data = result;
      
      // 2. Fallback if column missing or no entries found with filter
      if (!columnExists || (data == null || data.isEmpty)) {
        final fallback = await widget.supabase
            .from('pi_script_updates')
            .select()
            .order('pushed_at', ascending: false)
            .limit(1);
        data = fallback as List?;
      }

      if (data != null && data.isNotEmpty) {
        final latest = data[0];
        final scriptUrl = latest['script_url'];
        final storedContent = latest['script_content']?.toString();
        
        bool loaded = false;
        
        if (scriptUrl != null && scriptUrl.toString().isNotEmpty) {
          // Try direct CDN fetch
          try {
            final response = await http.get(Uri.parse(scriptUrl.toString())).timeout(const Duration(seconds: 10));
            if (response.statusCode == 200) {
              setState(() {
                _currentScriptContent = response.body;
                if (_scriptController.text.trim().isEmpty || _scriptController.text.length < 50) {
                  _scriptController.text = response.body;
                }
              });
              loaded = true;
            }
          } catch (e) {
            // CDN failed — try proxy next
          }
          
          // Proxy fallback only if CDN failed
          if (!loaded) {
            try {
              final proxyUrl = 'https://corsproxy.io/?' + Uri.encodeComponent(scriptUrl.toString());
              final proxyRes = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 10));
              if (proxyRes.statusCode == 200) {
                setState(() {
                  _currentScriptContent = proxyRes.body;
                  if (_scriptController.text.trim().isEmpty || _scriptController.text.length < 50) {
                    _scriptController.text = proxyRes.body;
                  }
                });
                loaded = true;
              }
            } catch (e) {
              // Proxy also failed
            }
          }
        }
        
        // Fallback: use script_content stored directly in Supabase
        if (!loaded) {
          if (storedContent != null && storedContent.isNotEmpty) {
            setState(() {
              _currentScriptContent = storedContent;
              if (_scriptController.text.trim().isEmpty || _scriptController.text.length < 50) {
                _scriptController.text = storedContent;
              }
            });
          } else {
            setState(() => _currentScriptContent = 
              '# No cached content found (v${latest['version'] ?? '?'}).\n'
              '# CDN link has expired and no script_content was stored.\n'
              '# Paste your script in the right panel and click UPLOAD & PUSH to deploy a new version.');
          }
        }
      } else {
        setState(() => _currentScriptContent = '# No previous entries found for ${widget.scriptType} scripts.');
      }
      
      if (!columnExists) {
        print('⚠️ Database column "script_type" is missing in "pi_script_updates" table.');
      }
    } catch (e) {
      print('Error loading current script: $e');
      setState(() => _currentScriptContent = '# Error loading script: $e');
    } finally {
      if (mounted) setState(() => _isLoadingCurrent = false);
    }
  }

  Future<void> _uploadAndPush() async {
    final script = _scriptController.text.trim();
    final version = _versionController.text.trim();
    final changelog = _changelogController.text.trim();

    if (script.isEmpty || version.isEmpty) {
      setState(() {
        _statusMessage = 'Script and version are required';
        _isError = true;
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _statusMessage = 'Uploading to CDN...';
      _isError = false;
    });

    try {
      final filename = widget.scriptType == 'pipeline' ? 'field_camera' : 'ball_tracking';
      final remotePath = 'pi_scripts/${filename}_v$version.py';
      final uploadUrl = '$_bunnyStorageUrl/$remotePath';
      
      final response = await http.put(
        Uri.parse(uploadUrl),
        headers: {
          'AccessKey': _bunnyApiKey,
          'Content-Type': 'application/octet-stream',
        },
        body: utf8.encode(script),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('CDN upload failed: HTTP ${response.statusCode}');
      }

      final cdnUrl = '$_bunnyCdnUrl/$remotePath';
      
      // Step 2: Insert into pi_script_updates table
      final insertData = {
        'version': version,
        'script_url': cdnUrl,
        'script_content': script, // Save content directly so we can fallback when CDN expires
        'changelog': changelog.isNotEmpty ? changelog : null,
        'pushed_by': 'admin',
        'script_type': widget.scriptType, // This might fail
      };

      try {
        await widget.supabase.from('pi_script_updates').insert(insertData);
      } catch (e) {
        if (e.toString().contains('42703')) {
          // Retry without script_type (column might not exist)
          final retryData = Map<String, dynamic>.from(insertData)..remove('script_type');
          try {
            await widget.supabase.from('pi_script_updates').insert(retryData);
          } catch (e2) {
            // Also try without script_content in case that column doesn't exist
            final minimalData = Map<String, dynamic>.from(retryData)..remove('script_content');
            await widget.supabase.from('pi_script_updates').insert(minimalData);
          }
        } else {
          rethrow;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update pushed! v$version is now active.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isError = true;
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.scriptType == 'pipeline' ? 'Pipeline Code (Pi)' : 'Ball Tracking Script (GPU)';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit $title',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          if (_isUploading)
            const Center(child: Padding(padding: EdgeInsets.only(right: 16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: _uploadAndPush,
                icon: const Icon(Icons.rocket_launch, size: 18),
                label: const Text('UPLOAD & PUSH'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Top Bar for Inputs
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Version
                SizedBox(
                  width: 120,
                  child: TextField(
                    controller: _versionController,
                    decoration: InputDecoration(
                      labelText: 'Version',
                      hintText: 'e.g. 1.1',
                      prefixIcon: const Icon(Icons.tag, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Changelog
                Expanded(
                  child: TextField(
                    controller: _changelogController,
                    decoration: InputDecoration(
                      labelText: 'Changelog (Optional)',
                      hintText: 'What changed in this version?',
                      prefixIcon: const Icon(Icons.notes, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          if (widget.scriptType == 'pipeline')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.white,
              child: Row(
                children: [
                  _buildToggle('Show Field Mask', _showFieldMask, (v) => setState(() => _showFieldMask = v)),
                  const SizedBox(width: 24),
                  _buildToggle('Show Red Ball', _showRedBall, (v) => setState(() => _showRedBall = v)),
                ],
              ),
            ),

          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: _isError ? Colors.red.shade50 : Colors.blue.shade50,
              child: Text(
                _statusMessage!,
                style: GoogleFonts.inter(
                  color: _isError ? Colors.red.shade800 : Colors.blue.shade800,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Side-by-Side Editor
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Current Script (Left)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'CURRENT SCRIPT (READONLY)',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _isLoadingCurrent 
                              ? const Center(child: CircularProgressIndicator())
                              : SingleChildScrollView(
                                  padding: const EdgeInsets.all(12),
                                  child: SelectableText(
                                    _currentScriptContent ?? '# No previous content found',
                                    style: GoogleFonts.firaCode(fontSize: 12, color: Colors.blueGrey.shade800),
                                  ),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // New Script (Right)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'NEW SCRIPT CONTENT',
                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () async {
                                final data = await Clipboard.getData('text/plain');
                                if (data?.text != null) {
                                  _scriptController.text = data!.text!;
                                }
                              },
                              icon: const Icon(Icons.paste, size: 14),
                              label: const Text('Paste from Clipboard', style: TextStyle(fontSize: 11)),
                              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade100),
                              boxShadow: [
                                BoxShadow(color: Colors.blue.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: TextField(
                              controller: _scriptController,
                              maxLines: null,
                              expands: true,
                              style: GoogleFonts.firaCode(fontSize: 12),
                              decoration: const InputDecoration(
                                contentPadding: EdgeInsets.all(12),
                                border: InputBorder.none,
                                hintText: '# Paste your new script here...',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      children: [
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.blue.shade700,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
        ),
      ],
    );
  }
}
