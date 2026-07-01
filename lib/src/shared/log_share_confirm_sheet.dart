import 'package:flutter/material.dart';
import 'custom_text.dart';
import 'custom_button.dart';

class LogShareConfirmSheet extends StatelessWidget {
  const LogShareConfirmSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.delete_sweep_outlined,
              color: Colors.orangeAccent, size: 36),
          const SizedBox(height: 16),
          const CustomText(
            'Share & Clear Logs',
            style: TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          const CustomText(
            'The log file will be shared, then permanently '
            'deleted from this device. Use export if you want to keep it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: CustomButton(
                  onPressed: () => Navigator.pop(context, false),
                  label: 'Cancel',
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white12),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CustomButton(
                  onPressed: () => Navigator.pop(context, true),
                  label: 'Share & Clear',
                  isElevated: true,
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
