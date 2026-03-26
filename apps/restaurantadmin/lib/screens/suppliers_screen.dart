import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/supplier.dart';
import 'package:restaurantadmin/screens/supplier_detail_screen.dart';

// Dark theme palette - matches supplier_detail_screen
const _kDarkBg = Color(0xFF1A1D21);
const _kDarkCard = Color(0xFF25282D);
const _kDarkSurface = Color(0xFF2D3138);
const _kTextPrimary = Color(0xFFE8EAED);
const _kTextSecondary = Color(0xFF9CA3AF);
const _kAccent = Color(0xFF3B82F6);
const _kAccentGreen = Color(0xFF22C55E);
const _kBorder = Color(0xFF3F4448);

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  bool _loading = false;
  List<Supplier> _suppliers = [];
  final Map<String, int> _supplierItemCounts = {};
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSuppliers();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Reload suppliers and restore scroll position so the list doesn't jump to top.
  /// Pass [savedOffset] when the list is about to be replaced (e.g. before showing loading).
  Future<void> _reloadSuppliersPreservingScroll({double? savedOffset}) async {
    final offset = savedOffset ?? (_scrollController.hasClients ? _scrollController.offset : 0.0);
    await _loadSuppliers();
    if (!mounted || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(offset.clamp(0.0, _scrollController.position.maxScrollExtent));
    });
  }

  Future<void> _loadSuppliers() async {
    setState(() => _loading = true);
    try {
      List<dynamic> data;
      try {
        data = await Supabase.instance.client
            .from('suppliers')
            .select(
              'id, created_at, updated_at, name, ai_rules, address, street_address, post_code, is_online_supplier, image_url',
            )
            .order('name');
      } catch (e1) {
        try {
          data = await Supabase.instance.client
              .from('suppliers')
              .select('id, created_at, updated_at, name, ai_rules, address')
              .order('name');
        } catch (e2) {
          data = await Supabase.instance.client
              .from('suppliers')
              .select('id, created_at, updated_at, name, ai_rules')
              .order('name');
        }
      }
      _suppliers = data
          .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
          .toList();

      // Load purchase item counts for each supplier
      await _loadItemCounts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load suppliers: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadItemCounts() async {
    try {
      // Get counts of purchase_catalog_items per supplier
      for (final supplier in _suppliers) {
        final countResp = await Supabase.instance.client
            .from('purchase_catalog_items')
            .select('id')
            .eq('supplier_id', supplier.id)
            .count(CountOption.exact);
        _supplierItemCounts[supplier.id] = countResp.count;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error loading item counts: $e');
    }
  }

  Future<void> _addSupplierDialog() async {
    final nameCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final streetCtrl = TextEditingController();
    final postCodeCtrl = TextEditingController();
    final aiRulesCtrl = TextEditingController();
    bool isOnline = false;
    final formKey = GlobalKey<FormState>();

    XFile? pickedImage;
    final picker = ImagePicker();
    String? tempPreviewUrl;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _kAccent,
            surface: _kDarkCard,
            onSurface: _kTextPrimary,
          ),
          dialogBackgroundColor: _kDarkCard,
        ),
        child: StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Add Supplier', style: TextStyle(color: _kTextPrimary)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tempPreviewUrl != null && tempPreviewUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          tempPreviewUrl!,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Add Image'),
                    onPressed: () async {
                      try {
                        final XFile? f = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                          maxWidth: 1200,
                        );
                        if (f != null) {
                          pickedImage = f;
                          setStateDialog(() => tempPreviewUrl = f.path);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to pick image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: streetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Street Address (optional)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: postCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Post Code (optional)',
                      prefixIcon: Icon(Icons.local_post_office_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      hintText: 'e.g. Building / Country',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('Online supplier'),
                      const Spacer(),
                      Switch(
                        value: isOnline,
                        onChanged: (v) => setStateDialog(() => isOnline = v),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: aiRulesCtrl,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      labelText: 'AI Rules (optional)',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _kTextSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    ),
    );

    if (ok != true) return;
    if (!formKey.currentState!.validate()) return;

    try {
      setState(() => _loading = true);

      String? imageUrl;
      if (pickedImage != null) {
        const bucket = 'supplier_images';
        final ext = pickedImage!.path.split('.').last.toLowerCase();
        final filename = 'new_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = 'public/$filename';
        final bytes = await pickedImage!.readAsBytes();
        await Supabase.instance.client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: pickedImage!.mimeType ?? 'image/$ext',
                upsert: true,
              ),
            );
        imageUrl = Supabase.instance.client.storage
            .from(bucket)
            .getPublicUrl(path);
      }

      final payload = Supplier(
        id: '',
        createdAt: DateTime.now(),
        name: nameCtrl.text.trim(),
        address: addressCtrl.text.trim().isEmpty
            ? null
            : addressCtrl.text.trim(),
        streetAddress: streetCtrl.text.trim().isEmpty
            ? null
            : streetCtrl.text.trim(),
        postCode: postCodeCtrl.text.trim().isEmpty
            ? null
            : postCodeCtrl.text.trim(),
        isOnlineSupplier: isOnline,
        aiRules: aiRulesCtrl.text.trim().isEmpty
            ? null
            : aiRulesCtrl.text.trim(),
        imageUrl: imageUrl,
      ).toJson(includeAddress: true);

      await Supabase.instance.client.from('suppliers').insert(payload);
      await _loadSuppliers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to add supplier: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSupplier(String id) async {
    try {
      setState(() => _loading = true);
      await Supabase.instance.client.from('suppliers').delete().eq('id', id);
      await _loadSuppliers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kDarkBg,
      appBar: AppBar(
        title: const Text('Suppliers'),
        backgroundColor: _kDarkCard,
        foregroundColor: _kTextPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadSuppliers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loading ? null : _addSupplierDialog,
        icon: const Icon(Icons.add),
        label: const Text('Add Supplier'),
        backgroundColor: _kAccent,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kAccent))
          : _suppliers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.storefront_outlined, size: 64, color: _kTextSecondary),
                      const SizedBox(height: 16),
                      const Text(
                        'No suppliers yet',
                        style: TextStyle(fontSize: 18, color: _kTextPrimary),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap + to add your first supplier',
                        style: TextStyle(fontSize: 14, color: _kTextSecondary),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSuppliers,
                  color: _kAccent,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: _suppliers.length,
                    itemBuilder: (context, index) {
                      final s = _suppliers[index];
                      final itemCount = _supplierItemCounts[s.id] ?? 0;
                      return Card(
                        elevation: 0,
                        color: _kDarkCard,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: _kBorder),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () async {
                            final result = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    SupplierDetailScreen(supplier: s),
                              ),
                            );
                            if (result == true && mounted) {
                              _reloadSuppliersPreservingScroll();
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _kDarkSurface,
                                    borderRadius: BorderRadius.circular(10),
                                    image:
                                        (s.imageUrl != null &&
                                            s.imageUrl!.isNotEmpty)
                                        ? DecorationImage(
                                            image: NetworkImage(s.imageUrl!),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child:
                                      (s.imageUrl == null ||
                                          s.imageUrl!.isEmpty)
                                      ? Icon(
                                          s.isOnlineSupplier == true
                                              ? Icons.cloud_done_outlined
                                              : Icons.storefront_outlined,
                                          color: _kAccent,
                                          size: 22,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                          color: _kTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: itemCount > 0
                                                  ? const Color(0xFF1E3A2F)
                                                  : _kDarkSurface,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: itemCount > 0
                                                    ? _kAccentGreen
                                                    : _kBorder,
                                              ),
                                            ),
                                            child: Text(
                                              '$itemCount item${itemCount == 1 ? '' : 's'}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: itemCount > 0
                                                    ? _kAccentGreen
                                                    : _kTextSecondary,
                                              ),
                                            ),
                                          ),
                                          if (s.isOnlineSupplier == true) ...[
                                            const SizedBox(width: 6),
                                            Icon(
                                              Icons.cloud_outlined,
                                              size: 12,
                                              color: _kAccent,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20, color: _kTextSecondary),
                                  padding: EdgeInsets.zero,
                                  onSelected: (value) {
                                    if (value == 'edit') _editSupplier(s);
                                    else if (value == 'delete') _confirmDelete(s);
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                          const SizedBox(width: 8),
                                          Text('Delete', style: TextStyle(color: Colors.red)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  size: 20,
                                  color: _kTextSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Future<void> _editSupplier(Supplier s) async {
    final nameCtrl = TextEditingController(text: s.name);
    final streetCtrl = TextEditingController(text: s.streetAddress ?? '');
    final postCodeCtrl = TextEditingController(text: s.postCode ?? '');
    final addressCtrl = TextEditingController(text: s.address ?? '');
    final aiRulesCtrl = TextEditingController(text: s.aiRules ?? '');
    bool isOnline = s.isOnlineSupplier ?? false;

    XFile? pickedImage;
    final picker = ImagePicker();
    String? tempPreviewUrl = s.imageUrl; // show existing until changed

    final formKey = GlobalKey<FormState>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.dark(
            primary: _kAccent,
            surface: _kDarkCard,
            onSurface: _kTextPrimary,
          ),
          dialogBackgroundColor: _kDarkCard,
        ),
        child: StatefulBuilder(
          builder: (ctx, setStateDialog) => AlertDialog(
            title: const Text('Edit Supplier', style: TextStyle(color: _kTextPrimary)),
            contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (tempPreviewUrl != null && tempPreviewUrl!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          tempPreviewUrl!,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Change Image'),
                    onPressed: () async {
                      try {
                        final XFile? f = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 80,
                          maxWidth: 1200,
                        );
                        if (f != null) {
                          pickedImage = f;
                          setStateDialog(() => tempPreviewUrl = f.path);
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to pick image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: streetCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Street Address',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: postCodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Post Code',
                      prefixIcon: Icon(Icons.local_post_office_outlined),
                    ),
                  ),
                  TextFormField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'e.g. Building / Country',
                      prefixIcon: Icon(Icons.map_outlined),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: 8),
                      const Text('Online supplier'),
                      const Spacer(),
                      Switch(
                        value: isOnline,
                        onChanged: (v) => setStateDialog(() => isOnline = v),
                      ),
                    ],
                  ),
                  TextFormField(
                    controller: aiRulesCtrl,
                    minLines: 2,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'AI Rules'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel', style: TextStyle(color: _kTextSecondary)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: _kAccent),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ),
    );

    if (ok != true) return;
    if (!formKey.currentState!.validate()) return;

    // Save scroll position before showing loading (list is replaced by spinner).
    final savedScrollOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;

    try {
      setState(() => _loading = true);

      String? imageUrl = s.imageUrl;
      if (pickedImage != null) {
        const bucket = 'supplier_images';
        final ext = pickedImage!.path.split('.').last.toLowerCase();
        final filename =
            '${s.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        final path = 'public/$filename';
        final bytes = await pickedImage!.readAsBytes();
        await Supabase.instance.client.storage
            .from(bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                contentType: pickedImage!.mimeType ?? 'image/$ext',
                upsert: true,
              ),
            );
        imageUrl = Supabase.instance.client.storage
            .from(bucket)
            .getPublicUrl(path);
      }

      await Supabase.instance.client
          .from('suppliers')
          .update({
            'name': nameCtrl.text.trim(),
            'street_address': streetCtrl.text.trim().isEmpty
                ? null
                : streetCtrl.text.trim(),
            'post_code': postCodeCtrl.text.trim().isEmpty
                ? null
                : postCodeCtrl.text.trim(),
            'address': addressCtrl.text.trim().isEmpty
                ? null
                : addressCtrl.text.trim(),
            'is_online_supplier': isOnline,
            'ai_rules': aiRulesCtrl.text.trim().isEmpty
                ? null
                : aiRulesCtrl.text.trim(),
            if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl,
          })
          .eq('id', s.id);

      await _reloadSuppliersPreservingScroll(savedOffset: savedScrollOffset);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update supplier: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmDelete(Supplier s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text('Are you sure you want to delete "${s.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _deleteSupplier(s.id);
    }
  }
}
