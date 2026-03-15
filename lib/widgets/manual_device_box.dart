import 'package:flutter/material.dart';

class ManualDeviceBox extends StatefulWidget {
  final void Function(String name, String ip, int textPort, int filePort)
  onAddDevice;

  const ManualDeviceBox({super.key, required this.onAddDevice});

  @override
  State<ManualDeviceBox> createState() => _ManualDeviceBoxState();
}

class _ManualDeviceBoxState extends State<ManualDeviceBox> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _textPortController = TextEditingController(
    text: '40402',
  );
  final TextEditingController _filePortController = TextEditingController(
    text: '40403',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _textPortController.dispose();
    _filePortController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final ip = _ipController.text.trim();
    final textPortText = _textPortController.text.trim();
    final filePortText = _filePortController.text.trim();

    if (name.isEmpty ||
        ip.isEmpty ||
        textPortText.isEmpty ||
        filePortText.isEmpty) {
      return;
    }

    final textPort = int.tryParse(textPortText);
    final filePort = int.tryParse(filePortText);

    if (textPort == null || filePort == null) {
      return;
    }

    widget.onAddDevice(name, ip, textPort, filePort);

    _nameController.clear();
    _ipController.clear();
    _textPortController.text = '40402';
    _filePortController.text = '40403';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Add Device Manually',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Device Name',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ipController,
          decoration: const InputDecoration(
            labelText: 'IP Address',
            hintText: '192.168.1.100',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            SizedBox(
              width: 180,
              child: TextField(
                controller: _textPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Text Port',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            SizedBox(
              width: 180,
              child: TextField(
                controller: _filePortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'File Port',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.add),
            label: const Text('Add Device'),
          ),
        ),
      ],
    );
  }
}
