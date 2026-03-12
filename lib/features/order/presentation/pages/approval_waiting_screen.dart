import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:urban_agent_app/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/model/order_details.dart';
import '../../../../core/services/apiservices.dart';
import '../../../../core/theme/app_theme.dart';
import '../widgets/modification_status_sheet.dart';

class ApprovalWaitingScreen extends ConsumerStatefulWidget {
  final String? orderId;
  const ApprovalWaitingScreen({super.key, this.orderId});

  @override
  ConsumerState<ApprovalWaitingScreen> createState() =>
      _ApprovalWaitingScreenState();
}

class _ApprovalWaitingScreenState extends ConsumerState<ApprovalWaitingScreen> {
  StreamSubscription<bool>? _wsSub;

  // true once we get a final APPROVED/REJECTED — stops any auto-reconnect
  bool _done = false;

  @override
  void initState() {
    super.initState();
    final orderId = widget.orderId;
    if (orderId != null && orderId.isNotEmpty) {
      _connectWs(orderId);
    } else {
      // Fallback: simulate after 4 s when no orderId provided
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _onStatusReceived(true);
      });
    }
  }

  /// Opens ONE WebSocket connection.
  /// • Stays open while every service_modification.status == PENDING
  /// • Emits once when status becomes APPROVED/APPLIED or REJECTED/DECLINED
  /// • If the server closes the socket before a final status arrives,
  ///   reconnects automatically after 5 s (so the buffer never disappears)
  void _connectWs(String orderId) {
    if (_done) return;
    _wsSub?.cancel();
    debugPrint('WS: connecting for order $orderId');

    _wsSub = ApiService.orderUpdatedStream(orderId).listen(
      // ── Final status received ────────────────────────────────────
      (bool approved) {
        _done = true;
        _wsSub?.cancel();
        if (mounted) _onStatusReceived(approved);
      },

      // ── Stream closed without a result (server drop / error) ─────
      onDone: () {
        debugPrint('WS: closed without result — reconnecting in 5 s');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_done) _connectWs(orderId);
        });
      },

      onError: (e) {
        debugPrint('WS error: $e — reconnecting in 5 s');
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted && !_done) _connectWs(orderId);
        });
      },
    );
  }

  @override
  void dispose() {
    _done = true;
    _wsSub?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────────
  // Called once with the final approved / rejected result
  // ──────────────────────────────────────────────────────────────────
  void _onStatusReceived(bool approved) async {
    debugPrint('Status received — approved: $approved');
    _wsSub?.cancel();

    // Trigger local notification
    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecond,
      approved ? 'Order Modification Approved!' : 'Order Modification Declined',
      approved
          ? 'The customer has agreed to your changes. You can now proceed.'
          : 'The customer has declined your changes.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'modification_alert_channel',
          'Modification Alerts',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
      ),
    );

    final orderId = widget.orderId;

    // 1. Fetch refreshed order details from API
    OrderDetails? refreshedOrder;
    if (orderId != null && orderId.isNotEmpty) {
      refreshedOrder = await ApiService.getOrderbyId(orderId);

      // If first fetch returned null, wait a moment and retry once
      if (refreshedOrder == null) {
        await Future.delayed(const Duration(seconds: 3));
        if (mounted) {
          refreshedOrder = await ApiService.getOrderbyId(orderId);
        }
      }
    }

    if (!mounted) return;

    // 2. Short wait so the user sees the result before transitioning
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Capture router before navigating
    final router = GoRouter.of(context);

    // 3. Navigate to job-details — pass order only if fetch succeeded
    if (refreshedOrder != null) {
      router.go('/job-details', extra: refreshedOrder);
    }

    // 4. Show ModificationStatusSheet on job-details after navigation renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final navContext = router.routerDelegate.navigatorKey.currentContext;
        if (navContext != null) {
          showModalBottomSheet(
            context: navContext,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => ModificationStatusSheet(
              isApproved: approved,
              message: approved
                  ? 'The customer has agreed to the new items and prices. You can now proceed with the service.'
                  : 'The customer declined the changes. Please stick to the original order requirements.',
            ),
          );
        }
      });
    });
  }

  // ──────────────────────────────────────────────────────────────────
  // UI — unchanged spinner screen
  // ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () {
            _done = true;
            _wsSub?.cancel();
            context.pop();
          },
        ),
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Waiting for Approval',
              style: GoogleFonts.outfit(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We have sent your modification request.\nPlease wait while the customer reviews the changes.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 48),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Do not start the additional work until approved.',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
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
