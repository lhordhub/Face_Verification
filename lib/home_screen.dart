// home_screen.dart

import 'package:flutter/material.dart';

import 'api_service.dart';
import 'live_verify_screen.dart';
import 'reference_store.dart';
import 'register_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _serverChecking = true;
  bool _serverOk = false;
  Map<String, dynamic>? _reference;

  @override
  void initState() {
    super.initState();
    _loadReference();
    _wakeServer();
  }

  Future<void> _loadReference() async {
    final reference = await ReferenceStore.load();
    if (!mounted) return;
    setState(() => _reference = reference);
  }

  Future<void> _wakeServer() async {
    setState(() => _serverChecking = true);
    final ok = await ApiService.wakeServer();
    if (!mounted) return;
    setState(() {
      _serverChecking = false;
      _serverOk = ok;
    });
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    await _loadReference();
  }

  Future<void> _openLive() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LiveVerifyScreen()),
    );
  }

  Future<void> _deleteReference() async {
    await ReferenceStore.clear();
    await _loadReference();
  }

  @override
  Widget build(BuildContext context) {
    final hasReference = _reference != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Face Verification')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: _serverChecking
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        _serverOk ? Icons.check_circle : Icons.error,
                        color: _serverOk ? Colors.green : Colors.red,
                      ),
                title: Text(
                  _serverChecking
                      ? 'Connecting to server...'
                      : _serverOk
                          ? 'Server ready'
                          : 'Server not reachable',
                ),
                subtitle: _serverChecking
                    ? const Text('A sleeping free server can take up to a minute.')
                    : null,
                trailing: (!_serverChecking && !_serverOk)
                    ? TextButton(
                        onPressed: _wakeServer,
                        child: const Text('Retry'),
                      )
                    : null,
              ),
            ),
            Card(
              child: ListTile(
                leading: Icon(
                  hasReference ? Icons.face : Icons.face_retouching_off,
                  color: hasReference ? Colors.green : Colors.orange,
                ),
                title: Text(
                  hasReference ? 'Reference saved' : 'No reference yet',
                ),
                subtitle: Text(
                  hasReference
                      ? 'Built from ${_reference!['num_samples']} photos.'
                      : 'Step 1: capture your reference photos.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openRegister,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                hasReference ? 'Redo reference' : '1. Set up my reference',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: hasReference ? _openLive : null,
              icon: const Icon(Icons.videocam),
              label: const Text('2. Live verify'),
            ),
            if (hasReference) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _deleteReference,
                child: const Text('Delete saved reference'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
