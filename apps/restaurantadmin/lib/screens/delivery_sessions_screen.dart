import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:restaurantadmin/services/lieferando_service.dart';

class DeliverySessionsScreen extends StatefulWidget {
  const DeliverySessionsScreen({super.key});

  @override
  State<DeliverySessionsScreen> createState() => _DeliverySessionsScreenState();
}

class _DeliverySessionsScreenState extends State<DeliverySessionsScreen>
    with WidgetsBindingObserver {
  final LieferandoService _service = LieferandoService();

  List<LieferandoSession> _sessions = [];
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;
  final TextEditingController _urlController = TextEditingController();

  // track which accounts are mid-relogin
  final Set<String> _reconnecting = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _urlController.text = _service.monitorBaseUrl.value;
    _service.monitorBaseUrl.addListener(_onUrlChanged);

    _loadSessions();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _urlController.dispose();
    _service.monitorBaseUrl.removeListener(_onUrlChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSessions();
  }

  void _onUrlChanged() {
    _loadSessions();
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _service.isConfigured) _loadSessions(silent: true);
    });
  }

  Future<void> _loadSessions({bool silent = false}) async {
    if (!_service.isConfigured) {
      if (mounted) setState(() { _isLoading = false; _sessions = []; _error = null; });
      return;
    }
    if (!silent && mounted) setState(() { _isLoading = true; _error = null; });
    try {
      final sessions = await _service.fetchSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  // ── Reconnect flow ─────────────────────────────────────────────────────────
  Future<void> _startReconnect(LieferandoSession session) async {
    setState(() => _reconnecting.add(session.accountId));

    try {
      final result = await _service.triggerRelogin(session.accountId);
      if (!mounted) return;

      await _showReconnectDialog(session, result);
    } catch (e) {
      if (mounted) {
        _showErrorSnack('Could not open login window: $e');
      }
    } finally {
      if (mounted) setState(() => _reconnecting.remove(session.accountId));
    }
  }

  Future<void> _showReconnectDialog(LieferandoSession session, ReloginResult result) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ReconnectSheet(
        session: session,
        result: result,
        onDone: () async {
          Navigator.of(ctx).pop();
          await _confirmReloginComplete(session.accountId);
        },
      ),
    );
  }

  Future<void> _confirmReloginComplete(String accountId) async {
    try {
      final status = await _service.confirmReloginComplete(accountId);
      if (!mounted) return;
      final msg = status == SessionStatus.active
          ? '✅ Login confirmed — session is now active!'
          : '⚠️ Session still appears expired. Try again.';
      _showInfoSnack(msg);
      _loadSessions(silent: true);
    } catch (e) {
      if (mounted) _showErrorSnack('Could not verify login: $e');
    }
  }

  // ── Settings dialog ────────────────────────────────────────────────────────
  Future<void> _showSettingsDialog() async {
    _urlController.text = _service.monitorBaseUrl.value;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2433),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.settings_ethernet, color: Color(0xFF3B82F6), size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Monitor URL', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the base URL of your lieferando-monitor server.\nExample: http://192.168.1.100:3001',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'http://your-vps-ip:3001',
                hintStyle: const TextStyle(color: Color(0xFF475569)),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                ),
                prefixIcon: const Icon(Icons.link, color: Color(0xFF3B82F6), size: 18),
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _saveUrl(ctx),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          FilledButton(
            onPressed: () => _saveUrl(ctx),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _saveUrl(BuildContext ctx) {
    final url = _urlController.text.trim();
    _service.monitorBaseUrl.value = url;
    Navigator.of(ctx).pop();
  }

  void _showErrorSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFFEF4444),
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _showInfoSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: const Color(0xFF10B981),
      behavior: SnackBarBehavior.floating,
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E2433),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B35), Color(0xFFFF9F1C)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.cloud_sync_outlined, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery Platforms',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                ),
                Text(
                  'Lieferando Session Manager',
                  style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _loadSessions(),
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8)),
            tooltip: 'Refresh',
          ),
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8)),
            tooltip: 'Configure monitor URL',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadSessions(),
        color: const Color(0xFF3B82F6),
        backgroundColor: const Color(0xFF1E2433),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    // Not configured
    if (!_service.isConfigured) {
      return _buildNotConfigured();
    }

    // Loading
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF3B82F6)),
            SizedBox(height: 16),
            Text('Connecting to monitor...', style: TextStyle(color: Color(0xFF94A3B8))),
          ],
        ),
      );
    }

    // Error
    if (_error != null) {
      return _buildError();
    }

    // Empty
    if (_sessions.isEmpty) {
      return _buildEmpty();
    }

    // Session list
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildStatusSummary(),
        const SizedBox(height: 16),
        ..._sessions.map((s) => _SessionCard(
          session: s,
          isReconnecting: _reconnecting.contains(s.accountId),
          onReconnect: () => _startReconnect(s),
        )),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatusSummary() {
    final active = _sessions.where((s) => s.status == SessionStatus.active).length;
    final expired = _sessions.where((s) => s.status == SessionStatus.expired).length;
    final total = _sessions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: expired > 0
              ? [const Color(0xFF7F1D1D), const Color(0xFF991B1B)]
              : [const Color(0xFF064E3B), const Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: expired > 0
              ? const Color(0xFFEF4444).withValues(alpha: 0.3)
              : const Color(0xFF10B981).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            expired > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: expired > 0 ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
            size: 36,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired > 0
                      ? '$expired account${expired > 1 ? 's' : ''} need${expired == 1 ? 's' : ''} re-login'
                      : 'All accounts are active',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
                Text(
                  '$active/$total sessions active',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotConfigured() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2433),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Icon(Icons.cloud_off_outlined, color: Color(0xFF475569), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Monitor Not Configured',
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            const Text(
              'Set your lieferando-monitor server URL to start tracking session health.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _showSettingsDialog,
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Configure Monitor URL'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2433),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: Color(0xFF3B82F6), size: 16),
                      SizedBox(width: 8),
                      Text('Setup hint', style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Run the lieferando-monitor on your VPS and enter its address.\nExample: http://123.45.67.89:3001',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF7F1D1D).withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: Color(0xFFFCA5A5), size: 48),
            ),
            const SizedBox(height: 24),
            const Text(
              'Cannot Reach Monitor',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 13, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _showSettingsDialog,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit URL'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF334155)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _loadSessions,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, color: Color(0xFF475569), size: 64),
          const SizedBox(height: 16),
          const Text('No sessions found', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16)),
          const SizedBox(height: 8),
          const Text(
            'The monitor returned an empty list.\nMake sure accounts are configured.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF475569), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _loadSessions,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Refresh'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF3B82F6)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Session Card
// ─────────────────────────────────────────────────────────────────────────────

class _SessionCard extends StatelessWidget {
  final LieferandoSession session;
  final bool isReconnecting;
  final VoidCallback onReconnect;

  const _SessionCard({
    required this.session,
    required this.isReconnecting,
    required this.onReconnect,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = session.status == SessionStatus.active;
    final isExpired = session.status == SessionStatus.expired;

    final statusColor = isActive
        ? const Color(0xFF10B981)
        : isExpired
            ? const Color(0xFFEF4444)
            : const Color(0xFF94A3B8);

    final statusLabel = isActive ? 'Active' : isExpired ? 'Expired' : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpired
              ? const Color(0xFFEF4444).withValues(alpha: 0.4)
              : const Color(0xFF334155),
          width: isExpired ? 1.5 : 1,
        ),
        boxShadow: isExpired
            ? [BoxShadow(color: const Color(0xFFEF4444).withValues(alpha: 0.08), blurRadius: 12)]
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status dot
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [BoxShadow(color: statusColor.withValues(alpha: 0.5), blurRadius: 6)],
                  ),
                ),
                const SizedBox(width: 12),
                // Account label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'ID: ${session.accountId}',
                        style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),

            // Metadata row
            const SizedBox(height: 12),
            Row(
              children: [
                _MetaChip(
                  icon: Icons.schedule_outlined,
                  label: session.lastCheckedAt != null
                      ? _timeAgo(session.lastCheckedAt!)
                      : 'Never checked',
                  tooltip: 'Last checked',
                ),
                const SizedBox(width: 8),
                _MetaChip(
                  icon: Icons.receipt_long_outlined,
                  label: session.lastOrderSeenAt != null
                      ? 'Order ${_timeAgo(session.lastOrderSeenAt!)}'
                      : 'No orders yet',
                  tooltip: 'Last order seen',
                ),
              ],
            ),

            // Reconnect / Re-login button (always accessible for all accounts)
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isReconnecting ? null : onReconnect,
                icon: isReconnecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.login_rounded, size: 18),
                label: Text(
                  isReconnecting
                      ? 'Opening login window on VPS...'
                      : isExpired
                          ? 'Reconnect Account'
                          : 'Re-login / Refresh Session',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isExpired
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF334155),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String tooltip;

  const _MetaChip({required this.icon, required this.label, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF1E293B)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF64748B), size: 13),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reconnect bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _ReconnectSheet extends StatelessWidget {
  final LieferandoSession session;
  final ReloginResult result;
  final VoidCallback onDone;

  const _ReconnectSheet({
    required this.session,
    required this.result,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final hasVnc = result.vncHost != null && result.vncPort != null;
    final vncAddress = hasVnc ? '${result.vncHost}:${result.vncPort}' : null;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E2433),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF334155),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.key_outlined, color: Color(0xFFF59E0B), size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Window Opened',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      session.label,
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasVnc) ...[
                  _Step(
                    number: 1,
                    text: 'Connect your VNC client to:',
                    highlight: vncAddress!,
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: vncAddress));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('VNC address copied!'), behavior: SnackBarBehavior.floating),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const _Step(number: 2, text: 'You will see the Chromium browser with the Lieferando login page.'),
                  const SizedBox(height: 12),
                  const _Step(number: 3, text: 'Type your credentials and complete any CAPTCHA / 2FA.'),
                  const SizedBox(height: 12),
                  const _Step(number: 4, text: 'Once logged in, tap "Done" below.'),
                ] else ...[
                  const _Step(number: 1, text: 'A Chromium browser window has opened on the server.'),
                  const SizedBox(height: 12),
                  const _Step(number: 2, text: 'Complete the Lieferando login (credentials + any CAPTCHA).'),
                  const SizedBox(height: 12),
                  const _Step(number: 3, text: 'When finished, tap "Done" below.'),
                ],
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Done button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onDone,
              icon: const Icon(Icons.check_circle_outline, size: 20),
              label: const Text('I\'ve Completed the Login', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
            child: const Center(child: Text('Cancel — I\'ll do it later')),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  final String? highlight;
  final VoidCallback? onCopy;

  const _Step({required this.number, required this.text, this.highlight, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22, height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$number',
            style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.4)),
              if (highlight != null) ...[
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: onCopy,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            highlight!,
                            style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 13, fontFamily: 'monospace', fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Icon(Icons.copy_outlined, color: Color(0xFF3B82F6), size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
