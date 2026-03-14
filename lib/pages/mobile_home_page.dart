import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/device.dart';
import '../services/connectivity_test_service.dart';
import '../services/discovery_service.dart';
import '../services/file_transfer_service.dart';
import '../services/log_service.dart';
import '../services/message_service.dart';
import '../services/save_location_service.dart';
import '../utils/network_utils.dart';
import '../widgets/connectivity_test_box.dart';

class MobileHomePage extends StatefulWidget {
  const MobileHomePage({super.key});

  @override
  State<MobileHomePage> createState() => _MobileHomePageState();
}

class _MobileHomePageState extends State<MobileHomePage> {
  late final DiscoveryService _discoveryService;
  late final MessageService _messageService;
  late final FileTransferService _fileTransferService;

  StreamSubscription<List<Device>>? _deviceSub;
  StreamSubscription<ReceivedTextMessage>? _messageSub;
  StreamSubscription<ReceivedFileRecord>? _fileSub;
  StreamSubscription<ReceivedFolderRecord>? _folderSub;

  List<Device> _devices = [];
  List<ReceivedTextMessage> _messages = [];
  List<ReceivedFileRecord> _files = [];
  List<ReceivedFolderRecord> _folders = [];

  String _localIp = 'Loading...';

  @override
  void initState() {
    super.initState();
    _initServices();
  }

  Future<void> _initServices() async {
    await LogService.instance.init();

    final ip = await NetworkUtils.findLocalIpv4();
    if (mounted) {
      setState(() {
        _localIp = ip;
      });
    }

    _discoveryService = DiscoveryService(
      selfId: _buildSelfId(),
      selfName: _buildPhoneName(),
    );

    _messageService = MessageService(selfName: _buildPhoneName());

    _fileTransferService = FileTransferService(selfName: _buildPhoneName());

    _deviceSub = _discoveryService.devicesStream.listen((devices) {
      if (!mounted) return;
      setState(() {
        _devices = devices;
      });
    });

    _messageSub = _messageService.messageStream.listen((message) {
      if (!mounted) return;
      setState(() {
        _messages = [message, ..._messages];
      });
    });

    _fileSub = _fileTransferService.receivedFileStream.listen((file) {
      if (!mounted) return;
      setState(() {
        _files = [file, ..._files];
      });
    });

    _folderSub = _fileTransferService.receivedFolderStream.listen((folder) {
      if (!mounted) return;
      setState(() {
        _folders = [folder, ..._folders];
      });
    });

    await _messageService.start();
    await _fileTransferService.startReceiver();
    await _discoveryService.start();
  }

  String _buildSelfId() {
    return 'android-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _buildPhoneName() {
    return 'Android Device';
  }

  @override
  void dispose() {
    _deviceSub?.cancel();
    _messageSub?.cancel();
    _fileSub?.cancel();
    _folderSub?.cancel();
    _discoveryService.dispose();
    _messageService.dispose();
    _fileTransferService.dispose();
    super.dispose();
  }

  Future<void> _copyReceivedText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Text copied')));
  }

  Future<void> _saveReceivedText(ReceivedTextMessage msg) async {
    final dir = await SaveLocationService.instance
        .ensureSenderCategoryDirectory(
          senderName: msg.fromDeviceName,
          category: 'Text',
        );

    final fileName =
        'text_${msg.time.year.toString().padLeft(4, '0')}-'
        '${msg.time.month.toString().padLeft(2, '0')}-'
        '${msg.time.day.toString().padLeft(2, '0')}_'
        '${msg.time.hour.toString().padLeft(2, '0')}-'
        '${msg.time.minute.toString().padLeft(2, '0')}-'
        '${msg.time.second.toString().padLeft(2, '0')}.txt';

    final file = File('${dir.path}${Platform.pathSeparator}$fileName');
    await file.writeAsString(msg.text, flush: true);

    await LogService.instance.info('Received text saved to ${file.path}');

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Text saved: ${file.path}')));
  }

  Future<void> _editReceivedText(ReceivedTextMessage msg) async {
    final controller = TextEditingController(text: msg.text);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          child: Container(
            padding: const EdgeInsets.all(16),
            width: 800,
            height: 600,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit / Save Text',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: controller.text),
                        );
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Edited text copied')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final dir = await SaveLocationService.instance
                            .ensureSenderCategoryDirectory(
                              senderName: msg.fromDeviceName,
                              category: 'Text',
                            );

                        final now = DateTime.now();
                        final fileName =
                            'edited_text_'
                            '${now.year.toString().padLeft(4, '0')}-'
                            '${now.month.toString().padLeft(2, '0')}-'
                            '${now.day.toString().padLeft(2, '0')}_'
                            '${now.hour.toString().padLeft(2, '0')}-'
                            '${now.minute.toString().padLeft(2, '0')}-'
                            '${now.second.toString().padLeft(2, '0')}.txt';

                        final file = File(
                          '${dir.path}${Platform.pathSeparator}$fileName',
                        );

                        await file.writeAsString(controller.text, flush: true);

                        if (!mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Edited text saved: ${file.path}'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _testConnection(String host) async {
    final matched = _devices.where((e) => e.ip == host).toList();
    final textPort = matched.isNotEmpty ? matched.first.textPort : 40402;
    final filePort = matched.isNotEmpty ? matched.first.filePort : 40403;

    final textResult = await ConnectivityTestService.testPort(
      host: host,
      port: textPort,
    );

    final fileResult = await ConnectivityTestService.testPort(
      host: host,
      port: filePort,
    );

    if (!mounted) return;

    final msg =
        'Text ${textResult.success ? "OK" : "FAIL"} | '
        'File ${fileResult.success ? "OK" : "FAIL"}';

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget _buildMessageCard(ReceivedTextMessage msg) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              msg.fromDeviceName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${msg.fromIp} | ${msg.contentType}',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: SelectableText(
                    msg.text,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _copyReceivedText(msg.text),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editReceivedText(msg),
                  icon: const Icon(Icons.edit),
                  label: const Text('Edit'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _saveReceivedText(msg),
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageTab() {
    if (_files.isEmpty && _folders.isEmpty) {
      return const Center(child: Text('No file or folder received yet'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_folders.isNotEmpty) ...[
          const Text(
            'Folders',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._folders.map((folder) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.folder),
                title: Text(folder.folderName),
                subtitle: SelectableText(
                  'From: ${folder.fromDeviceName} (${folder.fromIp})\n'
                  'Zip size: ${folder.zipSize} bytes\n'
                  'Saved: ${folder.savedPath}',
                ),
                isThreeLine: true,
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        if (_files.isNotEmpty) ...[
          const Text(
            'Files',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ..._files.map((file) {
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(file.fileName),
                subtitle: SelectableText(
                  'From: ${file.fromDeviceName} (${file.fromIp})\n'
                  'Size: ${file.size} bytes\n'
                  'Saved: ${file.savedPath}',
                ),
                isThreeLine: true,
              ),
            );
          }),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultHost = _devices.isNotEmpty ? _devices.first.ip : '';

    return Scaffold(
      appBar: AppBar(title: const Text('Lan Share Receiver')),
      body: DefaultTabController(
        length: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _buildPhoneName(),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('IP: $_localIp'),
                  const SizedBox(height: 4),
                  Text('Text Port: 40402'),
                  const SizedBox(height: 4),
                  Text('File Port: 40403'),
                  const SizedBox(height: 4),
                  Text('Online device count: ${_devices.length}'),
                  const SizedBox(height: 12),
                  ConnectivityTestBox(
                    defaultHost: defaultHost,
                    onTest: _testConnection,
                  ),
                ],
              ),
            ),
            const TabBar(
              tabs: [
                Tab(text: 'Text'),
                Tab(text: 'Storage'),
                Tab(text: 'Devices'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _messages.isEmpty
                        ? const Center(child: Text('No text received yet'))
                        : ListView.builder(
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              return _buildMessageCard(_messages[index]);
                            },
                          ),
                  ),
                  _buildStorageTab(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _devices.isEmpty
                        ? const Center(child: Text('No device found yet'))
                        : ListView.separated(
                            itemCount: _devices.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final d = _devices[index];
                              return ListTile(
                                leading: const Icon(Icons.devices),
                                title: Text(d.name),
                                subtitle: Text(
                                  '${d.ip}\ntext: ${d.textPort}   file: ${d.filePort}',
                                ),
                                isThreeLine: true,
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
