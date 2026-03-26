import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Placeholder for Create Football Field Screen
/// TODO: Copy full implementation from admin app and migrate to Supabase
class CreateFootballFieldScreen extends StatelessWidget {
  const CreateFootballFieldScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.sports_soccer,
                size: 80,
                color: Colors.green.shade300,
              ),
              const SizedBox(height: 24),
              Text(
                'Create Football Field',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This feature will be available soon.\nYou can create football fields from the admin web portal.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Coming Soon',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Full field management including:\n• Field details & photos\n• Pricing & time slots\n• Amenities configuration\n• Location mapping',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

