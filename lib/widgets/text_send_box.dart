import 'package:flutter/material.dart';

class TextSendBox extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const TextSendBox({
    super.key,
    required this.controller,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Text Message', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          'Text will be sent as raw UTF-8 content. Line breaks, spaces, and indentation will be kept.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          minLines: 6,
          maxLines: 14,
          decoration: InputDecoration(
            hintText: 'Paste text, code, JSON, or markdown here...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            alignLabelWithHint: true,
          ),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: onSend,
            icon: const Icon(Icons.send),
            label: const Text('Send Text'),
          ),
        ),
      ],
    );
  }
}
