import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mycut_customer/src/providers/looks_provider.dart';
import 'package:mycut_cutspec/mycut_cutspec.dart';
import 'package:mycut_ui/mycut_ui.dart';

/// Screen allowing customers to import a hairstyle photo from the gallery
/// and configure cut specifications without AI generation.
class ImportLookScreen extends ConsumerStatefulWidget {
  const ImportLookScreen({super.key});

  @override
  ConsumerState<ImportLookScreen> createState() => _ImportLookScreenState();
}

class _ImportLookScreenState extends ConsumerState<ImportLookScreen> {
  final _titleController = TextEditingController(text: 'My Gallery Look');
  final _picker = ImagePicker();

  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  bool _isSaving = false;

  // Default cut spec preset
  FadeType _selectedFade = FadeType.mid;
  int _fadeGuardStart = 1;
  int _fadeGuardEnd = 3;
  int _topLengthMm = 45;

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageName = picked.name;
      });
    }
  }

  Future<void> _saveLook() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for your look')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final cutSpec = CutSpec(
      fadeType: _selectedFade,
      fadeGuardStart: _fadeGuardStart,
      fadeGuardEnd: _fadeGuardEnd,
      topLengthMm: _topLengthMm,
    );

    final look = await ref.read(looksListProvider.notifier).saveLook(
          title: _titleController.text.trim(),
          styleKey: _selectedFade.name,
          cutSpec: cutSpec,
          imageBytes: _selectedImageBytes,
          imageFileName: _selectedImageName,
        );

    setState(() => _isSaving = false);

    if (mounted) {
      if (look != null) {
        await context.push('/looks/${look.id}/qr', extra: look);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save look. Try again.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Look'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Photo picker container
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 220,
                decoration: BoxDecoration(
                  color: MyCutColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: MyCutColors.surfaceContainerHighest,
                    width: 1.5,
                  ),
                ),
                child: _selectedImageBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 48,
                              color: MyCutColors.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Select Photo from Gallery',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: MyCutColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Import a photo of the hairstyle you want',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: MyCutColors.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),

            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Look Title',
                hintText: 'e.g. Low Taper Texture',
                filled: true,
                fillColor: MyCutColors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Cut Spec Configuration
            Text(
              'CUT SPECIFICATION',
              style: theme.textTheme.labelMedium?.copyWith(
                color: MyCutColors.secondary,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            // Fade Type Selector
            Wrap(
              spacing: 8,
              children: FadeType.values
                  .where((f) => f != FadeType.none)
                  .map((fade) {
                final isSelected = _selectedFade == fade;
                return ChoiceChip(
                  label: Text('${fade.name.toUpperCase()} FADE'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedFade = fade);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Guard Range
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'START GUARD: #$_fadeGuardStart',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: MyCutColors.onSurface,
                        ),
                      ),
                      Slider(
                        value: _fadeGuardStart.toDouble(),
                        max: 4,
                        divisions: 4,
                        onChanged: (val) {
                          setState(() {
                            _fadeGuardStart = val.toInt();
                            if (_fadeGuardEnd < _fadeGuardStart) {
                              _fadeGuardEnd = _fadeGuardStart;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'END GUARD: #$_fadeGuardEnd',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: MyCutColors.onSurface,
                        ),
                      ),
                      Slider(
                        value: _fadeGuardEnd.toDouble(),
                        min: 1,
                        max: 8,
                        divisions: 7,
                        onChanged: (val) {
                          setState(() {
                            _fadeGuardEnd = val.toInt();
                            if (_fadeGuardStart > _fadeGuardEnd) {
                              _fadeGuardStart = _fadeGuardEnd;
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Top Length
            Text(
              'TOP LENGTH: ${_topLengthMm}mm '
              '(~${(_topLengthMm / 25.4).toStringAsFixed(1)}")',
              style: theme.textTheme.labelSmall?.copyWith(
                color: MyCutColors.onSurface,
              ),
            ),
            Slider(
              value: _topLengthMm.toDouble(),
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (val) => setState(() => _topLengthMm = val.toInt()),
            ),
            const SizedBox(height: 32),

            // Save CTA
            ElevatedButton(
              onPressed: _isSaving ? null : _saveLook,
              child: _isSaving
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save Look & Generate QR'),
            ),
          ],
        ),
      ),
    );
  }
}
