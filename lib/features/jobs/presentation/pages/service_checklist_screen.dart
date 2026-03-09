import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/job_provider.dart';

class ServiceChecklistScreen extends ConsumerStatefulWidget {
  const ServiceChecklistScreen({super.key});

  @override
  ConsumerState<ServiceChecklistScreen> createState() =>
      _ServiceChecklistScreenState();
}

class _ServiceChecklistScreenState
    extends ConsumerState<ServiceChecklistScreen> {
  // Mock Checklist State
  final Map<String, bool> _tasks = {
    'Inspect air filters': false,
    'Check thermostat': false,
    'Clean condenser coils': false,
    'Verify coolant levels': false,
    'Electrical inspection': false,
  };

  bool get _allCompleted => _tasks.values.every((v) => v);

  @override
  Widget build(BuildContext context) {
    final progress =
        (_tasks.values.where((v) => v).length / _tasks.length) * 100;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              'Quarterly Inspection',
              style: GoogleFonts.outfit(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Text(
            //   'Step ${_tasks.values.where((v) => v).length} of ${_tasks.length}',
            //   style: GoogleFonts.outfit(
            //     fontSize: 12,
            //     color: AppTheme.textSecondary,
            //   ),
            // ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => context.pop(), // Cancel?
            child: const Text('Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Bar
          // LinearProgressIndicator(
          //   value: progress / 100,
          //   backgroundColor: Colors.grey[200],
          //   color: AppTheme.primaryColor,
          //   minHeight: 6,
          // ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tasks',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Text(
                    //   '${progress.toInt()}%',
                    //   style: GoogleFonts.outfit(
                    //     color: AppTheme.primaryColor,
                    //     fontWeight: FontWeight.bold,
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 16),

                ..._tasks.entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: entry.value
                            ? AppTheme.primaryColor
                            : Colors.transparent,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CheckboxListTile(
                      value: entry.value,
                      activeColor: AppTheme.primaryColor,
                      title: Text(
                        entry.key,
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w500),
                      ),
                      subtitle: entry.key.contains('coils')
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.camera_alt,
                                    size: 16,
                                    color: Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Photo Required',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : null,
                      onChanged: (val) {
                        setState(() {
                          _tasks[entry.key] = val!;
                        });
                      },
                    ),
                  );
                }),

                if (_tasks.entries.any(
                  (e) => e.key.contains('coils') && !e.value,
                ))
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[100]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: () {
                          // Capture mock logic
                          setState(() {
                            _tasks['Clean condenser coils'] =
                                true; // Auto fulfill
                          });
                        },
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.orange,
                        ),
                        label: const Text(
                          'Add Evidence',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: SafeArea(
              child: ElevatedButton(
                onPressed: _allCompleted
                    ? () {
                        ref
                            .read(jobProvider.notifier)
                            .completeJob(); // Or navigate to stock
                        context.go('/home'); // Or finish flow
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Job Completed Successfully!'),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _allCompleted ? 'Complete Job' : 'Complete All Tasks',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_allCompleted) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_outline),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
