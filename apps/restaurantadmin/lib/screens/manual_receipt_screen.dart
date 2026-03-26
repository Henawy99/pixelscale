import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:restaurantadmin/models/material_item.dart';
import 'package:restaurantadmin/models/receipt_item.dart'; // Assuming this model is suitable or will be adapted

import 'package:cached_network_image/cached_network_image.dart'; // Added for image display

// Enum for managing wizard steps
enum ManualReceiptStep {
  selectItems,
  enterQuantitiesAndPrices,
  reviewAndUploadImage,
}

class ManualReceiptScreen extends StatefulWidget {
  const ManualReceiptScreen({super.key});

  @override
  State<ManualReceiptScreen> createState() => _ManualReceiptScreenState();
}

class _ManualReceiptScreenState extends State<ManualReceiptScreen>
    with TickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Wizard state
  ManualReceiptStep _currentStep = ManualReceiptStep.selectItems;

  // Data for each step
  List<MaterialItem> _allMaterials = [];
  List<MaterialItem> _filteredMaterials = [];
  String _searchTerm = '';
  final TextEditingController _searchController = TextEditingController();

  final List<MaterialItem> _step1SelectedMaterials =
      []; // Materials selected in step 1
  List<ReceiptItem> _step2ReceiptItems =
      []; // Items with quantities and prices from step 2

  XFile? _receiptImageFile;
  final ImagePicker _picker = ImagePicker();

  // Loading states
  bool _isLoadingMaterials = true;
  bool _isSavingReceipt = false;

  // Animation controllers (can be re-added if complex animations are desired per step)

  // Focus nodes and controllers for quantity/price screen
  final Map<String, FocusNode> _quantityFocusNodes = {};
  final Map<String, FocusNode> _priceFocusNodes = {};
  final Map<String, TextEditingController> _quantityControllers = {};
  final Map<String, TextEditingController> _priceControllers = {};
  final Map<String, TextEditingController> _wholesalerNameController =
      {}; // If needed per item
  final Map<String, TextEditingController> _receiptDateController =
      {}; // If needed per item

  // Global form key for the quantity/price step if needed for validation
  final _quantityPriceFormKey = GlobalKey<FormState>();

  // Wholesaler and Receipt Date for the entire receipt (Step 3)
  final TextEditingController _overallWholesalerController =
      TextEditingController();
  final TextEditingController _overallReceiptDateController =
      TextEditingController();
  DateTime? _selectedReceiptDate;

  // For displaying calculated unit prices in Step 2
  final Map<String, double> _calculatedUnitPrices = {};

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _fetchMaterials();
    _selectedReceiptDate = DateTime.now();
    _overallReceiptDateController.text = "${_selectedReceiptDate!.toLocal()}"
        .split(' ')[0];

    _searchController.addListener(() {
      setState(() {
        _searchTerm = _searchController.text;
        _filterMaterials();
      });
    });

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    _quantityFocusNodes.forEach((_, node) => node.dispose());
    _priceFocusNodes.forEach((_, node) => node.dispose());
    _quantityControllers.forEach((_, controller) => controller.dispose());
    _priceControllers.forEach((_, controller) => controller.dispose());
    _overallWholesalerController.dispose();
    _overallReceiptDateController.dispose();
    super.dispose();
  }

  Future<void> _fetchMaterials() async {
    setState(() => _isLoadingMaterials = true);
    try {
      final List<dynamic> response = await _supabase
          .from('material')
          .select()
          .order('name', ascending: true);
      if (!mounted) return;
      setState(() {
        _allMaterials = response
            .map((data) => MaterialItem.fromJson(data as Map<String, dynamic>))
            .toList();
        _filterMaterials();
        _isLoadingMaterials = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMaterials = false);
      _showErrorSnackBar('Error fetching materials: $e');
    }
  }

  void _filterMaterials() {
    if (_searchTerm.isEmpty) {
      _filteredMaterials = List.from(_allMaterials);
    } else {
      _filteredMaterials = _allMaterials
          .where(
            (material) =>
                material.name.toLowerCase().contains(_searchTerm.toLowerCase()),
          )
          .toList();
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

  void _showWarningSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _goToNextStep() {
    if (_currentStep == ManualReceiptStep.selectItems) {
      if (_step1SelectedMaterials.isEmpty) {
        _showWarningSnackBar('Please select at least one material.');
        return;
      }
      // Prepare items for step 2
      _step2ReceiptItems = _step1SelectedMaterials.map((material) {
        // Initialize controllers and focus nodes for new items
        _quantityControllers[material.id] ??= TextEditingController();
        _priceControllers[material.id] ??= TextEditingController();
        _quantityFocusNodes[material.id] ??= FocusNode();
        _priceFocusNodes[material.id] ??= FocusNode();
        return ReceiptItem(
          material: material,
          unitOfMeasure: material.unitOfMeasure,
        );
      }).toList();
      setState(() => _currentStep = ManualReceiptStep.enterQuantitiesAndPrices);
    } else if (_currentStep == ManualReceiptStep.enterQuantitiesAndPrices) {
      if (_quantityPriceFormKey.currentState?.validate() ?? false) {
        _quantityPriceFormKey.currentState
            ?.save(); // Ensure values are saved to controllers if using onSaved
        // Update ReceiptItem objects from controllers
        bool allValid = true;
        for (var item in _step2ReceiptItems) {
          final qtyCtrl = _quantityControllers[item.material.id];
          final priceCtrl = _priceControllers[item.material.id];
          item.quantity = double.tryParse(qtyCtrl?.text ?? '0') ?? 0;

          // Assuming priceCtrl is for TOTAL price of that line item
          double itemTotalPrice = double.tryParse(priceCtrl?.text ?? '0') ?? 0;
          if (item.quantity > 0) {
            item.unitPricePaid = itemTotalPrice / item.quantity;
          } else {
            item.unitPricePaid = 0; // Or handle as error
          }
          if (item.quantity <= 0 || itemTotalPrice < 0) {
            // Price can be 0 if item is free
            allValid = false;
            break;
          }
        }
        if (!allValid) {
          _showErrorSnackBar(
            'Please enter valid positive quantities and non-negative prices for all items.',
          );
          return;
        }
        setState(() => _currentStep = ManualReceiptStep.reviewAndUploadImage);
      }
    }
    // No next step from review, only save
  }

  void _goToPreviousStep() {
    if (_currentStep == ManualReceiptStep.enterQuantitiesAndPrices) {
      setState(() => _currentStep = ManualReceiptStep.selectItems);
    } else if (_currentStep == ManualReceiptStep.reviewAndUploadImage) {
      setState(() => _currentStep = ManualReceiptStep.enterQuantitiesAndPrices);
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        setState(() => _receiptImageFile = pickedFile);
        _showSuccessSnackBar('Receipt image added successfully!');
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _selectReceiptDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedReceiptDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ), // Allow future dates slightly if needed
    );
    if (picked != null && picked != _selectedReceiptDate) {
      setState(() {
        _selectedReceiptDate = picked;
        _overallReceiptDateController.text = "${picked.toLocal()}".split(
          ' ',
        )[0]; // Format as YYYY-MM-DD
      });
    }
  }

  Widget _buildAppBar() {
    String title = '';
    switch (_currentStep) {
      case ManualReceiptStep.selectItems:
        title = 'Step 1: Select Materials';
        break;
      case ManualReceiptStep.enterQuantitiesAndPrices:
        title = 'Step 2: Enter Quantities & Prices';
        break;
      case ManualReceiptStep.reviewAndUploadImage:
        title = 'Step 3: Review & Add Image';
        break;
    }
    return AppBar(
      title: Text(title),
      leading: _currentStep != ManualReceiptStep.selectItems
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goToPreviousStep,
            )
          : null,
    );
  }

  Widget _buildItemSelectionStep() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search Materials',
                  hintText: 'Enter material name...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchTerm.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
              ),
            ),
            if (_step1SelectedMaterials.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.indigo[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.indigo[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.indigo[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_step1SelectedMaterials.length} material${_step1SelectedMaterials.length == 1 ? '' : 's'} selected',
                      style: TextStyle(
                        color: Colors.indigo[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _isLoadingMaterials
                  ? _buildLoadingState()
                  : _allMaterials.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filteredMaterials.length,
                      itemBuilder: (context, index) {
                        final material = _filteredMaterials[index];
                        final isSelected = _step1SelectedMaterials.any(
                          (m) => m.id == material.id,
                        );
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.indigo[50]
                                : Colors.white,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.indigo[300]!
                                  : Colors.grey[200]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: ListTile(
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child:
                                  (material.itemImageUrl != null &&
                                      material.itemImageUrl!.isNotEmpty)
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: CachedNetworkImage(
                                        imageUrl: material.itemImageUrl!,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Colors.grey[200],
                                              child: const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                ),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: Colors.indigo[100],
                                              child: Icon(
                                                Icons.inventory_2_outlined,
                                                color: Colors.indigo[600],
                                                size: 24,
                                              ),
                                            ),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        color: Colors.indigo[100],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_outlined,
                                        color: Colors.indigo[600],
                                        size: 24,
                                      ),
                                    ),
                            ),
                            title: Text(
                              material.name,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: Text('Unit: ${material.unitOfMeasure}'),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _step1SelectedMaterials.add(material);
                                  } else {
                                    _step1SelectedMaterials.removeWhere(
                                      (m) => m.id == material.id,
                                    );
                                  }
                                });
                              },
                              activeColor: Colors.indigo[600],
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _step1SelectedMaterials.removeWhere(
                                    (m) => m.id == material.id,
                                  );
                                } else {
                                  _step1SelectedMaterials.add(material);
                                }
                              });
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
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
            'Loading materials...',
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 24),
          Text(
            'No Materials Available',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No materials found. Add materials\nin the inventory screen first.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _updateCalculatedUnitPrice(String materialId) {
    final qtyCtrl = _quantityControllers[materialId];
    final priceCtrl = _priceControllers[materialId];
    if (qtyCtrl != null && priceCtrl != null) {
      final double quantity = double.tryParse(qtyCtrl.text) ?? 0.0;
      final double totalPrice = double.tryParse(priceCtrl.text) ?? 0.0;
      setState(() {
        if (quantity > 0 && totalPrice >= 0) {
          _calculatedUnitPrices[materialId] = totalPrice / quantity;
        } else {
          _calculatedUnitPrices[materialId] = 0.0;
        }
      });
    }
  }

  Widget _buildQuantityInputStep() {
    if (_step2ReceiptItems.isEmpty) {
      return const Center(
        child: Text('No items selected. Go back to select items.'),
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Form(
          key: _quantityPriceFormKey,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _step2ReceiptItems.length,
            itemBuilder: (context, index) {
              final receiptItem = _step2ReceiptItems[index];
              final material = receiptItem.material;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: Colors.blue[600],
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  material.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Unit: ${material.unitOfMeasure}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _quantityControllers[material.id],
                              focusNode: _quantityFocusNodes[material.id],
                              decoration: InputDecoration(
                                labelText: 'Quantity',
                                suffixText: material.unitOfMeasure,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                if (double.tryParse(value) == null ||
                                    double.parse(value) <= 0)
                                  return 'Must be > 0';
                                return null;
                              },
                              onChanged: (_) =>
                                  _updateCalculatedUnitPrice(material.id),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceControllers[material.id],
                              focusNode: _priceFocusNodes[material.id],
                              decoration: InputDecoration(
                                labelText: 'Total Price',
                                prefixText: '€',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) {
                                if (value == null || value.isEmpty)
                                  return 'Required';
                                if (double.tryParse(value) == null ||
                                    double.parse(value) < 0)
                                  return 'Must be >= 0';
                                return null;
                              },
                              onChanged: (_) =>
                                  _updateCalculatedUnitPrice(material.id),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calculate,
                              color: Colors.green[600],
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Price per ${material.unitOfMeasure}: €${(_calculatedUnitPrices[material.id] ?? 0.0).toStringAsFixed(3)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildReviewAndImageStep() {
    double grandTotal = _step2ReceiptItems.fold(0.0, (sum, item) {
      double itemTotalPrice =
          double.tryParse(_priceControllers[item.material.id]?.text ?? '0') ??
          0.0;
      return sum + itemTotalPrice;
    });

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green[600]!, Colors.green[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.withOpacity(0.3),
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
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Receipt Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_step2ReceiptItems.length} items • €${grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Items list
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _step2ReceiptItems.length,
                itemBuilder: (context, index) {
                  final item = _step2ReceiptItems[index];
                  final qtyCtrl = _quantityControllers[item.material.id];
                  final priceCtrl = _priceControllers[item.material.id];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_outlined,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                      ),
                      title: Text(
                        item.material.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Qty: ${qtyCtrl?.text ?? 'N/A'} ${item.material.unitOfMeasure}\nTotal: €${priceCtrl?.text ?? 'N/A'}',
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
              // Receipt details form
              Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _overallWholesalerController,
                        decoration: InputDecoration(
                          labelText: 'Wholesaler Name (Optional)',
                          prefixIcon: const Icon(Icons.store),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _overallReceiptDateController,
                        decoration: InputDecoration(
                          labelText: 'Receipt Date',
                          hintText: 'YYYY-MM-DD',
                          prefixIcon: const Icon(Icons.calendar_today),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.date_range),
                            onPressed: () => _selectReceiptDate(context),
                          ),
                        ),
                        readOnly: true,
                        onTap: () => _selectReceiptDate(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Image upload section
              Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Receipt Image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_receiptImageFile != null) ...[
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(_receiptImageFile!.path),
                              height: 200,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Center(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.blue[600]!, Colors.blue[400]!],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _pickImage,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_a_photo_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _receiptImageFile == null
                                          ? 'Add Receipt Image'
                                          : 'Change Image',
                                      style: const TextStyle(
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
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveReceipt() async {
    if (_step2ReceiptItems.isEmpty) {
      _showWarningSnackBar('No items to save.');
      return;
    }
    setState(() => _isSavingReceipt = true);

    String? uploadedReceiptImageUrl;
    if (_receiptImageFile != null) {
      try {
        final String fileExtension = _receiptImageFile!.path.split('.').last;
        final String fileName =
            'receipt_images/${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        await _supabase.storage
            .from('receipt_images')
            .upload(fileName, File(_receiptImageFile!.path));
        uploadedReceiptImageUrl = _supabase.storage
            .from('receipt_images')
            .getPublicUrl(fileName);
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Error uploading receipt image: $e');
        setState(() => _isSavingReceipt = false);
        return;
      }
    }

    final double finalTotalAmount = _step2ReceiptItems.fold(0.0, (sum, item) {
      double itemTotalPrice =
          double.tryParse(_priceControllers[item.material.id]?.text ?? '0') ??
          0.0;
      return sum + itemTotalPrice;
    });

    try {
      final receiptInsertResponse = await _supabase
          .from('receipts')
          .insert({
            'receipt_image_url': uploadedReceiptImageUrl,
            'total_amount': finalTotalAmount,
            'source_details': 'Manual Receipt Entry via App',
            'user_id': _supabase.auth.currentUser?.id,
            'wholesaler_name': _overallWholesalerController.text.isNotEmpty
                ? _overallWholesalerController.text
                : null,
            'receipt_date': _selectedReceiptDate?.toIso8601String(),
          })
          .select('id')
          .single();

      final String newReceiptId = receiptInsertResponse['id'] as String;

      for (final receiptItem in _step2ReceiptItems) {
        final material = receiptItem.material;
        final quantityChange =
            double.tryParse(_quantityControllers[material.id]?.text ?? '0') ??
            0;
        final itemTotalPrice =
            double.tryParse(_priceControllers[material.id]?.text ?? '0') ?? 0;

        if (quantityChange <= 0) continue;

        final double unitPrice = (quantityChange > 0 && itemTotalPrice >= 0)
            ? itemTotalPrice / quantityChange
            : 0;

        final materialRecord = await _supabase
            .from('material')
            .select('current_quantity, average_unit_cost')
            .eq('id', material.id)
            .single();

        final double oldQuantity =
            (materialRecord['current_quantity'] as num?)?.toDouble() ?? 0.0;
        final double oldWeightedAverageCost =
            (materialRecord['average_unit_cost'] as num?)?.toDouble() ?? 0.0;

        final double oldTotalValue = oldQuantity * oldWeightedAverageCost;
        final double addedValue = itemTotalPrice;

        final double newTotalQuantity = oldQuantity + quantityChange;
        final double newOverallTotalValue = oldTotalValue + addedValue;
        final double newWeightedAverageCost = (newTotalQuantity > 0)
            ? newOverallTotalValue / newTotalQuantity
            : 0;

        await _supabase
            .from('material')
            .update({
              'current_quantity': newTotalQuantity,
              'average_unit_cost': newWeightedAverageCost,
            })
            .eq('id', material.id);

        await _supabase.from('inventory_log').insert({
          'material_id': material.id,
          'material_name': material.name,
          'change_type': 'MANUAL_RECEIPT',
          'quantity_change': quantityChange,
          'new_quantity_after_change': newTotalQuantity,
          'unit_price_paid': unitPrice,
          'total_price_paid': itemTotalPrice,
          'source_details':
              'Manual Receipt App (Wholesaler: ${_overallWholesalerController.text.isNotEmpty ? _overallWholesalerController.text : "N/A"})',
          'receipt_id': newReceiptId,
          'user_id': _supabase.auth.currentUser?.id,
        });
      }

      if (!mounted) return;
      _showSuccessSnackBar('Receipt saved successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Error saving receipt: $e');
    } finally {
      if (mounted) {
        setState(() => _isSavingReceipt = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget currentStepWidget;
    switch (_currentStep) {
      case ManualReceiptStep.selectItems:
        currentStepWidget = _buildItemSelectionStep();
        break;
      case ManualReceiptStep.enterQuantitiesAndPrices:
        currentStepWidget = _buildQuantityInputStep();
        break;
      case ManualReceiptStep.reviewAndUploadImage:
        currentStepWidget = _buildReviewAndImageStep();
        break;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _getStepTitle(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        leading: _currentStep != ManualReceiptStep.selectItems
            ? Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _goToPreviousStep,
                ),
              )
            : null,
        actions: [
          if (_currentStep == ManualReceiptStep.reviewAndUploadImage)
            Container(
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[600]!, Colors.green[400]!],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _isSavingReceipt ? null : _saveReceipt,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: _isSavingReceipt
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.save, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
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
      body: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: currentStepWidget),
        ],
      ),
      floatingActionButton:
          _currentStep != ManualReceiptStep.reviewAndUploadImage
          ? Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.indigo[600]!, Colors.indigo[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: _goToNextStep,
                backgroundColor: Colors.transparent,
                elevation: 0,
                label: Text(
                  _currentStep == ManualReceiptStep.selectItems
                      ? 'Next: Enter Details'
                      : 'Next: Review',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, color: Colors.white),
              ),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case ManualReceiptStep.selectItems:
        return 'Step 1: Select Materials';
      case ManualReceiptStep.enterQuantitiesAndPrices:
        return 'Step 2: Quantities & Prices';
      case ManualReceiptStep.reviewAndUploadImage:
        return 'Step 3: Review & Upload';
      default:
        return 'Manual Receipt';
    }
  }

  String _getShortStepTitle(ManualReceiptStep step) {
    switch (step) {
      case ManualReceiptStep.selectItems:
        return 'Select Items';
      case ManualReceiptStep.enterQuantitiesAndPrices:
        return 'Details';
      case ManualReceiptStep.reviewAndUploadImage:
        return 'Review';
      default:
        return '';
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[600]!, Colors.indigo[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ManualReceiptStep.values.map((step) {
          bool isActive = step == _currentStep;
          bool isCompleted = step.index < _currentStep.index;
          return Column(
            children: [
              Container(
                width: isActive ? 40 : 32,
                height: isActive ? 40 : 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? Colors.green[500]
                      : isActive
                      ? Colors.white
                      : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: isCompleted
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : Center(
                        child: Text(
                          '${step.index + 1}',
                          style: TextStyle(
                            color: isActive ? Colors.indigo[600] : Colors.white,
                            fontSize: isActive ? 16 : 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                _getShortStepTitle(step),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
