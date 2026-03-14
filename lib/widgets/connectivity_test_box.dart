import 'package:flutter/material.dart';

class ConnectivityTestBox extends StatefulWidget {
  final String defaultHost;
  final Future<void> Function(String host) onTest;
  final Future<void> Function()? onSelfTest;

  const ConnectivityTestBox({
    super.key,
    required this.defaultHost,
    required this.onTest,
    this.onSelfTest,
  });

  @override
  State<ConnectivityTestBox> createState() => _ConnectivityTestBoxState();
}

class _ConnectivityTestBoxState extends State<ConnectivityTestBox> {
  late final TextEditingController _hostController;

  @override
  void initState() {
    super.initState();
    _hostController = TextEditingController(text: widget.defaultHost);
  }

  @override
  void didUpdateWidget(covariant ConnectivityTestBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.defaultHost != oldWidget.defaultHost &&
        widget.defaultHost.isNotEmpty &&
        _hostController.text.trim().isEmpty) {
      _hostController.text = widget.defaultHost;
    }
  }

  @override
  void dispose() {
    _hostController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      return;
    }
    await widget.onTest(host);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connection Test', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _hostController,
          decoration: const InputDecoration(
            labelText: 'Target IP',
            hintText: '192.168.1.100',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.network_check),
            label: const Text('Test Connection'),
          ),
        ),
      ],
    );
  }
}
