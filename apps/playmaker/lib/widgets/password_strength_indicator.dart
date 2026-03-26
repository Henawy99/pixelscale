import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:playmakerappstart/utils/validators.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();

    final strength = Validators.getPasswordStrength(password);
    final label = Validators.getPasswordStrengthLabel(strength);
    final color = Validators.getPasswordStrengthColor(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                      decoration: BoxDecoration(
                        color: index < strength 
                            ? color 
                            : Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.inter(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Password must be at least 6 characters',
          style: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

