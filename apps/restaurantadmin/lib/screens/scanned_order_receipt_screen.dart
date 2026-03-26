import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:cross_file/cross_file.dart';

class ScannedOrderReceiptScreen extends StatefulWidget {
  static const String routeName = '/scanned-order-receipt';
  const ScannedOrderReceiptScreen({super.key});

  @override
  State<ScannedOrderReceiptScreen> createState() =>
      _ScannedOrderReceiptScreenState();
}

class _ScannedOrderReceiptScreenState extends State<ScannedOrderReceiptScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _fileName;
  Uint8List? _fileBytes;
  bool _isDragging = false;

  bool _isProcessing = false;
  bool _isSaving = false;
  bool _receiptSaved = false;
  String? _processingMessage;
  bool _processingSuccess = false;
  Map<String, dynamic>? _analysisResult;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() {
          _fileBytes = result.files.single.bytes;
          _fileName = result.files.single.name;
          _processingMessage = null;
          _analysisResult = null;
          _receiptSaved = false;
        });
      } else {
        setState(() {
          _fileName = null;
          _fileBytes = null;
        });
         if (result != null && result.files.single.bytes == null && mounted) {
          _showSnackBar('Could not read file content. Please try again.', isError: true);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Error picking file: ${e.toString()}', isError: true);
    }
  }

  Future<void> _handleDroppedFiles(List<XFile> files) async {
    if (files.isEmpty) return;
    
    final file = files.first;
    final fileName = file.name.toLowerCase();
    
    if (!fileName.endsWith('.jpg') && 
        !fileName.endsWith('.jpeg') && 
        !fileName.endsWith('.png') && 
        !fileName.endsWith('.pdf')) {
      _showSnackBar('Please drop a valid image file (jpg, jpeg, png, pdf)', isError: true);
      return;
    }

    try {
      final bytes = await file.readAsBytes();
      setState(() {
        _fileBytes = bytes;
        _fileName = file.name;
        _processingMessage = null;
        _analysisResult = null;
        _receiptSaved = false;
      });
    } catch (e) {
      _showSnackBar('Error reading file: ${e.toString()}', isError: true);
    }
  }

  Future<void> _processReceipt() async {
    if (_fileBytes == null) {
      _showSnackBar('Please select a receipt image file.', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingMessage = 'Encoding image...';
      _processingSuccess = false;
      _analysisResult = null;
      _receiptSaved = false;
    });

    try {
      // Convert image bytes to base64
      final base64Image = base64Encode(_fileBytes!);

      setState(() => _processingMessage = 'Analyzing receipt with AI...');

      // Call the scan-receipt edge function, passing base64 data
      final response = await _supabase.functions.invoke(
        'scan-receipt',
        body: {
          'receiptImageBase64': base64Image,
          'noSave': true, // Prevent auto-saving
        },
      );

      if (!mounted) return;
      
      final responseData = response.data;

      if (responseData != null) {
        setState(() {
          _analysisResult = Map<String, dynamic>.from(responseData);
          
          if (responseData['ok'] == true) {
            final detectedType = responseData['type'] ?? 'unknown';
            _processingMessage = 'Receipt classified as: ${detectedType.toUpperCase()}';
            _processingSuccess = true;
          } else if (responseData['error'] != null) {
            _processingMessage = 'Error: ${responseData['error']}';
            _processingSuccess = false;
          } else {
            _processingMessage = 'Receipt processed - check details below';
            _processingSuccess = true;
          }
        });
      } else {
        throw Exception('No response data received');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _processingMessage = 'Error: ${e.toString()}';
        _processingSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _saveToWatcher() async {
    if (_analysisResult == null || !(_analysisResult!['ok'] == true)) return;

    setState(() {
      _isSaving = true;
      _processingMessage = 'Saving to Receipt Watcher...';
    });

    try {
      final extractedData = _analysisResult!['extracted_data'] as Map<String, dynamic>;
      final scanType = _analysisResult!['type'] as String;
      final brandName = scanType == 'order' ? extractedData['brandName'] : null;
      final supplierName = scanType == 'purchase' ? extractedData['supplierName'] : null;

      await _supabase.from('scanned_receipts').insert({
        'scan_type': scanType,
        'storage_path': _analysisResult!['storage_path'],
        'raw_json': jsonEncode(extractedData),
        'extracted_data': extractedData,
        'brand_name': brandName,
        'supplier_name': supplierName,
      });

      // Send push notification after saving
      try {
        final isOrder = scanType == 'order';
        final amount = isOrder ? extractedData['totalPrice'] : extractedData['totalAmount'];
        final formattedAmount = amount != null ? '€${(amount as num).toStringAsFixed(2)}' : 'N/A';
        
        debugPrint('[PushNotification] Sending notification: $scanType, Amount: $formattedAmount');
        
        // Call edge function to send notification
        final response = await _supabase.functions.invoke('send-push-notification', body: {
          'title': isOrder ? 'New Order Scanned' : 'New Purchase Scanned',
          'body': isOrder 
              ? 'New Order, Total $formattedAmount'
              : 'New Purchase, Total $formattedAmount',
          'data': {
            'type': scanType,
            'amount': amount?.toString() ?? '0',
            'storagePath': _analysisResult!['storage_path'] ?? '',
          },
        });
        
        debugPrint('[PushNotification] Response: ${response.data}');
      } catch (notificationError) {
        // Don't fail the save if notification fails
        debugPrint('[PushNotification] ERROR: $notificationError');
        
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Notification failed: $notificationError'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _receiptSaved = true;
          _processingMessage = 'Successfully saved to Receipt Watcher!';
          _processingSuccess = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _processingMessage = 'Error saving to watcher: ${e.toString()}';
          _processingSuccess = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Receipt Scanner'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: DropTarget(
        onDragEntered: (_) => setState(() => _isDragging = true),
        onDragExited: (_) => setState(() => _isDragging = false),
        onDragDone: (details) {
          setState(() => _isDragging = false);
          _handleDroppedFiles(details.files);
        },
        child: Container(
          color: _isDragging ? const Color.fromRGBO(33, 150, 243, 0.1) : null,
          child: SingleChildScrollView(
            child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                      const SizedBox(height: 20),
                      
                      // Info Banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color.fromRGBO(33, 150, 243, 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color.fromRGBO(33, 150, 243, 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'AI will automatically classify the receipt as either an Order or Purchase',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Drag & Drop Zone
                      Container(
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _isDragging ? Colors.blue : Colors.grey,
                            width: _isDragging ? 3 : 2,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          color: _isDragging 
                              ? const Color.fromRGBO(33, 150, 243, 0.05) 
                              : const Color.fromRGBO(158, 158, 158, 0.05),
                        ),
                        child: InkWell(
                          onTap: _pickFile,
                          borderRadius: BorderRadius.circular(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _isDragging ? Icons.file_download : Icons.cloud_upload,
                                size: 64,
                                color: _isDragging ? Colors.blue : Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _isDragging 
                                    ? 'Drop receipt image here' 
                                    : 'Drag & Drop receipt image here',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: _isDragging ? Colors.blue : Colors.grey[700],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'or click to browse',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Supported: JPG, JPEG, PNG, PDF',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_fileName != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(76, 175, 80, 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'File selected:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    Text(
                                      _fileName!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setState(() {
                                    _fileName = null;
                                    _fileBytes = null;
                                    _processingMessage = null;
                                    _analysisResult = null;
                                    _receiptSaved = false;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Process Button
                      FilledButton.icon(
                        onPressed: (_isProcessing || _fileBytes == null)
                            ? null
                            : _processReceipt,
                        icon: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(_isProcessing ? 'Analyzing...' : 'Process Receipt with AI'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: Colors.deepPurple,
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),

                      // Save to Watcher Button
                      if (_analysisResult != null && _analysisResult!['ok'] == true && !_receiptSaved) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _saveToWatcher,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.save),
                          label: const Text('Save to Receipt Watcher'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                      
                      // Status Message
                      if (_processingMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _processingSuccess 
                                ? const Color.fromRGBO(76, 175, 80, 0.1) 
                                : const Color.fromRGBO(255, 152, 0, 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _processingSuccess ? Colors.green : Colors.orange,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _processingSuccess ? Icons.check_circle : Icons.info,
                                color: _processingSuccess ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                    child: Text(
                      _processingMessage!,
                      style: TextStyle(
                                    color: _processingSuccess ? Colors.green[900] : Colors.orange[900],
                                    fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
                          ),
                        ),
                      ],
                      
                      // Analysis Results
                      if (_analysisResult != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'AI Analysis Results',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color.fromRGBO(33, 150, 243, 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color.fromRGBO(33, 150, 243, 0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildResultRow('Status', _analysisResult!['ok'] == true ? 'Success' : 'Failed', 
                                  isHighlighted: _analysisResult!['ok'] == true),
                              _buildResultRow('Classified Type', _analysisResult!['type']?.toString().toUpperCase() ?? 'N/A'),
                              if (_analysisResult!['storage_path'] != null)
                                _buildResultRow('Storage Path', _analysisResult!['storage_path'].toString()),
                              if (_analysisResult!['error'] != null)
                                _buildResultRow('Error', _analysisResult!['error'].toString(), isError: true),
                              
                              if (_analysisResult!['extracted_data'] is Map) ...[
                                const Divider(height: 24),
                                const Text(
                                  'Extracted Details',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildExtractedDetails(_analysisResult!['extracted_data'] as Map<String, dynamic>),
                              ],

                              const Divider(height: 24),
                              const Text(
                                'Raw Response:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: SelectableText(
                                  _analysisResult.toString(),
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Note: This function only analyzes and saves the receipt. It does not create an Order or Purchase record.',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtractedDetails(Map<String, dynamic> data) {
    final classification = data['classification']?.toString() ?? 'unknown';

    switch (classification) {
      case 'order':
        final items = data['orderItems'] as List<dynamic>? ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('Classification', data['classification']?.toString() ?? 'N/A'),
            _buildResultRow('Brand Name', data['brandName']?.toString() ?? 'N/A'),
            _buildResultRow('Platform Order ID', data['platformOrderId']?.toString() ?? 'N/A'),
            _buildResultRow('Order Date', data['orderDate']?.toString() ?? 'N/A'),
            _buildResultRow('Total Price', data['totalPrice']?.toString() ?? 'N/A'),
            _buildResultRow('Delivery Fee', data['deliveryFee']?.toString() ?? 'N/A'),
            _buildResultRow('Payment Method', data['paymentMethod']?.toString() ?? 'N/A'),
            _buildResultRow('Customer Name', data['customerName']?.toString() ?? 'N/A'),
            _buildResultRow('Customer Address', '${data['customerStreet'] ?? ''}, ${data['customerPostcode'] ?? ''} ${data['customerCity'] ?? ''}'),
            if (items.isNotEmpty) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 140,
                      child: Text(
                        'Order Items:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('- ${item['quantity']}x ${item['name']} @ ${item['price']}'),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]
          ],
        );
      case 'purchase':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('Classification', data['classification']?.toString() ?? 'N/A'),
            _buildResultRow('Supplier Name', data['supplierName']?.toString() ?? 'N/A'),
            _buildResultRow('Total Amount', data['totalAmount']?.toString() ?? 'N/A'),
            _buildResultRow('Receipt Date', data['receiptDate']?.toString() ?? 'N/A'),
          ],
        );
      case 'unknown':
      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow('Classification', data['classification']?.toString() ?? 'N/A'),
            _buildResultRow('Comment', data['comment']?.toString() ?? 'N/A', isError: true),
          ],
        );
    }
  }

  Widget _buildResultRow(String label, String value, {bool isHighlighted = false, bool isError = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: isError ? Colors.red[700] : (isHighlighted ? Colors.green[700] : Colors.black87),
                fontWeight: (isHighlighted || isError) ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
