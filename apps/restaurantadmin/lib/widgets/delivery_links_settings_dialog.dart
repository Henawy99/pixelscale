import 'package:flutter/material.dart';
import 'package:restaurantadmin/models/brand.dart';
import 'package:restaurantadmin/services/ratings_scraper_service.dart';

class DeliveryLinksSettingsDialog extends StatefulWidget {
  final Brand brand;
  final Future<void> Function(Brand) onSave;

  const DeliveryLinksSettingsDialog({
    super.key,
    required this.brand,
    required this.onSave,
  });

  @override
  State<DeliveryLinksSettingsDialog> createState() => _DeliveryLinksSettingsDialogState();
}

class _DeliveryLinksSettingsDialogState extends State<DeliveryLinksSettingsDialog> {
  late TextEditingController _lieferandoController;
  late TextEditingController _foodoraController;
  late TextEditingController _foodoraSelfController;
  late TextEditingController _woltController;
  late TextEditingController _googleController;

  bool _isSaving = false;
  final RatingsScraperService _scraperService = RatingsScraperService();

  @override
  void initState() {
    super.initState();
    _lieferandoController = TextEditingController(text: widget.brand.lieferandoUrl ?? '');
    _foodoraController = TextEditingController(text: widget.brand.foodoraUrl ?? '');
    _foodoraSelfController = TextEditingController(text: widget.brand.foodoraSelfUrl ?? '');
    _woltController = TextEditingController(text: widget.brand.woltUrl ?? '');
    _googleController = TextEditingController(text: widget.brand.googleUrl ?? '');
  }

  @override
  void dispose() {
    _lieferandoController.dispose();
    _foodoraController.dispose();
    _foodoraSelfController.dispose();
    _woltController.dispose();
    _googleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    
    // Scrape ratings before saving
    double? newLiefRating = widget.brand.lieferandoRating;
    double? newFoodoraRating = widget.brand.foodoraRating;
    double? newFoodoraSelfRating = widget.brand.foodoraSelfRating;
    double? newWoltRating = widget.brand.woltRating;
    double? newGoogleRating = widget.brand.googleRating;

    try {
      if (_lieferandoController.text.isNotEmpty) {
        newLiefRating = await _scraperService.fetchRating(_lieferandoController.text, 'Lieferando') ?? newLiefRating;
      }
      if (_foodoraController.text.isNotEmpty) {
        newFoodoraRating = await _scraperService.fetchRating(_foodoraController.text, 'Foodora') ?? newFoodoraRating;
      }
      if (_foodoraSelfController.text.isNotEmpty) {
        newFoodoraSelfRating = await _scraperService.fetchRating(_foodoraSelfController.text, 'Foodora') ?? newFoodoraSelfRating;
      }
      if (_woltController.text.isNotEmpty) {
        newWoltRating = await _scraperService.fetchRating(_woltController.text, 'Wolt') ?? newWoltRating;
      }
      if (_googleController.text.isNotEmpty) {
        newGoogleRating = await _scraperService.fetchRating(_googleController.text, 'Google') ?? newGoogleRating;
      }
      
      final now = DateTime.now();
      final updatedBrand = Brand(
        id: widget.brand.id,
        createdAt: widget.brand.createdAt,
        name: widget.brand.name,
        description: widget.brand.description,
        imageUrl: widget.brand.imageUrl,
        lieferandoUrl: _lieferandoController.text.trim(),
        foodoraUrl: _foodoraController.text.trim(),
        foodoraSelfUrl: _foodoraSelfController.text.trim(),
        woltUrl: _woltController.text.trim(),
        googleUrl: _googleController.text.trim(),
        lieferandoRating: newLiefRating,
        foodoraRating: newFoodoraRating,
        foodoraSelfRating: newFoodoraSelfRating,
        woltRating: newWoltRating,
        googleRating: newGoogleRating,
        lieferandoReviewCount: widget.brand.lieferandoReviewCount,
        foodoraReviewCount: widget.brand.foodoraReviewCount,
        foodoraSelfReviewCount: widget.brand.foodoraSelfReviewCount,
        woltReviewCount: widget.brand.woltReviewCount,
        googleReviewCount: widget.brand.googleReviewCount,
        lieferandoUpdatedAt: _lieferandoController.text.trim().isNotEmpty ? now : widget.brand.lieferandoUpdatedAt,
        foodoraUpdatedAt: _foodoraController.text.trim().isNotEmpty ? now : widget.brand.foodoraUpdatedAt,
        foodoraSelfUpdatedAt: _foodoraSelfController.text.trim().isNotEmpty ? now : widget.brand.foodoraSelfUpdatedAt,
        woltUpdatedAt: _woltController.text.trim().isNotEmpty ? now : widget.brand.woltUpdatedAt,
        googleUpdatedAt: _googleController.text.trim().isNotEmpty ? now : widget.brand.googleUpdatedAt,
      );

      await widget.onSave(updatedBrand);
      
      // Check for low ratings
      final lowRatings = {
        'Lieferando': newLiefRating,
        'Foodora': newFoodoraRating,
        'Foodora Self': newFoodoraSelfRating,
        'Wolt': newWoltRating,
        'Google': newGoogleRating,
      };
      for (final entry in lowRatings.entries) {
        if (entry.value != null && entry.value! < 4.0) {
          await _scraperService.showLowRatingNotification(updatedBrand.name, entry.key, entry.value!);
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving links: $e')),
        );
      }
      setState(() => _isSaving = false);
    }
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          isDense: true,
        ),
        style: const TextStyle(fontSize: 13),
        keyboardType: TextInputType.url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${widget.brand.name} Delivery Links',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildTextField('Lieferando URL', _lieferandoController, Icons.delivery_dining),
              _buildTextField('Foodora URL (Platform Delivery)', _foodoraController, Icons.fastfood,
                  hint: 'Platform delivery page'),
              _buildTextField('Foodora URL (Self-Delivery)', _foodoraSelfController, Icons.local_shipping,
                  hint: 'Own delivery page'),
              _buildTextField('Wolt URL', _woltController, Icons.electric_bike),
              _buildTextField('Google Profile URL', _googleController, Icons.search),
              const SizedBox(height: 20),
              _isSaving
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save & Scrape Ratings'),
                    ),
              const SizedBox(height: 8),
              if (!_isSaving)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
