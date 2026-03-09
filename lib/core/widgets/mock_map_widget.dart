import 'package:flutter/material.dart';


class MockMapWidget extends StatelessWidget {
  final List<Widget> markers;
  final Widget? overlay;
  final bool interactionsEnabled;

  const MockMapWidget({
    super.key,
    this.markers = const [],
    this.overlay,
    this.interactionsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE5E3DF), // Google Maps default bg color
      child: Stack(
        children: [
          // Grid lines to look like a map
          LayoutBuilder(builder: (context, constraints) {
            return CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _MapGridPainter(),
            );
          }),
          
          // Placeholders for "Map Features"
          Positioned(
            top: 100,
            left: 50,
            child: _buildMapLabel('Park'),
          ),
           Positioned(
            bottom: 200,
            right: 80,
            child: _buildMapLabel('Hospital'),
          ),
          
          // Custom Markers
          ...markers,

          // Overlay (e.g. Service Radius Circle)
          if (overlay != null) overlay!,

          // Google Logo Mock
          Positioned(
            bottom: 24,
            left: 24,
            child: Opacity(
              opacity: 0.5,
              child: Text(
                'Google',
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapLabel(String text) {
    return Column(
      children: [
        Icon(Icons.park, color: Colors.green[300], size: 20),
        Text(
          text,
          style: TextStyle(
            color: Colors.grey[600],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final roadPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    // Draw some random "roads"
    final path = Path();
    path.moveTo(0, size.height * 0.3);
    path.cubicTo(size.width * 0.4, size.height * 0.3, size.width * 0.6, size.height * 0.7, size.width, size.height * 0.6);
    
    final path2 = Path();
    path2.moveTo(size.width * 0.3, 0);
    path2.lineTo(size.width * 0.3, size.height);

    canvas.drawPath(path, roadPaint);
    canvas.drawPath(path2, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
