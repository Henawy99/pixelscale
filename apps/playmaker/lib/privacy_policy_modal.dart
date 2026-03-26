import 'package:flutter/material.dart';

class PrivacyPolicyModal extends StatelessWidget {
  const PrivacyPolicyModal({Key? key}) : super(key: key);

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (context, scrollController) => PrivacyPolicyModal(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar for draggable sheet
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            height: 4,
            width: 40,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Privacy Policy for Playmaker\nLast Updated: February 13, 2025',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    '1. Introduction',
                    'Welcome to Playmaker\'s Privacy Policy. This policy describes how we collect, use, process, and protect your personal information when you use our mobile application and services. We are committed to protecting your privacy and handling your data in an open and transparent manner.',
                  ),
                  _buildSection(
                    '2. Information We Collect',
                    '2.1 Information You Provide\n• Account information (name, email address, phone number, date of birth)\n• Profile information (profile picture, preferred playing position)\n• Payment information (credit card details, billing address)\n• Booking details (preferred playing times, booking history)\n• Communications with us (support queries, feedback)\n\n2.2 Information Automatically Collected\n• Device information (device type, operating system, unique device identifiers)\n• Usage data (app features used, booking patterns, access times)\n• Location data (with your permission, to show nearby football fields)\n• Log data (IP address, browser type, pages visited)\n• Cookies and similar technologies',
                  ),
                  _buildSection(
                    '3. How We Use Your Information',
                    '• Processing and managing your bookings\n• Facilitating payments between you and field providers\n• Providing customer support\n• Sending booking confirmations and reminders\n• Personalizing your app experience\n• Improving our services\n• Sending promotional offers (with your consent)\n• Preventing fraud and ensuring platform security\n• Complying with legal obligations',
                  ),
                  _buildSection(
                    '4. Information Sharing and Disclosure',
                    '4.1 We Share Information With:\n• Field providers (only necessary booking details)\n• Payment processors (for transaction processing)\n• Service providers (analytics, customer support, hosting)\n• Legal authorities (when required by law)\n\n4.2 We Do Not:\n• Sell your personal information to third parties\n• Share your information for marketing purposes without consent\n• Disclose more information than necessary for service provision',
                  ),
                  _buildSection(
                    '5. Data Security',
                    'We implement appropriate technical and organizational measures to protect your data, including:\n\n• Encryption of sensitive information\n• Regular security assessments\n• Access controls and authentication\n• Secure data storage\n• Regular security updates\n• Employee training on data protection',
                  ),
                  _buildSection(
                    '6. Your Privacy Rights',
                    'You have the right to:\n\n• Access your personal information\n• Correct inaccurate data\n• Request deletion of your data\n• Withdraw consent for data processing\n• Export your data\n• Object to certain data processing\n• Lodge complaints with supervisory authorities',
                  ),
                  _buildSection(
                    '7. Data Retention',
                    'We retain your information for as long as:\n\n• Your account is active\n• Needed to provide our services\n• Required by law\n• Necessary for fraud prevention\n• Essential for dispute resolution',
                  ),
                  _buildSection(
                    '8. International Data Transfers',
                    'If we transfer your data internationally, we ensure:\n\n• Adequate data protection measures\n• Compliance with applicable laws\n• Implementation of appropriate safeguards\n• Transparency about transfer mechanisms',
                  ),
                  _buildSection(
                    '9. Children\'s Privacy',
                    '• Our service is not intended for users under 18\n• We do not knowingly collect data from children\n• We will delete any information if we discover it was collected from a minor',
                  ),
                  _buildSection(
                    '10. Third-Party Links',
                    '• Our app may contain links to third-party services\n• We are not responsible for third-party privacy practices\n• Please review third-party privacy policies separately',
                  ),
                  _buildSection(
                    '11. Marketing Communications',
                    '• We send marketing communications only with consent\n• You can opt out at any time\n• Each marketing email includes an unsubscribe option\n• Preference settings are available in your account',
                  ),
                  _buildSection(
                    '12. Cookies and Tracking',
                    'We use cookies and similar technologies to:\n\n• Improve user experience\n• Remember preferences\n• Analyze usage patterns\n• Provide personalized content\n• Enhance security',
                  ),
                  _buildSection(
                    '13. Changes to This Policy',
                    '• We may update this policy periodically\n• Significant changes will be notified via app or email\n• Continued use after changes implies acceptance\n• Previous versions will be archived',
                  ),
                  _buildSection(
                    '14. Contact Us',
                    'For privacy-related questions or concerns:\n\n• Email: office@playmakerapp.info\n• Phone: +201151994181\n• Address: Banfseg 12 Villa 106',
                  ),
                  _buildSection(
                    '15. Supervisory Authority',
                    'You have the right to lodge a complaint with your local data protection authority if you have concerns about how we process your personal information.',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'By using Playmaker, you acknowledge that you have read and understood this Privacy Policy and agree to its terms.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Bottom action area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('I Understand'),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              fontSize: 14, 
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}