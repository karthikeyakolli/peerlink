import 'package:flutter/material.dart';
import '../../core/biometric_auth_service.dart';
import '../../core/received_files_service.dart';
import '../../core/safe_folder_service.dart';

/// Minimalist Light-Only Private Safe Folder Modal.
/// Lets users create a local PIN, unlock their encrypted Safe Folder, move sensitive
/// Vault files into local authenticated encryption, and restore or delete them.
class SafeFolderSheet extends StatefulWidget {
  final VoidCallback? onVaultChanged;

  const SafeFolderSheet({super.key, this.onVaultChanged});

  static Future<void> show(BuildContext context, {VoidCallback? onVaultChanged}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeFolderSheet(onVaultChanged: onVaultChanged),
    );
  }

  @override
  State<SafeFolderSheet> createState() => _SafeFolderSheetState();
}

class _SafeFolderSheetState extends State<SafeFolderSheet> {
  final SafeFolderService _safe = SafeFolderService.instance;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _confirmPinController = TextEditingController();

  String? _errorText;
  bool _busy = false;
  List<SafeFolderItem> _lockedItems = [];

  @override
  void initState() {
    super.initState();
    if (_safe.isUnlocked) {
      _lockedItems = _safe.listLockedFiles();
    }
    BiometricAuthService.instance.startInactivityMonitor(
      timeout: const Duration(minutes: 2),
      onAutoLock: () {
        if (mounted && _safe.isUnlocked) {
          _safe.lock();
          _refreshItems();
        }
      },
    );
  }

  @override
  void dispose() {
    BiometricAuthService.instance.stopInactivityMonitor();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  void _refreshItems() {
    setState(() {
      _lockedItems = _safe.isUnlocked ? _safe.listLockedFiles() : [];
    });
  }

  Future<void> _handleSetupPin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmPinController.text.trim();
    if (pin.length < 4) {
      setState(() => _errorText = 'Please enter a PIN with at least 4 digits/characters.');
      return;
    }
    if (pin != confirm) {
      setState(() => _errorText = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    await _safe.setupPin(pin);
    await _safe.enrollBiometric(pin);
    _pinController.clear();
    _confirmPinController.clear();
    if (mounted) {
      setState(() => _busy = false);
      _refreshItems();
    }
  }

  Future<void> _handleUnlock() async {
    final pin = _pinController.text.trim();
    if (pin.isEmpty) {
      setState(() => _errorText = 'Enter your Safe Folder PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final ok = await _safe.unlock(pin);
    if (ok) {
      await _safe.enrollBiometric(pin);
    }
    _pinController.clear();
    if (mounted) {
      setState(() {
        _busy = false;
        if (!ok) {
          _errorText = 'Incorrect PIN (attempt ${_safe.failedAttempts}). Try again.';
        }
      });
      if (ok) _refreshItems();
    }
  }

  Future<void> _handleBiometricUnlock() async {
    setState(() {
      _busy = true;
      _errorText = null;
    });
    final bioOk = await BiometricAuthService.instance.authenticate(reason: 'Unlock Safe Folder');
    if (!bioOk) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = 'Biometric authentication cancelled or not recognized.';
        });
      }
      return;
    }
    final unlocked = await _safe.unlockWithBiometric();
    if (!unlocked && !_safe.isUnlocked) {
      if (mounted) {
        setState(() {
          _busy = false;
          _errorText = 'Please enter PIN once to enable biometric unlock.';
        });
      }
      return;
    }
    if (mounted) {
      setState(() => _busy = false);
      _refreshItems();
    }
  }

  Future<void> _showAddFromVaultPicker() async {
    final files = await ReceivedFilesService.instance.getReceivedFiles(includeDirectories: false);
    if (!mounted) return;
    if (files.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No files available in PeerLink Vault to lock.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selected = await showDialog<ReceivedFileItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Move File to Safe Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 360,
          height: 280,
          child: ListView.separated(
            itemCount: files.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (_, idx) {
              final f = files[idx];
              return ListTile(
                dense: true,
                leading: const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF2563EB), size: 20),
                title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
                subtitle: Text(f.formattedSize, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                onTap: () => Navigator.pop(ctx, f),
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );

    if (selected != null && mounted) {
      setState(() => _busy = true);
      try {
        await _safe.lockFile(selected.path);
        widget.onVaultChanged?.call();
        if (mounted) {
          setState(() => _busy = false);
          _refreshItems();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Encrypted "${selected.name}" inside Safe Folder'),
              backgroundColor: const Color(0xFF15803D),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _busy = false;
            _errorText = 'Could not lock file: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Icon(
                      _safe.isUnlocked ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                      color: const Color(0xFF2563EB),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Safe Folder',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          _safe.isUnlocked
                              ? 'Unlocked • ${_lockedItems.length} encrypted ${_lockedItems.length == 1 ? "file" : "files"}'
                              : 'Local PIN-encrypted private vault (on-device only)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  if (_safe.isUnlocked)
                    TextButton.icon(
                      key: const Key('safe_folder_lock_button'),
                      onPressed: () {
                        _safe.lock();
                        _refreshItems();
                      },
                      icon: const Icon(Icons.lock_outline_rounded, size: 16),
                      label: const Text('Lock', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 22, color: Color(0xFFE5E7EB)),
              if (!_safe.isConfigured)
                _buildSetupPinView()
              else if (!_safe.isUnlocked)
                _buildUnlockPinView()
              else
                _buildUnlockedVaultView(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSetupPinView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: const Text(
            'Create a local PIN to protect sensitive files with authenticated on-device encryption (PBKDF2-HMAC-SHA256). Nothing leaves your device.',
            style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          key: const Key('safe_setup_pin_field'),
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'New PIN (4+ digits)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const Key('safe_confirm_pin_field'),
          controller: _confirmPinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Confirm PIN',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('safe_create_pin_button'),
          onPressed: _busy ? null : _handleSetupPin,
          icon: const Icon(Icons.shield_outlined, size: 18),
          label: Text(_busy ? 'Setting up...' : 'Create Safe Folder'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockPinView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('safe_unlock_pin_field'),
          controller: _pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          onSubmitted: (_) => _handleUnlock(),
          decoration: const InputDecoration(
            labelText: 'Enter Safe Folder PIN',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        if (_errorText != null) ...[
          const SizedBox(height: 8),
          Text(_errorText!, style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626))),
        ],
        const SizedBox(height: 14),
        FilledButton.icon(
          key: const Key('safe_unlock_button'),
          onPressed: _busy ? null : _handleUnlock,
          icon: const Icon(Icons.lock_open_rounded, size: 18),
          label: Text(_busy ? 'Verifying...' : 'Unlock Safe Folder'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('safe_biometric_unlock_button'),
          onPressed: _busy ? null : _handleBiometricUnlock,
          icon: const Icon(Icons.fingerprint_rounded, size: 18),
          label: const Text('Unlock with Biometrics / Windows Hello'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F172A),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildUnlockedVaultView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          key: const Key('safe_add_file_button'),
          onPressed: _busy ? null : _showAddFromVaultPicker,
          icon: const Icon(Icons.add_moderator_outlined, size: 18),
          label: const Text('Encrypt & Lock File from Vault'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 11),
          ),
        ),
        const SizedBox(height: 14),
        if (_lockedItems.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Text(
              'Safe Folder is empty.\nEncrypted files are hidden from normal browsing and protected by your PIN.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.5),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _lockedItems.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, idx) {
              final item = _lockedItems[idx];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user_outlined, color: Color(0xFF15803D), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.originalName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            '${item.formattedSize} • Encrypted',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      key: Key('safe_restore_button_$idx'),
                      onPressed: _busy
                          ? null
                          : () async {
                              setState(() => _busy = true);
                              await _safe.restoreFile(item.id);
                              widget.onVaultChanged?.call();
                              if (mounted) {
                                setState(() => _busy = false);
                                _refreshItems();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Restored "${item.originalName}" to Vault'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Restore', style: TextStyle(fontSize: 12)),
                    ),
                    IconButton(
                      tooltip: 'Delete Permanently',
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                      onPressed: _busy
                          ? null
                          : () async {
                              await _safe.deleteLockedFile(item.id);
                              _refreshItems();
                            },
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
