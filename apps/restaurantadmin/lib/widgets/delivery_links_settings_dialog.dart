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
  late TextEditingController _woltController;
  late TextEditingController _googleController;

  bool _isSaving = false;
  final RatingsScraperService _scraperService = RatingsScraperService();

  @override
  void initState() {
    super.initState();
    _lieferandoController = TextEditingController(text: widget.brand.lieferandoUrl ?? '');
    _foodoraController = TextEditingController(text: widget.brand.foodoraUrl ?? '');
    _woltController = TextEditingController(text: widget.brand.woltUrl ?? '');
    _googleController = TextEditingController(text: widget.brand.googleUrl ?? '');
  }

  @override
  void dispose() {
    _lieferandoController.dispose();
    _foodoraController.dispose();
    _woltController.dispose();
    _googleController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSaving = true);
    
    // Scrape ratings before saving
    double? newLiefRating = widget.brand.lieferandoRating;
    double? newFoodoraRating = widget.brand.foodoraRating;
    double? newWoltRating = widget.brand.woltRating;
    double? newGoogleRating = widget.brand.googleRating;

    try {
      if (_lieferandoController.text.isNotEmpty) {
        newLiefRating = await _scraperService.fetchRating(_lieferandoController.text, 'Lieferando') ?? newLiefRating;
      }
      if (_foodoraController.text.isNotEmpty) {
        newFoodoraRating = await _scraperService.fetchRating(_foodoraController.text, 'Foodora') ?? newFoodoraRating;
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
        woltUrl: _woltController.text.trim(),
        googleUrl: _googleController.text.trim(),
        lieferandoRating: newLiefRating,
        foodoraRating: newFoodoraRating,
        woltRating: newWoltRating,
        googleRating: newGoogleRating,
        lieferandoReviewCount: widget.brand.lieferandoReviewCount,
        foodoraReviewCount: widget.brand.foodoraReviewCount,
        woltReviewCount: widget.brand.woltReviewCount,
        googleReviewCount: widget.brand.googleReviewCount,
        lieferandoUpdatedAt: _lieferandoController.text.trim().isNotEmpty ? now : widget.brand.lieferandoUpdatedAt,
        foodoraUpdatedAt: _foodoraController.text.trim().isNotEmpty ? now : widget.brand.foodoraUpdatedAt,
        woltUpdatedAt: _woltController.text.trim().isNotEmpty ? now : widget.brand.woltUpdatedAt,
        googleUpdatedAt: _googleController.text.trim().isNotEmpty ? now : widget.brand.googleUpdatedAt,
      );

      await widget.onSave(updatedBrand);
      
      // Check for low ratings
      if (newLiefRating != null && newLiefRating < 4.0) {
        await _scraperService.showLowRatingNotification(updatedBrand.name, 'Lieferando', newLiefRating);
      }
      if (newFoodoraRating != null && newFoodoraRating < 4.0) {
        await _scraperService.showLowRatingNotification(updatedBrand.name, 'Foodora', newFoodoraRating);
      }
      if (newWoltRating != null && newWoltRating < 4.0) {
        await _scraperService.showLowRatingNotification(updatedBrand.name, 'Wolt', newWoltRating);
      }
      if (newGoogleRating != null && newGoogleRating < 4.0) {
        await _scraperService.showLowRatingNotification(updatedBrand.name, 'Google', newGoogleRating);
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

  Widget _buildTextField(String label, TextEditingController controller, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.url,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
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
              _buildTextField('Foodora URL', _foodoraController, Icons.fastfood),
              _buildTextField('Wolt URL', _woltController, Icons.electric_bike),
              _buildTextField('Google Profile URL', _googleController, Icons.search),
              const SizedBox(height: 24),
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
