import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:restaurantadmin/config/delivery_zones.dart';
import 'package:restaurantadmin/config/online_brands.dart';
import 'package:restaurantadmin/models/cart_item.dart';
import 'package:restaurantadmin/providers/cart_provider.dart';
import 'package:restaurantadmin/services/public_web_order_service.dart';
import 'package:restaurantadmin/widgets/public/delivery_zones_card.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PublicCheckoutPanel extends StatefulWidget {
  final OnlineBrandConfig brand;

  const PublicCheckoutPanel({super.key, required this.brand});

  @override
  State<PublicCheckoutPanel> createState() => _PublicCheckoutPanelState();
}

class _PublicCheckoutPanelState extends State<PublicCheckoutPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _postcodeController = TextEditingController();
  final _cityController = TextEditingController(text: 'Salzburg');
  final _noteController = TextEditingController();
  final _orderService = PublicWebOrderService();

  String? _fulfillment;
  bool _isSubmitting = false;
  WebOrderResult? _success;

  DeliveryZone? get _zone =>
      deliveryZoneForPostcode(_postcodeController.text);

  @override
  void initState() {
    super.initState();
    _postcodeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _streetController.dispose();
    _postcodeController.dispose();
    _cityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon != null ? Icon(icon, size: 22) : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: widget.brand.primaryColor, width: 2),
      ),
    );
  }

  Future<void> _submit(CartProvider cart) async {
    if (cart.items.isEmpty) return;
    if (_fulfillment == null) {
      _showMsg('Bitte wähle Abholung oder Lieferung.');
      return;
    }

    if (_fulfillment == 'delivery') {
      if (!_formKey.currentState!.validate()) return;
      final zone = _zone;
      if (zone == null) {
        _showMsg(
          'Diese PLZ liegt außerhalb unseres Liefergebiets. Siehe Liste unten.',
        );
        return;
      }
      if (!meetsMinimumOrder(cart.totalPrice, zone)) {
        _showMsg(
          'Mindestbestellwert: ${formatEuro(zone.minimumOrder)}. '
          'Noch ${formatEuro(remainingForMinimum(cart.totalPrice, zone))} fehlen.',
        );
        return;
      }
    }

    setState(() => _isSubmitting = true);
    try {
      double? lat;
      double? lng;
      if (_fulfillment == 'delivery') {
        try {
          final geo = await Supabase.instance.client.functions.invoke(
            'geocode-address',
            body: {
              'street': _streetController.text.trim(),
              'city': _cityController.text.trim(),
              'postcode': normalizePostcode(_postcodeController.text),
              'country': 'AT',
            },
          );
          if (geo.data != null && geo.data['error'] == null) {
            lat = (geo.data['latitude'] as num?)?.toDouble();
            lng = (geo.data['longitude'] as num?)?.toDouble();
          }
        } catch (_) {}
      }

      final result = await _orderService.placeOrder(
        brand: widget.brand,
        cartItems: cart.items.values.toList(),
        fulfillmentType: _fulfillment!,
        customerName: _nameController.text.trim().isEmpty
            ? null
            : _nameController.text.trim(),
        customerStreet: _streetController.text.trim().isEmpty
            ? null
            : _streetController.text.trim(),
        customerPostcode: normalizePostcode(_postcodeController.text).isEmpty
            ? null
            : normalizePostcode(_postcodeController.text),
        customerCity: _cityController.text.trim().isEmpty
            ? null
            : _cityController.text.trim(),
        customerPhone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        deliveryLatitude: lat,
        deliveryLongitude: lng,
      );

      cart.clearCart();
      if (mounted) {
        setState(() {
          _success = result;
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showMsg(e.toString().replaceFirst('Exception: ', ''), isError: true);
      }
    }
  }

  void _showMsg(String text, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text),
        backgroundColor: isError ? Colors.red.shade700 : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_success != null) return _buildSuccess(_success!);

    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final isDelivery = _fulfillment == 'delivery';
        final zone = isDelivery ? _zone : null;
        final subtotal = cart.totalPrice;
        final grandTotal = orderGrandTotal(
          subtotal: subtotal,
          isDelivery: isDelivery,
          zone: zone,
        );
        final canSubmitDelivery = zone != null && meetsMinimumOrder(subtotal, zone);
        final canSubmit = cart.items.isNotEmpty &&
            _fulfillment != null &&
            (!isDelivery || canSubmitDelivery);

        return Container(
          color: Colors.grey.shade100,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _sectionTitle(Icons.shopping_bag_outlined, 'Deine Bestellung'),
                  const SizedBox(height: 8),
                  if (cart.items.isEmpty)
                    _emptyCartHint()
                  else ...[
                    ...cart.items.values.map((i) => _cartLine(context, cart, i)),
                    const SizedBox(height: 12),
                    _orderSummary(subtotal, zone, isDelivery, grandTotal),
                  ],
                  if (cart.items.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle(Icons.place_outlined, 'Wie möchtest du bestellen?'),
                    const SizedBox(height: 10),
                    _fulfillmentPicker(),
                    if (_fulfillment == 'pickup') ...[
                      const SizedBox(height: 12),
                      _pickupInfoCard(),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: _fieldDecoration('Name', icon: Icons.person_outline),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _fieldDecoration(
                          'Telefon',
                          hint: 'Für Rückfragen',
                          icon: Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                    if (_fulfillment == 'delivery') ...[
                      const SizedBox(height: 12),
                      DeliveryZonesCard(
                        accentColor: widget.brand.primaryColor,
                        selectedZone: zone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameController,
                        decoration: _fieldDecoration('Name *', icon: Icons.person_outline),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Bitte Name eingeben' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _phoneController,
                        decoration: _fieldDecoration(
                          'Telefon *',
                          icon: Icons.phone_outlined,
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Bitte Telefon angeben' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _streetController,
                        decoration: _fieldDecoration(
                          'Straße & Hausnummer *',
                          icon: Icons.home_outlined,
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _postcodeController,
                              decoration: _fieldDecoration('PLZ *'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(4),
                              ],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'PLZ eingeben';
                                }
                                if (deliveryZoneForPostcode(v) == null) {
                                  return 'PLZ nicht im Liefergebiet';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _cityController,
                              decoration: _fieldDecoration('Stadt *'),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty ? 'Pflichtfeld' : null,
                            ),
                          ),
                        ],
                      ),
                      if (zone != null && !meetsMinimumOrder(subtotal, zone)) ...[
                        const SizedBox(height: 10),
                        _warningBanner(
                          'Noch ${formatEuro(remainingForMinimum(subtotal, zone))} '
                          'bis Mindestbestellwert (${formatEuro(zone.minimumOrder)})',
                        ),
                      ],
                      if (_postcodeController.text.length == 4 && zone == null) ...[
                        const SizedBox(height: 10),
                        _warningBanner(
                          'Lieferung in PLZ ${_postcodeController.text} leider nicht möglich.',
                        ),
                      ],
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteController,
                      decoration: _fieldDecoration(
                        'Anmerkung',
                        hint: 'z.B. Klingel, Etage…',
                        icon: Icons.edit_note,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Zahlung bei Abholung / Lieferung: Bar',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: (!_isSubmitting && canSubmit)
                          ? () => _submit(cart)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.brand.primaryColor,
                        disabledBackgroundColor: Colors.grey.shade400,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              cart.items.isEmpty
                                  ? 'Warenkorb ist leer'
                                  : 'Jetzt bestellen · ${formatEuro(grandTotal)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 22, color: widget.brand.primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _emptyCartHint() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.restaurant_menu, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Wähle Gerichte aus der Speisekarte',
              style: TextStyle(color: Colors.grey[700], fontSize: 15),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _pickupInfoCard() {
    return Card(
      elevation: 0,
      color: Colors.green.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.green.shade200),
      ),
      child: const ListTile(
        leading: Icon(Icons.store, color: Colors.green),
        title: Text('Abholung bei uns', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(kKitchenAddress),
      ),
    );
  }

  Widget _fulfillmentPicker() {
    return Row(
      children: [
        Expanded(
          child: _fulfillmentTile(
            value: 'pickup',
            icon: Icons.storefront,
            label: 'Abholung',
            subtitle: 'Kostenlos',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _fulfillmentTile(
            value: 'delivery',
            icon: Icons.delivery_dining,
            label: 'Lieferung',
            subtitle: 'Salzburg & Umgebung',
          ),
        ),
      ],
    );
  }

  Widget _fulfillmentTile({
    required String value,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    final selected = _fulfillment == value;
    return Material(
      color: selected
          ? widget.brand.primaryColor.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => setState(() => _fulfillment = value),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? widget.brand.primaryColor : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 32,
                color: selected ? widget.brand.primaryColor : Colors.grey[600],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: selected ? widget.brand.primaryColor : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _orderSummary(
    double subtotal,
    DeliveryZone? zone,
    bool isDelivery,
    double grandTotal,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _summaryRow('Zwischensumme', formatEuro(subtotal)),
            if (isDelivery && zone != null) ...[
              const SizedBox(height: 6),
              _summaryRow('Liefergebühr (PLZ ${zone.plz})', formatEuro(zone.deliveryFee)),
              if (!meetsMinimumOrder(subtotal, zone))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Mindestbestellwert: ${formatEuro(zone.minimumOrder)}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800),
                  ),
                ),
            ],
            const Divider(height: 20),
            _summaryRow(
              'Gesamt',
              formatEuro(grandTotal),
              bold: true,
              valueColor: widget.brand.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool bold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 16 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 18 : 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _warningBanner(String text) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.orange.shade900, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _cartLine(BuildContext context, CartProvider cart, CartItem item) {
    final menuItem = item.menuItemWithRecipe.menuItem;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    menuItem.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    formatEuro(menuItem.price),
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (item.quantity > 1) {
                      cart.updateItemQuantity(menuItem.id, item.quantity - 1);
                    } else {
                      cart.removeFromCart(menuItem.id);
                    }
                  },
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () =>
                      cart.updateItemQuantity(menuItem.id, item.quantity + 1),
                  icon: Icon(Icons.add_circle, color: widget.brand.primaryColor),
                ),
              ],
            ),
            SizedBox(
              width: 56,
              child: Text(
                formatEuro(item.subtotal),
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(WebOrderResult result) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.brand.primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: widget.brand.primaryColor,
                size: 72,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Danke für deine Bestellung!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Bestellnummer',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      result.orderNumber,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: widget.brand.primaryColor,
                        letterSpacing: 1,
                      ),
                    ),
                    if (result.deliveryFee != null && result.deliveryFee! > 0) ...[
                      const SizedBox(height: 8),
                      _summaryRow(
                        'Liefergebühr',
                        formatEuro(result.deliveryFee!),
                      ),
                    ],
                    const Divider(height: 28),
                    _summaryRow('Gesamt', formatEuro(result.totalPrice), bold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _fulfillment == 'pickup'
                  ? 'Wir bereiten deine Bestellung vor. Abholung: $kKitchenAddress'
                  : 'Wir bereiten deine Bestellung vor und liefern sie bald zu dir.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
