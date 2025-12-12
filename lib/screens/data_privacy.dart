import 'package:flutter/material.dart';

Future<bool> showDataPrivacyDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // Icon Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.privacy_tip_outlined,
                  size: 40,
                  color: Colors.blue,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              const Text(
                'Data Privacy Notice',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: const [
                      Text(
                        'Your privacy is important to us. By proceeding, you agree to the collection and processing of your responses for the purpose of this survey.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Your answers will be treated with confidentiality and will be used for analytical and research purposes only. Your personal identity will not be disclosed in any reports generated from this survey.',
                        textAlign: TextAlign.justify,
                        style: TextStyle(fontSize: 15, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Button Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Agree & Proceed',
                      style: TextStyle(fontSize: 16),
                    ),
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}
