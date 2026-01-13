import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/mock_map_widget.dart';

class ServiceAreaScreen extends StatefulWidget {
  const ServiceAreaScreen({super.key});

  @override
  State<ServiceAreaScreen> createState() => _ServiceAreaScreenState();
}

class _ServiceAreaScreenState extends State<ServiceAreaScreen> {
  double _radius = 15.0; // km

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Define Service Zone',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.white.withOpacity(0.9),
        elevation: 0,
        leading: IconButton(
           icon: const Icon(Icons.close, color: Colors.black),
           onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _radius = 15.0);
            },
            child: const Text('Reset', style: TextStyle(color: AppTheme.primaryColor)),
          )
        ],
      ),
      body: Stack(
        children: [
          // Map Background
          Positioned.fill(
            child: MockMapWidget(
              overlay: Center(
                child: Container(
                  width: 200 + (_radius * 5), // dynamic visual size
                  height: 200 + (_radius * 5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacity(0.2),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: Center(
                     child: Container(
                       width: 10, height: 10,
                       decoration: const BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
                     ),
                  ),
                ),
              ),
            ),
          ),
          
          // Controls Sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Zone Radius',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${_radius.toInt()} km',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _radius,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    activeColor: AppTheme.primaryColor,
                    onChanged: (val) {
                      setState(() => _radius = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('1 km', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                      Text('50 km', style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                       context.pop();
                       ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text('Service zone updated to ${_radius.toInt()} km')),
                       );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Save Service Zone'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
