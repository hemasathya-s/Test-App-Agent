import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';

class SlotManagementScreen extends StatefulWidget {
  const SlotManagementScreen({super.key});

  @override
  State<SlotManagementScreen> createState() => _SlotManagementScreenState();
}

class _SlotManagementScreenState extends State<SlotManagementScreen> {
  DateTime _selectedDate = DateTime.now();
  
  // Mock Slots Data
  final Map<DateTime, List<String>> _slots = {};

  @override
  void initState() {
    super.initState();
    // Seed some mock data
    final today = DateTime.now();
    _slots[DateTime(today.year, today.month, today.day)] = ['09:00 AM - 12:00 PM', '02:00 PM - 06:00 PM'];
  }

  List<String> get _currentSlots {
    final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    return _slots[key] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      appBar: AppBar(
        title: Text(
          'Manage Slots',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildCalendarStrip(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Working Hours',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      '${_currentSlots.length} slots added',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_currentSlots.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 48.0),
                    child: Center(
                      child: Text(
                        'No slots added for this day.',
                        style: GoogleFonts.outfit(color: AppTheme.textSecondary),
                      ),
                    ),
                  )
                else
                  ..._currentSlots.map((slot) => _buildSlotCard(slot)),
                
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _showAddSlotDialog,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppTheme.primaryColor, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor),
                  label: Text(
                    'Add New Slot',
                    style: GoogleFonts.outfit(
                      color: AppTheme.primaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // Mock Save Logic
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Availability saved successfully!')),
            );
          },
          style: ElevatedButton.styleFrom(
             backgroundColor: AppTheme.primaryColor,
             padding: const EdgeInsets.symmetric(vertical: 16),
             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Save Changes'),
        ),
      ),
    );
  }
  
  Widget _buildCalendarStrip() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: 14, // Next 2 weeks
          itemBuilder: (context, index) {
            final date = DateTime.now().add(Duration(days: index));
            final isSelected = date.day == _selectedDate.day && date.month == _selectedDate.month;
            
            return GestureDetector(
              onTap: () => setState(() => _selectedDate = date),
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 64,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryColor : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryColor : Colors.grey.shade200,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ] : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('E').format(date),
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : AppTheme.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date.day.toString(),
                      style: GoogleFonts.outfit(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSlotCard(String slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.access_time_filled, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              slot,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppTheme.textSecondary),
            onPressed: () {
              // Edit mock logic
            },
          ),
        ],
      ),
    );
  }

  void _showAddSlotDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add New Slot',
              style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerField('Start Time', '09:00 AM'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimePickerField('End Time', '12:00 PM'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // Mock Add Logic
                final key = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
                setState(() {
                  if (_slots[key] == null) _slots[key] = [];
                  _slots[key]!.add('01:00 PM - 03:00 PM'); // Logic hardcoded for demo
                });
                Navigator.pop(context);
              },
              child: const Text('Add Slot'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimePickerField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(value, style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
              const Icon(Icons.keyboard_arrow_down, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}
