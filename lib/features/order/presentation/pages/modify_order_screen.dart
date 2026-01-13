import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/order_modification_provider.dart';

class ModifyOrderScreen extends ConsumerWidget {
  const ModifyOrderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderModificationProvider);
    final controller = ref.read(orderModificationProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Modify Order',
          style: GoogleFonts.outfit(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Order Info Header
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[50], // Light bg
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #12345',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Customer: Jane Doe',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.successColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Active',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              color: AppTheme.successColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[900],
                      borderRadius: BorderRadius.circular(8),
                    ), // Placeholder black box from design
                  ),
                ],
              ),
            ),
          ),

          // Items List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Items',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Clear all',
                      style: GoogleFonts.outfit(color: AppTheme.primaryColor),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                ...state.items
                    .where((i) => !i.isRemoved)
                    .map(
                      (item) => Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)} / unit',
                                        style: GoogleFonts.outfit(
                                          color: AppTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '\$${(item.price * item.quantity).toStringAsFixed(2)}',
                                        style: GoogleFonts.outfit(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    color: AppTheme.textSecondary,
                                  ),
                                  onPressed: () =>
                                      controller.removeItem(item.id),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildQtyBtn(
                                  Icons.remove,
                                  () => controller.updateQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    item.quantity.toString(),
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                _buildQtyBtn(
                                  Icons.add,
                                  () => controller.updateQuantity(
                                    item.id,
                                    item.quantity + 1,
                                  ),
                                  isColor: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                // Add Item Button
                InkWell(
                  onTap: () {
                    // Mock Add Item
                    controller.addItem('Deep Cleaning (3h)', 90.0);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primaryColor,
                        style: BorderStyle.solid,
                      ), // dashed border hard to do with standard Border
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Add another item',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Totals
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Original Total',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          Text(
                            '\$${state.originalTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              color: AppTheme.textSecondary,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Total',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '\$${state.newTotal.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Difference',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '+ \$${(state.newTotal - state.originalTotal).toStringAsFixed(2)}',
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Reason Input
                Text(
                  'Reason for change',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        'Add a note for the approver explaining why this change is necessary...',
                    hintStyle: GoogleFonts.outfit(
                      color: AppTheme.textSecondary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  onChanged: controller.setNote,
                ),

                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    context.push('/modification-summary');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Request Approval',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(
    IconData icon,
    VoidCallback onTap, {
    bool isColor = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isColor ? AppTheme.primaryColor : Colors.grey[100],
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 20,
          color: isColor ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
