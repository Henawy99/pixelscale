import 'package:flutter/material.dart';
import 'package:playmakerappstart/custom_tile_container.dart';

class MobileWalletSelectionSheet extends StatefulWidget {
  final String? selectedMobileWallet;
  final Function(String) onWalletSelected;

  const MobileWalletSelectionSheet({
    Key? key,
    this.selectedMobileWallet,
    required this.onWalletSelected,
  }) : super(key: key);

  @override
  _MobileWalletSelectionSheetState createState() => _MobileWalletSelectionSheetState();
}

class _MobileWalletSelectionSheetState extends State<MobileWalletSelectionSheet> {
  String? _selectedMobileWallet;

  @override
  void initState() {
    super.initState();
    _selectedMobileWallet = widget.selectedMobileWallet;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Choose your preferred mobile wallet',
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold, color: Colors.green),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedMobileWallet = 'Etisalat Cash';
              });
              widget.onWalletSelected(_selectedMobileWallet!);
            },
            child: CustomTileContainer(
              isSelected: _selectedMobileWallet == 'Etisalat Cash',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/mobile-wallet-logos/etisalat-cash.png',
                        width: 40,
                        height: 40,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Etisalat Cash',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedMobileWallet == 'Etisalat Cash' ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMobileWallet == 'Etisalat Cash') const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedMobileWallet = 'Vodafone Cash';
              });
              widget.onWalletSelected(_selectedMobileWallet!);
            },
            child: CustomTileContainer(
              isSelected: _selectedMobileWallet == 'Vodafone Cash',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/mobile-wallet-logos/vodafone-cash.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Vodafone Cash',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedMobileWallet == 'Vodafone Cash' ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMobileWallet == 'Vodafone Cash') const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedMobileWallet = 'Orange Cash';
              });
              widget.onWalletSelected(_selectedMobileWallet!);
            },
            child: CustomTileContainer(
              isSelected: _selectedMobileWallet == 'Orange Cash',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/mobile-wallet-logos/orange-cash.png',
                        width: 24,
                        height: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Orange Cash',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedMobileWallet == 'Orange Cash' ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMobileWallet == 'Orange Cash') const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedMobileWallet = 'Other Wallets';
              });
              widget.onWalletSelected(_selectedMobileWallet!);
            },
            child: CustomTileContainer(
              isSelected: _selectedMobileWallet == 'Other Wallets',
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_wallet,
                          color: _selectedMobileWallet == 'Other Wallets' ? Colors.green : Colors.black),
                      const SizedBox(width: 10),
                      Text(
                        'Other Wallets',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _selectedMobileWallet == 'Other Wallets' ? Colors.green : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  if (_selectedMobileWallet == 'Other Wallets') const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _selectedMobileWallet != null ? () => Navigator.pop(context) : null,
            child: const Text(
              'Confirm',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), // Make the button full width
              backgroundColor:
                  _selectedMobileWallet != null ? Colors.green : Colors.grey, // Update color based on selection
            ),
          ),
        ],
      ),
    );
  }
}
