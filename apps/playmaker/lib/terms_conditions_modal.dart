import 'package:flutter/material.dart';

class TermsAndConditionsModal extends StatelessWidget {
  const TermsAndConditionsModal({Key? key}) : super(key: key);

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
          builder: (context, scrollController) => TermsAndConditionsModal(),
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
                    'Terms and Conditions for Playmaker',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: 'Last Updated',
                    content: 'February 4, 2025',
                    isHeader: true,
                  ),
                  _buildSection(
                    title: '1. Introduction',
                    content: 'Welcome to Playmaker ("we," "our," or "us"). These Terms and Conditions ("Terms") govern your use of the Playmaker mobile application ("App") and all related services. By downloading, accessing, or using our App, you agree to be bound by these Terms.',
                  ),
                  _buildSection(
                    title: '2. Service Description',
                    content: 'Playmaker is a platform that facilitates the booking of football fields by connecting court owners ("Providers") with users seeking to book football fields ("Bookers"). We act as an intermediary platform and are not the owner or operator of any football fields listed on our App.',
                  ),
                            _buildSection(
                    title: '3. User Registration and Account',
                    content: '• You must register an account to use our services.\n'
                    '• You must provide accurate, current, and complete information during registration.\n'
                    '• You are responsible for maintaining the confidentiality of your account credentials.\n'
                    '• You must be at least 18 years old to create an account.',
                  ),
                  _buildSection(
                    title: '4. Booking and Payment',
                    content: '• All bookings are subject to availability and Provider approval.\n'
                    '• Prices are set by Providers and may vary.\n'
                    '• Payment must be made in full at the time of booking.\n'
                    '• We accept payment through our approved payment methods within the App.\n'
                    '• All applicable taxes and fees will be clearly displayed before payment.',
                  ),
                  _buildSection(
                    title: '5. Cancellation and Refund Policy',
                    content: 'No refunds will be provided except in cases where:\n'
                    '• The Provider denies access to the booked field without valid reason\n'
                    '• The field is unusable due to Provider\'s fault\n'
                    '• The Provider cancels the booking\n\n'
                    '• Refund requests must be submitted within 24 hours of the incident.\n'
                    '• Approved refunds will be processed within 5-7 business days.',
                  ),
                  _buildSection(
                    title: '6. Provider Responsibilities',
                    content: 'Providers must:\n'
                    '• Provide accurate information about their facilities\n'
                    '• Maintain their fields in safe, playable condition\n'
                    '• Honor all confirmed bookings\n'
                    '• Update availability calendar regularly\n'
                    '• Comply with local laws and regulations',
                  ),
                  _buildSection(
                    title: '7. Booker Responsibilities',
                    content: 'Bookers must:\n'
                    '• Arrive on time for their booking\n'
                    '• Use the facilities as intended\n'
                    '• Follow facility rules and regulations\n'
                    '• Report any issues promptly\n'
                    '• Pay for any damages caused during their booking',
                  ),
                  _buildSection(
                    title: '8. Platform Rules',
                    content: 'Users agree not to:\n'
                    '• Circumvent our platform to make direct bookings\n'
                    '• Share account credentials\n'
                    '• Provide false information\n'
                    '• Engage in any fraudulent activities\n'
                    '• Harass other users or staff',
                  ),
                  _buildSection(
                    title: '9. Liability and Disclaimers',
                    content: 'We are not liable for:\n'
                    '• Quality or condition of football fields\n'
                    '• Accidents or injuries during play\n'
                    '• Disputes between Providers and Bookers\n'
                    '• Loss of personal belongings\n'
                    '• Technical issues beyond our control\n\n'
                    'Users play at their own risk and should have appropriate insurance coverage.',
                  ),
                  _buildSection(
                    title: '10. Intellectual Property',
                    content: '• All App content, including logos, designs, and software, is our property.\n'
                    '• Users may not copy, modify, or distribute our intellectual property.',
                  ),
                  _buildSection(
                    title: '11. Privacy and Data Protection',
                    content: '• We collect and process personal data as described in our Privacy Policy.\n'
                    '• Users consent to our data collection and processing practices.',
                  ),
                  _buildSection(
                    title: '12. Modification of Service',
                    content: 'We reserve the right to:\n'
                    '• Modify or discontinue any aspect of the service\n'
                    '• Update these Terms at any time\n'
                    '• Change our fees and payment policies',
                  ),
                  _buildSection(
                    title: '13. Termination',
                    content: '• We may terminate or suspend accounts for violations of these Terms.\n'
                    '• Users may delete their accounts at any time.',
                  ),
                  _buildSection(
                    title: '14. Dispute Resolution',
                    content: 'All disputes will be resolved through:\n'
                    '• Initial friendly negotiation\n'
                    '• Mediation if necessary\n'
                    '• Binding arbitration as a last resort',
                  ),
                  _buildSection(
                    title: '15. Governing Law',
                    content: 'These Terms are governed by [Your Country\'s] law, without regard to conflict of law principles.',
                  ),
                  _buildSection(
                    title: '16. Contact Information',
                    content: 'For questions about these Terms, contact us at:\n[Your Contact Information]',
                  ),
                  _buildSection(
                    title: '17. Severability',
                    content: 'If any provision of these Terms is found to be unenforceable, the remaining provisions will remain in effect.',
                  ),
                  const SizedBox(height: 16),
                  _buildSection(
                    title: '',
                    content: 'By using Playmaker, you acknowledge that you have read, understood, and agree to these Terms and Conditions.',
                    isFooter: true,
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

  Widget _buildSection({
    required String title,
    required String content,
    bool isHeader = false,
    bool isFooter = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty && !isHeader && !isFooter)
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          if (title.isNotEmpty && !isHeader && !isFooter)
            const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: isHeader ? 16 : 14,
              color: isHeader ? Colors.black54 : Colors.black87,
              fontWeight: isFooter ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}