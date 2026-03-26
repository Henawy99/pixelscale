import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Model for order type configuration (can be moved to a separate models file later)
class OrderTypeConfig {
  final String id;
  final String brandId;
  String name;
  double percentageCut;
  double serviceFee;
  bool isActive;
  int displayOrder;
  final DateTime createdAt;
  DateTime? updatedAt;

  OrderTypeConfig({
    required this.id,
    required this.brandId,
    required this.name,
    this.percentageCut = 0.0,
    this.serviceFee = 0.0,
    this.isActive = true,
    this.displayOrder = 0,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderTypeConfig.fromJson(Map<String, dynamic> json) {
    return OrderTypeConfig(
      id: json['id'] as String,
      brandId: json['brand_id'] as String,
      name: json['name'] as String,
      percentageCut: (json['percentage_cut'] as num?)?.toDouble() ?? 0.0,
      serviceFee: (json['service_fee'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'brand_id': brandId,
      'name': name,
      'percentage_cut': percentageCut,
      'service_fee': serviceFee,
      'is_active': isActive,
      'display_order': displayOrder,
      // 'created_at': createdAt.toIso8601String(), // Usually handled by DB
      'updated_at': DateTime.now().toIso8601String(), // Set on update
    };
  }

  Map<String, dynamic> toJsonForInsert(String currentBrandId) {
    return {
      'brand_id': currentBrandId, // Ensure brand_id is set for new records
      'name': name,
      'percentage_cut': percentageCut,
      'service_fee': serviceFee,
      'is_active': isActive,
      'display_order': displayOrder,
    };
  }
}

class OrderTypeSettingsScreen extends StatefulWidget {
  final String
  brandId; // Assuming this screen is accessed in context of a brand

  const OrderTypeSettingsScreen({super.key, required this.brandId});

  @override
  State<OrderTypeSettingsScreen> createState() =>
      _OrderTypeSettingsScreenState();
}

class _OrderTypeSettingsScreenState extends State<OrderTypeSettingsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<OrderTypeConfig> _orderTypeConfigs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchOrderTypeConfigs();
  }

  Future<void> _fetchOrderTypeConfigs() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _supabase
          .from('order_type_configs')
          .select()
          .eq('brand_id', widget.brandId) // Filter by current brand
          .order('display_order', ascending: true)
          .order('name', ascending: true);

      if (!mounted) return;
      _orderTypeConfigs = (response as List)
          .map((data) => OrderTypeConfig.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching order type configs: $e');
      if (mounted) _error = 'Failed to load configurations: $e';
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEditDialog({OrderTypeConfig? config}) async {
    final formKey = GlobalKey<FormState>();
    String name = config?.name ?? '';
    // Percentage cut should be stored as decimal (e.g., 0.15 for 15%) but displayed as percentage
    TextEditingController percentageCutController = TextEditingController(
      text: config != null
          ? (config.percentageCut * 100).toStringAsFixed(2)
          : '',
    );
    TextEditingController serviceFeeController = TextEditingController(
      text: config?.serviceFee.toStringAsFixed(2) ?? '',
    );
    bool isActive = config?.isActive ?? true;
    // int displayOrder = config?.displayOrder ?? 0; // For simplicity, not editing display_order in this dialog for now

    OrderTypeConfig? result = await showDialog<OrderTypeConfig>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // For updating isActive switch
            return AlertDialog(
              title: Text(
                config == null ? 'Add New Order Type' : 'Edit Order Type',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        initialValue: name,
                        decoration: const InputDecoration(
                          labelText: 'Name*',
                          hintText: 'e.g., Lieferando, Wolt',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Name is required.';
                          return null;
                        },
                        onChanged: (value) => name = value,
                      ),
                      TextFormField(
                        controller: percentageCutController,
                        decoration: const InputDecoration(
                          labelText: 'Percentage Cut (%)*',
                          hintText: 'e.g., 15.00 for 15%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Percentage cut is required (can be 0).';
                          final p = double.tryParse(value);
                          if (p == null || p < 0 || p > 100)
                            return 'Enter a valid percentage (0-100).';
                          return null;
                        },
                      ),
                      TextFormField(
                        controller: serviceFeeController,
                        decoration: const InputDecoration(
                          labelText: 'Fixed Service Fee (€)*',
                          hintText: 'e.g., 0.50',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Service fee is required (can be 0).';
                          final f = double.tryParse(value);
                          if (f == null || f < 0)
                            return 'Enter a valid fee (>= 0).';
                          return null;
                        },
                      ),
                      SwitchListTile(
                        title: const Text('Active'),
                        value: isActive,
                        onChanged: (bool value) {
                          setDialogState(() {
                            // Use setDialogState for changes within the dialog
                            isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                ElevatedButton(
                  child: Text(config == null ? 'Add' : 'Save'),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      formKey.currentState!
                          .save(); // Not strictly needed with onChanged/controllers for simple fields

                      final double percentageCut =
                          (double.tryParse(percentageCutController.text) ??
                              0.0) /
                          100.0; // Convert to decimal
                      final double serviceFee =
                          double.tryParse(serviceFeeController.text) ?? 0.0;

                      try {
                        if (config == null) {
                          // Add new
                          final newConfigMap = OrderTypeConfig(
                            id: '', // Will be generated by DB or ignored
                            brandId: widget.brandId,
                            name: name,
                            percentageCut: percentageCut,
                            serviceFee: serviceFee,
                            isActive: isActive,
                            createdAt:
                                DateTime.now(), // Temp, DB will set actual
                          ).toJsonForInsert(widget.brandId);

                          await _supabase
                              .from('order_type_configs')
                              .insert(newConfigMap);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order type added!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          // Update existing
                          Map<String, dynamic> updateData = {
                            'name': name,
                            'percentage_cut': percentageCut,
                            'service_fee': serviceFee,
                            'is_active': isActive,
                            'updated_at': DateTime.now().toIso8601String(),
                          };
                          await _supabase
                              .from('order_type_configs')
                              .update(updateData)
                              .eq('id', config.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Order type updated!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                        Navigator.of(dialogContext).pop(
                          OrderTypeConfig(
                            id: '',
                            brandId: '',
                            name: 'dummy',
                            createdAt: DateTime.now(),
                          ),
                        ); // Pop with a dummy to indicate success
                      } catch (e) {
                        print("Error saving order type config: $e");
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        // Optionally, don't pop dialog on error
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      // If dialog was popped with a success indicator
      _fetchOrderTypeConfigs(); // Refresh the list
    }
  }

  // TODO: Implement _deleteConfig

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Type Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchOrderTypeConfigs,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red),
              ),
            )
          : _orderTypeConfigs.isEmpty
          ? const Center(
              child: Text(
                'No order type configurations found. Tap + to add one.',
              ),
            )
          : ListView.builder(
              itemCount: _orderTypeConfigs.length,
              itemBuilder: (context, index) {
                final config = _orderTypeConfigs[index];
                return ListTile(
                  title: Text(config.name),
                  subtitle: Text(
                    'Cut: ${(config.percentageCut * 100).toStringAsFixed(2)}% + Fee: ${config.serviceFee.toStringAsFixed(2)}€',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: config.isActive,
                        onChanged: (value) async {
                          // TODO: Implement direct toggle or through edit dialog
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _showEditDialog(config: config),
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditDialog(),
        tooltip: 'Add Order Type', // Call with no config to add new
        child: const Icon(Icons.add),
      ),
    );
  }
}
