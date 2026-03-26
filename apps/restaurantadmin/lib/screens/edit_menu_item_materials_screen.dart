import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/menu_item_model.dart';
import 'package:restaurantadmin/models/menu_item_material.dart';
import 'package:restaurantadmin/models/material_item.dart'; // To fetch material names

class EditMenuItemMaterialsScreen extends StatefulWidget {
  final MenuItem menuItem;

  const EditMenuItemMaterialsScreen({super.key, required this.menuItem});

  @override
  State<EditMenuItemMaterialsScreen> createState() =>
      _EditMenuItemMaterialsScreenState();
}

class _EditMenuItemMaterialsScreenState
    extends State<EditMenuItemMaterialsScreen>
    with TickerProviderStateMixin {
  List<MenuItemMaterial> _linkedMaterials = [];
  Map<String, String> _materialIdToNameMap =
      {}; // For displaying material names
  bool _isLoading = true;
  String? _error;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _fetchLinkedMaterials();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchLinkedMaterials() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('menu_item_materials')
          .select(
            '*, material_id(id, name, item_image_url)',
          ) // Join with material table to get name and image URL
          .eq('menu_item_id', widget.menuItem.id)
          .order('created_at', ascending: true);

      if (!mounted) return;

      final List<MenuItemMaterial> fetchedLinks = [];
      final Map<String, String> tempMaterialMap = {};

      for (var data in response as List) {
        final mapData = data as Map<String, dynamic>;
        // The join provides material data nested under 'material_id' key if successful
        String? materialName;
        String? materialImageUrl;
        if (mapData['material_id'] is Map) {
          final materialDataMap =
              mapData['material_id'] as Map<String, dynamic>;
          materialName = materialDataMap['name'] as String?;
          materialImageUrl = materialDataMap['item_image_url'] as String?;
          // Store in our local map if needed elsewhere, though fromJson handles it
          if (materialName != null && materialDataMap['id'] != null) {
            tempMaterialMap[materialDataMap['id'] as String] = materialName;
          }
        }
        fetchedLinks.add(
          MenuItemMaterial.fromJson(
            mapData,
            materialName: materialName,
            materialItemImageUrlParam: materialImageUrl,
          ),
        );
      }

      setState(() {
        _linkedMaterials = fetchedLinks;
        _materialIdToNameMap =
            tempMaterialMap; // Or build it from fetchedLinks if preferred
      });
      _animationController.forward();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load linked materials: ${e.toString()}";
        });
      }
      print("Error loading linked materials: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteLinkedMaterial(String linkId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange[600],
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('Confirm Deletion'),
          ],
        ),
        content: const Text(
          'Are you sure you want to remove this material link?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.red[600]!, Colors.red[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.of(context).pop(true),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('menu_item_materials')
          .delete()
          .eq('id', linkId);

      if (mounted) {
        _showSuccessSnackBar('Material link removed successfully!');
        _fetchLinkedMaterials(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to remove material link: $e');
      }
      print("Error deleting material link: $e");
    }
  }

  Future<void> _navigateToAddMaterialLink() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddMaterialLinkDialog(menuItemId: widget.menuItem.id);
      },
    );

    if (result == true && mounted) {
      _fetchLinkedMaterials(); // Refresh the list if a link was added
    }
  }

  Future<void> _handleQuantityUpdate(
    String linkId,
    double newQuantity,
    String unitOfMeasure,
  ) async {
    // Optimistically update UI or show loading indicator
    // For simplicity, we'll just call Supabase and refresh
    try {
      await Supabase.instance.client
          .from('menu_item_materials')
          .update({
            'quantity_used': newQuantity,
            'unit_of_measure_for_usage': unitOfMeasure,
          })
          .eq('id', linkId);

      if (mounted) {
        _showSuccessSnackBar('Quantity updated successfully!');
        _fetchLinkedMaterials(); // Refresh the list
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to update quantity: $e');
      }
      print("Error updating quantity: $e");
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [Colors.teal[600]!, Colors.teal[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.teal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.menuItem.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_linkedMaterials.length} ${_linkedMaterials.length == 1 ? 'material' : 'materials'} linked',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const CircularProgressIndicator(),
          ),
          const SizedBox(height: 24),
          Text(
            'Loading linked materials...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 20),
            Text(
              'Failed to Load Materials',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error occurred',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[600]!, Colors.red[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _fetchLinkedMaterials,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Try Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Materials Linked',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No materials linked to ${widget.menuItem.name} yet.\nTap the button below to start linking materials.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[600]!, Colors.teal[400]!],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _navigateToAddMaterialLink,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_link, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Link Materials',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'Materials for ${widget.menuItem.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () async {
                await _fetchLinkedMaterials();
                if (_error == null) {
                  _showSuccessSnackBar('Materials refreshed successfully!');
                }
              },
              tooltip: 'Refresh Materials',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: _isLoading
              ? _buildLoadingState()
              : _error != null
              ? _buildErrorState()
              : _linkedMaterials.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: () async {
                    await _fetchLinkedMaterials();
                    if (_error == null) {
                      _showSuccessSnackBar('Materials refreshed successfully!');
                    }
                  },
                  color: Colors.teal,
                  child: ListView(
                    children: [
                      _buildHeader(),
                      ..._linkedMaterials.asMap().entries.map((entry) {
                        final index = entry.key;
                        final link = entry.value;
                        return FadeTransition(
                          opacity: _fadeAnimation,
                          child: SlideTransition(
                            position:
                                Tween<Offset>(
                                  begin: const Offset(0, 0.1),
                                  end: Offset.zero,
                                ).animate(
                                  CurvedAnimation(
                                    parent: _animationController,
                                    curve: Interval(
                                      (index * 0.1).clamp(0.0, 1.0),
                                      ((index * 0.1) + 0.3).clamp(0.0, 1.0),
                                      curve: Curves.easeOut,
                                    ),
                                  ),
                                ),
                            child: _EditableMaterialLinkTile(
                              key: ValueKey(link.id),
                              menuItemMaterial: link,
                              materialName:
                                  link.materialName ??
                                  _materialIdToNameMap[link.materialId] ??
                                  'Unknown Material',
                              materialItemImageUrl: link.materialItemImageUrl,
                              onQuantityUpdate: (newQuantity, newUnit) async {
                                await _handleQuantityUpdate(
                                  link.id,
                                  newQuantity,
                                  newUnit,
                                );
                              },
                              onDelete: () => _deleteLinkedMaterial(link.id),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal[600]!, Colors.teal[400]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddMaterialLink,
          backgroundColor: Colors.transparent,
          elevation: 0,
          label: const Text(
            'Link Materials',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          icon: const Icon(Icons.add_link, color: Colors.white),
        ),
      ),
    );
  }
}

// Enhanced Material Link Tile
class _EditableMaterialLinkTile extends StatefulWidget {
  final MenuItemMaterial menuItemMaterial;
  final String materialName;
  final String? materialItemImageUrl;
  final Future<void> Function(double newQuantity, String newUnit)
  onQuantityUpdate;
  final Future<void> Function() onDelete;

  const _EditableMaterialLinkTile({
    super.key,
    required this.menuItemMaterial,
    required this.materialName,
    this.materialItemImageUrl,
    required this.onQuantityUpdate,
    required this.onDelete,
  });

  @override
  State<_EditableMaterialLinkTile> createState() =>
      _EditableMaterialLinkTileState();
}

class _EditableMaterialLinkTileState extends State<_EditableMaterialLinkTile> {
  late TextEditingController _quantityController;
  late String _currentUnitOfMeasure;
  final _formKey = GlobalKey<FormState>();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.menuItemMaterial.quantityUsed.toString(),
    );
    _currentUnitOfMeasure = widget.menuItemMaterial.unitOfMeasureUsed ?? 'N/A';
  }

  @override
  void dispose() {
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _saveQuantity() async {
    if (_formKey.currentState!.validate()) {
      final newQuantity = double.tryParse(_quantityController.text);
      if (newQuantity != null && newQuantity > 0) {
        final confirmSave = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.edit, color: Colors.blue[600], size: 28),
                const SizedBox(width: 12),
                const Text('Update Quantity'),
              ],
            ),
            content: Text(
              'Update quantity to $newQuantity $_currentUnitOfMeasure?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue[600]!, Colors.blue[400]!],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => Navigator.of(context).pop(true),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
        if (confirmSave == true) {
          await widget.onQuantityUpdate(newQuantity, _currentUnitOfMeasure);
          setState(() => _isEditing = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Row(
            children: [
              // Material image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child:
                    widget.materialItemImageUrl != null &&
                        widget.materialItemImageUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: widget.materialItemImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey[600],
                              size: 30,
                            ),
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: Colors.teal[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.teal[600],
                          size: 30,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              // Material details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.materialName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_isEditing)
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityController,
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                suffixText: _currentUnitOfMeasure,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                final dValue = double.tryParse(value);
                                if (dValue == null) return 'Invalid';
                                if (dValue <= 0) return '> 0';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.green[600]!,
                                  Colors.green[400]!,
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: _saveQuantity,
                                child: const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(() => _isEditing = false),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.grey[600],
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.blue[600]!, Colors.blue[400]!],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${widget.menuItemMaterial.quantityUsed} $_currentUnitOfMeasure',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => setState(() => _isEditing = true),
                                child: Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.grey[600],
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (widget.menuItemMaterial.notes != null &&
                        widget.menuItemMaterial.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.note, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.menuItemMaterial.notes!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              Container(
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: widget.onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.delete_outline,
                        color: Colors.red[600],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced Multi-Select Add Material Dialog
class _AddMaterialLinkDialog extends StatefulWidget {
  final String menuItemId;

  const _AddMaterialLinkDialog({required this.menuItemId});

  @override
  State<_AddMaterialLinkDialog> createState() => _AddMaterialLinkDialogState();
}

class _AddMaterialLinkDialogState extends State<_AddMaterialLinkDialog> {
  final _formKey = GlobalKey<FormState>();
  final List<MaterialItem> _selectedMaterials = [];
  final Map<String, double> _quantities = {};
  final Map<String, String> _notes = {};

  List<MaterialItem> _availableMaterials = [];
  List<MaterialItem> _filteredMaterials = [];
  bool _isLoadingMaterials = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchAvailableMaterials();
    _searchController.addListener(_filterMaterials);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterMaterials() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredMaterials = List.from(_availableMaterials);
      } else {
        _filteredMaterials = _availableMaterials
            .where((material) => material.name.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  Future<void> _fetchAvailableMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final response = await Supabase.instance.client
          .from('material')
          .select()
          .order('name', ascending: true);
      if (!mounted) return;
      final materials = (response as List)
          .map((data) => MaterialItem.fromJson(data as Map<String, dynamic>))
          .toList();
      setState(() {
        _availableMaterials = materials;
        _filteredMaterials = List.from(materials);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error fetching materials: $e')),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingMaterials = false);
    }
  }

  void _toggleMaterialSelection(MaterialItem material) {
    setState(() {
      if (_selectedMaterials.any((m) => m.id == material.id)) {
        _selectedMaterials.removeWhere((m) => m.id == material.id);
        _quantities.remove(material.id);
        _notes.remove(material.id);
      } else {
        _selectedMaterials.add(material);
        _quantities[material.id] = 1.0;
        _notes[material.id] = '';
      }
    });
  }

  Future<void> _submitLinks() async {
    if (_selectedMaterials.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Please select at least one material.'),
              ),
            ],
          ),
          backgroundColor: Colors.orange[600],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      setState(() => _isSubmitting = true);

      try {
        final links = _selectedMaterials.map((material) {
          final quantity = _quantities[material.id] ?? 1.0;
          final notes = _notes[material.id]?.trim();
          return {
            'menu_item_id': widget.menuItemId,
            'material_id': material.id,
            'quantity_used': quantity,
            'unit_of_measure_for_usage': material.unitOfMeasure,
            'notes': notes?.isNotEmpty == true ? notes : null,
          };
        }).toList();

        await Supabase.instance.client
            .from('menu_item_materials')
            .insert(links);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_selectedMaterials.length} materials linked successfully!',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Failed to link materials: $e')),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.add_link,
                    color: Colors.teal[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Link Materials',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (_selectedMaterials.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.teal[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_selectedMaterials.length} selected',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.teal[700],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            // Search
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search Materials',
                hintText: 'Enter material name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            // Materials list
            Expanded(
              child: _isLoadingMaterials
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredMaterials.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No materials found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: _formKey,
                      child: ListView.builder(
                        itemCount: _filteredMaterials.length,
                        itemBuilder: (context, index) {
                          final material = _filteredMaterials[index];
                          final isSelected = _selectedMaterials.any(
                            (m) => m.id == material.id,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.teal[50]
                                  : Colors.white,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.teal[300]!
                                    : Colors.grey[200]!,
                                width: isSelected ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                ListTile(
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        _toggleMaterialSelection(material),
                                    activeColor: Colors.teal[600],
                                  ),
                                  title: Text(
                                    material.name,
                                    style: TextStyle(
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Unit: ${material.unitOfMeasure}',
                                  ),
                                  onTap: () =>
                                      _toggleMaterialSelection(material),
                                ),
                                if (isSelected) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: TextFormField(
                                            initialValue:
                                                _quantities[material.id]
                                                    ?.toString() ??
                                                '1.0',
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                              suffixText:
                                                  material.unitOfMeasure,
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              isDense: true,
                                            ),
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty)
                                                return 'Required';
                                              final dValue = double.tryParse(
                                                value,
                                              );
                                              if (dValue == null)
                                                return 'Invalid';
                                              if (dValue <= 0) return '> 0';
                                              return null;
                                            },
                                            onSaved: (value) =>
                                                _quantities[material.id] =
                                                    double.tryParse(
                                                      value ?? '1.0',
                                                    ) ??
                                                    1.0,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: TextFormField(
                                            initialValue:
                                                _notes[material.id] ?? '',
                                            decoration: InputDecoration(
                                              labelText: 'Notes (Optional)',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              isDense: true,
                                            ),
                                            onSaved: (value) =>
                                                _notes[material.id] =
                                                    value ?? '',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
            const SizedBox(height: 20),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.teal[600]!, Colors.teal[400]!],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.teal.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _isSubmitting ? null : _submitLinks,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'Link ${_selectedMaterials.length} Material${_selectedMaterials.length == 1 ? '' : 's'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
