import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReceiptEditDialog extends StatefulWidget {
  final Map<String, dynamic> scannedData;
  final Uint8List? receiptImageBytes;
  final String? receiptImagePath;

  const ReceiptEditDialog({
    super.key,
    required this.scannedData,
    this.receiptImageBytes,
    this.receiptImagePath,
  });

  @override
  State<ReceiptEditDialog> createState() => _ReceiptEditDialogState();
}

class _ReceiptEditDialogState extends State<ReceiptEditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  bool _isSaving = false;

  // Controllers for editable fields
  late TextEditingController _brandNameController;
  late TextEditingController _platformOrderIdController;
  late TextEditingController _totalPriceController;
  late TextEditingController _deliveryFeeController;
  late TextEditingController _customerNameController;
  late TextEditingController _customerStreetController;
  late TextEditingController _customerPostcodeController;
  late TextEditingController _customerCityController;
  late TextEditingController _noteController;
  late TextEditingController _orderTypeNameController;
  late TextEditingController _commissionAmountController;
  
  late DateTime _selectedDate;
  late DateTime _selectedDeliveryTime;
  late String _paymentMethod;
  late String _fulfillmentType;

  List<Map<String, dynamic>> _orderItems = [];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final data = widget.scannedData;
    
    _brandNameController = TextEditingController(text: data['brandName']?.toString() ?? '');
    _platformOrderIdController = TextEditingController(text: data['platformOrderId']?.toString() ?? '');
    _totalPriceController = TextEditingController(text: (data['totalPrice'] ?? 0.0).toString());
    _deliveryFeeController = TextEditingController(text: (data['deliveryFee'] ?? 0.0).toString());
    _customerNameController = TextEditingController(text: data['customerName']?.toString() ?? '');
    _customerStreetController = TextEditingController(text: data['customerStreet']?.toString() ?? '');
    _customerPostcodeController = TextEditingController(text: data['customerPostcode']?.toString() ?? '');
    _customerCityController = TextEditingController(text: data['customerCity']?.toString() ?? '');
    _noteController = TextEditingController(text: data['note']?.toString() ?? '');
    _orderTypeNameController = TextEditingController(text: data['orderTypeName']?.toString() ?? '');
    _commissionAmountController = TextEditingController(text: (data['commissionAmount'] ?? 0.0).toString());

    // Parse dates
    _selectedDate = _parseDate(data['createdAt'] ?? data['orderDate']) ?? DateTime.now();
    _selectedDeliveryTime = _parseDate(data['requestedDeliveryTime']) ?? DateTime.now();
    
    _paymentMethod = data['paymentMethod']?.toString() ?? 'cash';
    _fulfillmentType = data['fulfillmentType']?.toString() ?? 'delivery';

    // Copy order items
    if (data['orderItems'] is List) {
      _orderItems = List<Map<String, dynamic>>.from(data['orderItems'] as List);
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  @override
  void dispose() {
    _brandNameController.dispose();
    _platformOrderIdController.dispose();
    _totalPriceController.dispose();
    _deliveryFeeController.dispose();
    _customerNameController.dispose();
    _customerStreetController.dispose();
    _customerPostcodeController.dispose();
    _customerCityController.dispose();
    _noteController.dispose();
    _orderTypeNameController.dispose();
    _commissionAmountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
      );
      if (time != null) {
        setState(() {
          _selectedDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectDeliveryTime() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDeliveryTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDeliveryTime),
      );
      if (time != null) {
        setState(() {
          _selectedDeliveryTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveToReceiptWatcher() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Build the updated extracted data
      final extractedData = {
        'classification': 'order',
        'brandName': _brandNameController.text,
        'platformOrderId': _platformOrderIdController.text.isEmpty ? null : _platformOrderIdController.text,
        'orderDate': _selectedDate.toIso8601String(),
        'fulfillmentType': _fulfillmentType,
        'totalPrice': double.tryParse(_totalPriceController.text) ?? 0.0,
        'deliveryFee': double.tryParse(_deliveryFeeController.text) ?? 0.0,
        'paymentMethod': _paymentMethod,
        'customerName': _customerNameController.text.isEmpty ? null : _customerNameController.text,
        'customerStreet': _customerStreetController.text.isEmpty ? null : _customerStreetController.text,
        'customerPostcode': _customerPostcodeController.text.isEmpty ? null : _customerPostcodeController.text,
        'customerCity': _customerCityController.text.isEmpty ? null : _customerCityController.text,
        'orderItems': _orderItems,
        'note': _noteController.text.isEmpty ? null : _noteController.text,
        'orderTypeName': _orderTypeNameController.text.isEmpty ? null : _orderTypeNameController.text,
        'commissionAmount': double.tryParse(_commissionAmountController.text),
        'createdAt': _selectedDate.toIso8601String(),
        'requestedDeliveryTime': _selectedDeliveryTime.toIso8601String(),
      };

      // Upload image if available
      String? storagePath;
      if (widget.receiptImageBytes != null) {
        final fileName = 'test_receipts/${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('receipt_images').uploadBinary(
          fileName,
          widget.receiptImageBytes!,
        );
        storagePath = fileName;
      } else if (widget.receiptImagePath != null) {
        // Reference existing path
        storagePath = widget.receiptImagePath;
      }

      // Save to scanned_receipts table
      await _supabase.from('scanned_receipts').insert({
        'scan_type': 'order',
        'storage_path': storagePath,
        'raw_json': jsonEncode(extractedData),
        'extracted_data': extractedData,
        'brand_name': _brandNameController.text.isEmpty ? null : _brandNameController.text,
        'supplier_name': null,
      });

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Receipt saved to Receipt Watcher successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Edit Receipt'),
        backgroundColor: Colors.orange,
        actions: [
          IconButton(
            icon: _isSaving 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _saveToReceiptWatcher,
            tooltip: 'Save to Receipt Watcher',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Test Mode Banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.science, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TEST MODE: Edit receipt data before saving to Receipt Watcher',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Basic Info Section
              _buildSectionTitle('Basic Information'),
              _buildTextField('Brand Name', _brandNameController),
              _buildTextField('Platform Order ID', _platformOrderIdController),
              _buildTextField('Order Type Name', _orderTypeNameController),
              
              const SizedBox(height: 20),

              // Date & Time Section
              _buildSectionTitle('Date & Time'),
              _buildDateField(
                'Order Date',
                _selectedDate,
                _selectDate,
              ),
              _buildDateField(
                'Delivery Time',
                _selectedDeliveryTime,
                _selectDeliveryTime,
              ),
              
              const SizedBox(height: 20),

              // Order Details Section
              _buildSectionTitle('Order Details'),
              _buildDropdownField(
                'Fulfillment Type',
                _fulfillmentType,
                ['delivery', 'pickup', 'dine-in'],
                (value) => setState(() => _fulfillmentType = value!),
              ),
              _buildDropdownField(
                'Payment Method',
                _paymentMethod,
                ['cash', 'online', 'card', 'unknown'],
                (value) => setState(() => _paymentMethod = value!),
              ),
              
              const SizedBox(height: 20),

              // Financial Section
              _buildSectionTitle('Financial Details'),
              _buildTextField('Total Price (€)', _totalPriceController, isNumber: true),
              _buildTextField('Delivery Fee (€)', _deliveryFeeController, isNumber: true),
              _buildTextField('Note', _noteController, isNumber: false),
              _buildTextField('Commission Amount (€)', _commissionAmountController, isNumber: true),
              
              const SizedBox(height: 20),

              // Customer Info Section
              _buildSectionTitle('Customer Information'),
              _buildTextField('Customer Name', _customerNameController),
              _buildTextField('Street', _customerStreetController),
              _buildTextField('Postcode', _customerPostcodeController),
              _buildTextField('City', _customerCityController),
              
              const SizedBox(height: 20),

              // Order Items Section
              _buildSectionTitle('Order Items (${_orderItems.length})'),
              ..._orderItems.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(item['menuItemName']?.toString() ?? 'Unknown Item'),
                    subtitle: Text('Quantity: ${item['quantity'] ?? 1}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() => _orderItems.removeAt(index));
                      },
                    ),
                  ),
                );
              }),
              
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveToReceiptWatcher,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_isSaving ? 'Saving...' : 'Save to Receipt Watcher'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
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

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.orange,
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        validator: isNumber
            ? (value) {
                if (value != null && value.isNotEmpty) {
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildDateField(
    String label,
    DateTime date,
    VoidCallback onTap,
  ) {
    final formatter = DateFormat('MMM dd, yyyy HH:mm');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: Colors.grey.shade50,
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          child: Text(formatter.format(date)),
        ),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    void Function(String?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
        items: options.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option.toUpperCase()),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

