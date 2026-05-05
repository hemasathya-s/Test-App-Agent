import 'dart:async';
import 'dart:convert';

import 'package:hugeicons/hugeicons.dart';
import 'package:urban_agent_app/core/services/apiservices.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'place_picker_page.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

const kOrange = Color(0xFFF97316);
const kOrangeLight = Color(0xFFFFF8F3);
const kOrangeBorder = Color(0xFFFBD0B0);

class OrderCreationPage extends StatefulWidget {
  const OrderCreationPage({super.key});

  @override
  State<OrderCreationPage> createState() => _OrderCreationPageState();
}

class _OrderCreationPageState extends State<OrderCreationPage> {
  final _formKey = GlobalKey<FormState>();

  // Customer Info
  final _addressCtrl = TextEditingController();
  final _customerNameCtrl = TextEditingController();
  final _customerNumberCtrl = TextEditingController();
  final _customerEmailCtrl = TextEditingController();
  final _customerGstCtrl = TextEditingController();

  // Location
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  final _googleAddressCtrl = TextEditingController();

  // Order
  String? _slotId;
  bool _isInstantSlot = false;
  bool _isOtpRequired = true;
  bool _noAssignment = true;
  bool _noRazorpay = false;
  bool _isPaid = true;
  final String _orderPlatform = 'OWN_PLATFORM';
  final String _orderType = 'B2C';

  // Payment
  final _paymentMethodCtrl = TextEditingController();
  final _transactionIdCtrl = TextEditingController();
  final _partialPaymentCtrl = TextEditingController();

  // Assignment
  final _userIdCtrl = TextEditingController();
  final _hubIdCtrl = TextEditingController();
  final _zoneIdCtrl = TextEditingController();

  // Items
  final List<Map<String, dynamic>> _items = [];

  void _addItem() {
    // Validate address section before opening product sheet
    if (_addressCtrl.text.trim().isEmpty ||
        _googleAddressCtrl.text.trim().isEmpty ||
        _latCtrl.text.trim().isEmpty ||
        _lngCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in the complete address section (Address, Google Address, Latitude & Longitude) before adding items.',
          ),
          backgroundColor: Colors.grey,
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProductSelectorSheet(
        onSelected: (product) {
          setState(() => _items.add(product));
        },
        lat: _latCtrl.text,
        lng: _lngCtrl.text,
      ),
    );
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  late Razorpay _razorpay;

  @override
  void initState() {
    super.initState();
    _fetchAgentProfile();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    _transactionIdCtrl.text = response.paymentId ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment Successful'), backgroundColor: Colors.black),
    );
    _submitOrderActual();
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment Failed: ${response.message}'), backgroundColor: Colors.grey),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('External Wallet: ${response.walletName}'), backgroundColor: Colors.blue),
    );
  }

  double get _totalAmount => _items.fold(0, (sum, item) => sum + ((item['amount'] as num? ?? 0) * (item['quantity'] as num? ?? 1)));

  Future<void> _startRazorpayCheckout() async {
    final settings = await ApiService.getAppSettings();
    final apiKey = settings?['pg_api_key'];

    if (apiKey == null || apiKey.isEmpty) {
      // if (mounted) {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Razorpay Key not found in settings'), backgroundColor: Colors.grey),
      //   );
      // }
      return;
    }

    final total = _totalAmount;
    final options = {
      'key': apiKey,
      'amount': (total * 100).toInt(), // amount in the smallest currency unit
      'prefill': {
        'contact': _customerNumberCtrl.text,
        'email': _customerEmailCtrl.text,
      },
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
    }
  }

  Future<void> _fetchAgentProfile() async {
    try {
      final res = await ApiService.getAgentProfile();
      if (res.isSuccess && res.data != null) {
        final profile = res.data!;
        if (mounted) {
          setState(() {
            _hubIdCtrl.text = profile.agent.userDetails.hubId ?? '';
            _userIdCtrl.text = profile.agent.id;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching agent profile: $e');
    }
  }

  void _submitOrder() {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item'), backgroundColor: Colors.grey),
      );
      return;
    }

    // Prepare confirmation details
    final details = {
      'customer_name': _customerNameCtrl.text,
      'customer_number': _customerNumberCtrl.text,
      'customer_email': _customerEmailCtrl.text,
      'address': _googleAddressCtrl.text.isNotEmpty ? _googleAddressCtrl.text : _addressCtrl.text,
      'items': _items,
      'total': _totalAmount,
      'is_razorpay': !_noRazorpay,
      'hub_id': _hubIdCtrl.text,
      'zone_id': _zoneIdCtrl.text,
    };

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _OrderConfirmationSheet(
        details: details,
        onConfirm: () {
          Navigator.pop(context);
          if (!_noRazorpay) {
            _startRazorpayCheckout();
          } else {
            _submitOrderActual();
          }
          // _submitOrderActual();
        },
      ),
    );
  }

  void _clearForm() {
    setState(() {
      for (final c in [
        _addressCtrl, _customerNameCtrl, _customerNumberCtrl,
        _customerEmailCtrl, _customerGstCtrl, _latCtrl, _lngCtrl,
        _googleAddressCtrl, _paymentMethodCtrl, _transactionIdCtrl,
        _partialPaymentCtrl, _userIdCtrl, _hubIdCtrl, _zoneIdCtrl,
      ]) {
        c.clear();
      }
      _items.clear();
      _isPaid = true;
      _noRazorpay = false;
    });
  }

  void _submitOrderActual() async {
    final payload = {
      'address': _addressCtrl.text,
      'customer_name': _customerNameCtrl.text,
      'customer_number': _customerNumberCtrl.text,
      if (_customerEmailCtrl.text.isNotEmpty)
        'customer_email': _customerEmailCtrl.text,
      if (_customerGstCtrl.text.isNotEmpty)
        'customer_gst': _customerGstCtrl.text,
      if (_latCtrl.text.isNotEmpty) 'latitude': double.tryParse(_latCtrl.text),
      if (_lngCtrl.text.isNotEmpty)
        'longitude': double.tryParse(_lngCtrl.text),
      if (_googleAddressCtrl.text.isNotEmpty)
        'google_address': _googleAddressCtrl.text,
      if (_slotId != null) 'slot_id': _slotId,
      'is_instant_slot': _isInstantSlot,
      'is_otp_required': _isOtpRequired,
      'items': _items,
      'is_paid': _isPaid,
      if (_paymentMethodCtrl.text.isNotEmpty)
        'payment_method': _paymentMethodCtrl.text,
      if (_transactionIdCtrl.text.isNotEmpty)
        'transaction_id': _transactionIdCtrl.text,
      'no_assignment': _noAssignment,
      'no_razorpay': _noRazorpay,
      'order_platform': _orderPlatform,
      'order_type': _orderType,
      if (_partialPaymentCtrl.text.isNotEmpty)
        'partial_payment_amount': _partialPaymentCtrl.text,
      if (_userIdCtrl.text.isNotEmpty) 'user_id': _userIdCtrl.text,
      if (_hubIdCtrl.text.isNotEmpty) 'hub_id': _hubIdCtrl.text,
      if (_zoneIdCtrl.text.isNotEmpty) 'zone_id': _zoneIdCtrl.text,
    };

    // Print payload in JSON format to console
    debugPrint('FINAL ORDER PAYLOAD: ${jsonEncode(payload)}');

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: kOrange),
      ),
    );

    try {
      final res = await ApiService.createOrder(payload);

      // Close Loading
      if (mounted) Navigator.pop(context);

      if (res.isSuccess) {
        if (mounted) {
          _clearForm();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F9F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF22C55E), size: 44),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Order Created!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Your order has been created successfully.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(ctx).pop(); // close dialog
                          Navigator.of(context).pop(); // go back
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: const Text('Done',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res.error ?? 'Failed to create order'),
              backgroundColor: Colors.grey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading if error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: kOrange,
        foregroundColor: Colors.white,
        title: const Text('Create New Order',
            style: TextStyle(fontWeight: FontWeight.w500)),
        elevation: 0,
        leading: IconButton(onPressed: (){Navigator.pop(context);}, icon: const Icon(HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white, size: 24))
      ),
      body: SafeArea(
        child:Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (_orderType == 'B2C') ...[
                _CustomerInfoCard(
                  addressCtrl: _addressCtrl,
                  nameCtrl: _customerNameCtrl,
                  numberCtrl: _customerNumberCtrl,
                  emailCtrl: _customerEmailCtrl,
                  gstCtrl: _customerGstCtrl,
                ),
                const SizedBox(height: 10),
                _DeliveryAddressCard(
                  addressCtrl: _addressCtrl,
                  latCtrl: _latCtrl,
                  lngCtrl: _lngCtrl,
                  googleCtrl: _googleAddressCtrl,
                ),
                const SizedBox(height: 10),
              ],
              _ItemsCard(
                items: _items,
                onAdd: _addItem,
                onRemove: _removeItem,
                onChanged: (i, key, val) =>
                    setState(() => _items[i][key] = val),
              ),
              const SizedBox(height: 10),
              // _OrderSettingsCard(
              //   isInstantSlot: _isInstantSlot,
              //   isOtpRequired: _isOtpRequired,
              //   noAssignment: _noAssignment,
              //   orderPlatform: _orderPlatform,
              //   orderType: _orderType,
              //   onInstantSlotChanged: (v) =>
              //       setState(() => _isInstantSlot = v),
              //   onOtpChanged: (v) => setState(() => _isOtpRequired = v),
              //   onNoAssignmentChanged: (v) =>
              //       setState(() => _noAssignment = v),
              //   onPlatformChanged: (v) =>
              //       setState(() => _orderPlatform = v!),
              //   onTypeChanged: (v) => setState(() => _orderType = v!),
              // ),
              if (_orderType == 'B2C') ...[
                const SizedBox(height: 10),
                _PaymentCard(
                  isPaid: _isPaid,
                  noRazorpay: _noRazorpay,
                  methodCtrl: _paymentMethodCtrl,
                  txnCtrl: _transactionIdCtrl,
                  partialCtrl: _partialPaymentCtrl,
                  onPaidChanged: (v) => setState(() => _isPaid = v),
                  onNoRazorpayChanged: (v) =>
                      setState(() => _noRazorpay = v),
                ),
                const SizedBox(height: 10),
                // _AssignmentCard(
                //   hubCtrl: _hubIdCtrl,
                //   zoneCtrl: _zoneIdCtrl,
                //   userCtrl: _userIdCtrl,
                // ),
              ],
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Create Order',
                    style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _razorpay.clear();
    for (final c in [
      _addressCtrl, _customerNameCtrl, _customerNumberCtrl,
      _customerEmailCtrl, _customerGstCtrl, _latCtrl, _lngCtrl,
      _googleAddressCtrl, _paymentMethodCtrl, _transactionIdCtrl,
      _partialPaymentCtrl, _userIdCtrl, _hubIdCtrl, _zoneIdCtrl,
    ]) c.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Section cards
// ---------------------------------------------------------------------------

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5), width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: kOrange, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    color: kOrange,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

InputDecoration _fieldDecor(String label, {String? hint}) => InputDecoration(
  labelText: label,
  hintText: hint,
  labelStyle: const TextStyle(fontSize: 14, color: Color(0xFF888888)),
  hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBBBBB)),
  contentPadding:
  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  filled: true,
  fillColor: const Color(0xFFFAFAFA),
  border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:
      const BorderSide(color: Color(0xFFE8E8E8), width: 1)),
  enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide:
      const BorderSide(color: Color(0xFFE8E8E8), width: 1)),
  focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: kOrange, width: 1.5)),
);

// ---------------------------------------------------------------------------

class _CustomerInfoCard extends StatelessWidget {
  const _CustomerInfoCard({
    required this.addressCtrl,
    required this.nameCtrl,
    required this.numberCtrl,
    required this.emailCtrl,
    required this.gstCtrl,
  });

  final TextEditingController addressCtrl, nameCtrl, numberCtrl,
      emailCtrl, gstCtrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Customer info', children: [
      TextFormField(
        controller: nameCtrl,
        decoration: _fieldDecor('Customer name *'),
        validator: (v) =>
        (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: numberCtrl,
        maxLength: 10,
        keyboardType: TextInputType.phone,
        decoration: _fieldDecor('Customer number *'),
        validator: (v) =>
        (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _fieldDecor('Email', hint: 'Optional'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: gstCtrl,
            decoration: _fieldDecor('GST number', hint: 'Optional'),
          ),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _DeliveryAddressCard extends StatelessWidget {
  const _DeliveryAddressCard({
    required this.addressCtrl,
    required this.latCtrl,
    required this.lngCtrl,
    required this.googleCtrl,
  });

  final TextEditingController addressCtrl, latCtrl, lngCtrl, googleCtrl;

  Future<void> _pickLocation(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PlacePickerPage(
          initialLocation: (latCtrl.text.isNotEmpty && lngCtrl.text.isNotEmpty)
              ? LatLng(double.tryParse(latCtrl.text) ?? 0,
                  double.tryParse(lngCtrl.text) ?? 0)
              : null,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      googleCtrl.text = result['address'] ?? '';
      addressCtrl.text = result['address'] ?? '';
      latCtrl.text = result['lat']?.toString() ?? '';
      lngCtrl.text = result['lng']?.toString() ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Delivery address', children: [
      TextFormField(
        controller: addressCtrl,
        decoration: _fieldDecor('Address *'),
        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
      ),
      const SizedBox(height: 8),
      TextFormField(
        controller: googleCtrl,
        readOnly: true,
        onTap: () => _pickLocation(context),
        decoration: _fieldDecor('Google address', hint: 'Search on map').copyWith(
            suffixIcon: IconButton(
          icon: const Icon(Icons.add_location_alt_outlined, color: kOrange, size: 20),
          onPressed: () => _pickLocation(context),
        )),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: latCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecor('Latitude'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: lngCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _fieldDecor('Longitude'),
          ),
        ),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.items,
    required this.onAdd,
    required this.onRemove,
    required this.onChanged,
  });

  final List<Map<String, dynamic>> items;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int, String, dynamic) onChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Order items *', children: [
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(
            child: Text('No items added to this order.',
                style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
          ),
        )
      else
        ...items.asMap().entries.map((e) {
          final i = e.key;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: kOrangeLight,
              border: Border.all(color: kOrangeBorder, width: 1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(items[i]['name'] ?? 'Item ${i + 1}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333))),
                    if (items[i]['amount'] != null)
                      Text('₹${items[i]['amount']}',
                          style: const TextStyle(fontSize: 12, color: kOrange)),
                  ],
                ),
              ),
              Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3EA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Qty: ${items[i]['quantity']}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFC2410C),
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onRemove(i),
                child: const Icon(Icons.close,
                    size: 20, color: Color(0xFFAAAAAA)),
              ),
            ]),
          );
        }),
      GestureDetector(
        onTap: onAdd,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
                color: kOrange, width: 1.5,
                style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('+ Add item',
                style: TextStyle(
                    fontSize: 13,
                    color: kOrange,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _OrderSettingsCard extends StatelessWidget {
  const _OrderSettingsCard({
    required this.isInstantSlot,
    required this.isOtpRequired,
    required this.noAssignment,
    required this.orderPlatform,
    required this.orderType,
    required this.onInstantSlotChanged,
    required this.onOtpChanged,
    required this.onNoAssignmentChanged,
    required this.onPlatformChanged,
    required this.onTypeChanged,
  });

  final bool isInstantSlot, isOtpRequired, noAssignment;
  final String orderPlatform, orderType;
  final ValueChanged<bool> onInstantSlotChanged, onOtpChanged,
      onNoAssignmentChanged;
  final ValueChanged<String?> onPlatformChanged, onTypeChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Order settings', children: [
      DropdownButtonFormField<String>(
        value: orderType,
        decoration: _fieldDecor('Order type'),
        items: const [
          DropdownMenuItem(value: 'B2C', child: Text('B2C — Business to Consumer')),
        ],
        onChanged: onTypeChanged,
      ),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: orderPlatform,
        decoration: _fieldDecor('Order platform'),
        items: const [
          DropdownMenuItem(value: 'OWN_PLATFORM', child: Text('Own Platform')),
        ],
        onChanged: onPlatformChanged,
      ),
      const SizedBox(height: 8),
      // TextFormField(
      //   decoration: _fieldDecor('Delivery slot ID', hint: 'UUID (optional)'),
      // ),
      // const SizedBox(height: 10),
      // _ToggleRow('Instant slot', isInstantSlot, onInstantSlotChanged),
      // _ToggleRow('OTP required', isOtpRequired, onOtpChanged),
      // _ToggleRow('No assignment', noAssignment, onNoAssignmentChanged),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    required this.isPaid,
    required this.noRazorpay,
    required this.methodCtrl,
    required this.txnCtrl,
    required this.partialCtrl,
    required this.onPaidChanged,
    required this.onNoRazorpayChanged,
  });

  final bool isPaid, noRazorpay;
  final TextEditingController methodCtrl, txnCtrl, partialCtrl;
  final ValueChanged<bool> onPaidChanged, onNoRazorpayChanged;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Payment', children: [
      _ToggleRow('Razorpay Payment', !noRazorpay, (v) => onNoRazorpayChanged(!v)),
      if (noRazorpay) ...[
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: kOrange, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          const Text(
            'USER ALREADY PAID',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: kOrange, letterSpacing: 0.5),
          ),
        ]),
        const SizedBox(height: 12),
        _ToggleRow('Order paid', isPaid, onPaidChanged),
        const SizedBox(height: 8),
        TextFormField(
          controller: methodCtrl,
          decoration: _fieldDecor('Payment method', hint: 'e.g. CASH, UPI'),
          validator: (v) => (v == null || v.isEmpty) ? 'Required for manual payment' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: txnCtrl,
          decoration: _fieldDecor('Transaction ID', hint: 'Manual reference ID'),
          //validator: (v) => (v == null || v.isEmpty) ? 'Required for manual payment' : null,
        ),
      ],
      const SizedBox(height: 8),
      // TextFormField(
      //   controller: partialCtrl,
      //   keyboardType:
      //   const TextInputType.numberWithOptions(decimal: true),
      //   decoration:
      //   _fieldDecor('Partial payment amount', hint: '₹ 0.00'),
      // ),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({
    required this.hubCtrl,
    required this.zoneCtrl,
    required this.userCtrl,
  });

  final TextEditingController hubCtrl, zoneCtrl, userCtrl;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(title: 'Assignment', children: [
      Row(children: [
        Expanded(
          child: TextFormField(
            controller: hubCtrl,
            decoration: _fieldDecor('Hub ID', hint: 'UUID'),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: zoneCtrl,
            decoration: _fieldDecor('Zone ID', hint: 'UUID'),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      TextFormField(
        controller: userCtrl,
        decoration: _fieldDecor('User ID', hint: 'UUID (optional)'),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------

class _ToggleRow extends StatelessWidget {
  const _ToggleRow(this.label, this.value, this.onChanged);
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 14, color: Color(0xFF444444))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kOrange,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _ProductSelectorSheet extends StatefulWidget {
  const _ProductSelectorSheet(
      {required this.onSelected, required this.lat, required this.lng});
  final Function(Map<String, dynamic>) onSelected;
  final String lat;
  final String lng;

  @override
  State<_ProductSelectorSheet> createState() => _ProductSelectorSheetState();
}

class _ProductSelectorSheetState extends State<_ProductSelectorSheet> {
  final List<Map<String, dynamic>> _products = [];
  final Map<String, TextEditingController> _qtyCtrls = {};
  final Map<String, TextEditingController> _priceCtrls = {};
  int _currentPage = 1;
  int _totalProducts = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String _searchQuery = '';
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    _fetchProducts();
    print("Munal location lat and lng ${widget.lat} , ${widget.lng}");
  }

  @override
  void dispose() {
    _debounce?.cancel();
    for (final c in _qtyCtrls.values) c.dispose();
    for (final c in _priceCtrls.values) c.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecorSheet(String prefix, {String? hint}) => InputDecoration(
        prefixText: prefix,
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: kOrange),
        ),
      );

  void _onScroll(ScrollController sc) {
    if (sc.position.pixels >= sc.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _fetchProducts(loadMore: true);
    }
  }

  Map<String, bool> _addingIds = {};

  Future<void> _fetchProducts({bool loadMore = false}) async {
    if (loadMore) {
      if (mounted) setState(() => _isLoadingMore = true);
    } else {
      if (mounted) setState(() => _isLoading = true);
      _currentPage = 1;
      _products.clear();
    }

    final res = await ApiService.listProduct(
      lat: widget.lat,
      lng: widget.lng,
      // search: _searchQuery,
      page: _currentPage,
      size: 20,
    );

    if (res.isSuccess && res.data != null) {
      final pResp = res.data!;
      if (mounted) {
        setState(() {
          _products.addAll(pResp.products);
          for (final p in pResp.products) {
            final pid = p['id']?.toString() ?? UniqueKey().toString();
            if (!_qtyCtrls.containsKey(pid)) {
              _qtyCtrls[pid] = TextEditingController(text: '1');
              double price = 0.0;
              if (p['pricing'] is List && (p['pricing'] as List).isNotEmpty) {
                final pricingList = p['pricing'] as List;
                final sellingEntry = pricingList.firstWhere(
                  (e) => e['pricing_type_name'] == 'SELLING',
                  orElse: () => pricingList.first,
                );
                price = double.tryParse(sellingEntry['price']?.toString() ?? '0') ?? 0.0;
              }
              _priceCtrls[pid] = TextEditingController(text: price.toString());
            }
          }
          _totalProducts = pResp.total;
          _hasMore = pResp.hasMore;
          _currentPage++;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _searchQuery = val;
      _fetchProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Drag Handle
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
          
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Product',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                      ),
                      if (!_isLoading)
                        Text(
                          '$_totalProducts found',
                          style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
          
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search for products or brands...',
                      hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: kOrange, size: 20),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: kOrange, width: 1.5),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
          
                // Product List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: kOrange))
                      : _products.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[300]),
                                  const SizedBox(height: 16),
                                  Text('No products found', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController..addListener(() => _onScroll(scrollController)),
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              itemCount: _products.length + (_hasMore ? 1 : 0),
                              itemBuilder: (context, i) {
                                if (i == _products.length) {
                                  return const Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Center(child: CircularProgressIndicator(color: kOrange, strokeWidth: 2)),
                                  );
                                }
          
                                final pMap = _products[i];
                                final id = pMap['id']?.toString() ?? i.toString();
                                final name = pMap['name']?.toString() ?? 'Unknown Product';
                                final qtyCtrl = _qtyCtrls[id];
                                final priceCtrl = _priceCtrls[id];
                                
                                // Extract media
                                String? imageUrl;
                                final mediaList = pMap['media'];
                                if (mediaList is List && mediaList.isNotEmpty) {
                                  final firstMedia = mediaList[0];
                                  if (firstMedia is Map) {
                                    imageUrl = firstMedia['file_url']?.toString();
                                  }
                                }
          
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: Colors.grey[200]!),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Thumbnail
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: Colors.grey[100],
                                                borderRadius: BorderRadius.circular(12),
                                                image: imageUrl != null
                                                    ? DecorationImage(
                                                        image: NetworkImage(imageUrl),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: imageUrl == null
                                                  ? Icon(Icons.image_not_supported_outlined, color: Colors.grey[400], size: 24)
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    name,
                                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    () {
                                                      final brand = pMap['brand'];
                                                      if (brand is Map) return brand['name']?.toString() ?? 'General';
                                                      if (brand is List && brand.isNotEmpty) {
                                                        final first = brand[0];
                                                        if (first is Map) return first['name']?.toString() ?? 'General';
                                                        return first.toString();
                                                      }
                                                      return brand?.toString() ?? 'General';
                                                    }(),
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          child: Divider(height: 1),
                                        ),
                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 3,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Price (Edit if needed)', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 6),
                                                  SizedBox(
                                                    height: 40,
                                                    child: TextFormField(
                                                      controller: priceCtrl,
                                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                      decoration: _fieldDecorSheet('₹'),
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text('Qty', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                                                  const SizedBox(height: 6),
                                                  SizedBox(
                                                    height: 40,
                                                    child: TextFormField(
                                                      controller: qtyCtrl,
                                                      keyboardType: TextInputType.number,
                                                      decoration: _fieldDecorSheet(''),
                                                      textAlign: TextAlign.center,
                                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Padding(
                                              padding: const EdgeInsets.only(top: 18),
                                              child: ElevatedButton(
                                                onPressed: _addingIds[id] == true ? null : () async {
                                                  final q = int.tryParse(qtyCtrl?.text ?? '1') ?? 1;
                                                  final p = double.tryParse(priceCtrl?.text ?? '0.0') ?? 0.0;

                                                  if (mounted) setState(() => _addingIds[id] = true);
                                                  
                                                  try {
                                                    final res = await ApiService.getProductDetails(id);
                                                    if (res.isSuccess && res.data != null) {
                                                      // Find the possession for this product
                                                      final possession = res.data!.myPossession.firstWhere(
                                                        (element) => element.productDetails.id == id,
                                                        orElse: () => res.data!.myPossession.isNotEmpty 
                                                            ? res.data!.myPossession.first 
                                                            : throw Exception('No possession found'),
                                                      );

                                                      if (possession.availableSerialNumbers.length < q) {
                                                        if (mounted) {
                                                          ScaffoldMessenger.of(context).showSnackBar(
                                                            SnackBar(
                                                              content: Text('Insufficient serial numbers. Only ${possession.availableSerialNumbers.length} available.'),
                                                              backgroundColor: Colors.grey,
                                                            ),
                                                          );
                                                        }
                                                        return;
                                                      }

                                                      widget.onSelected({
                                                        'type': 'PRODUCT',
                                                        'product_id': id,
                                                        'name': name, // kept for UI
                                                        'quantity': q,
                                                        'attributes': {}, // as requested "no show attributes"
                                                        'amount': p, // as requested "amount"
                                                        'serial_numbers': possession.availableSerialNumbers.take(q).toList(),
                                                      });
                                                      Navigator.pop(context);
                                                    } else {
                                                      throw Exception(res.error ?? 'Failed to get product details');
                                                    }
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.grey),
                                                      );
                                                    }
                                                  } finally {
                                                    if (mounted) setState(() => _addingIds[id] = false);
                                                  }
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: kOrange,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(60, 40),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                  elevation: 0,
                                                ),
                                                child: _addingIds[id] == true
                                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                                    : const Text('Add', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _OrderConfirmationSheet extends StatelessWidget {
  const _OrderConfirmationSheet({required this.details, required this.onConfirm});
  final Map<String, dynamic> details;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final items = details['items'] as List<Map<String, dynamic>>;
    final total = details['total'] as double;
    final isRazorpay = details['is_razorpay'] as bool;

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF9FAFB),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Review Order',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _SummarySection(
                      title: 'Customer Details',
                      items: [
                        _SummaryRow('Name', details['customer_name']),
                        _SummaryRow('Phone', details['customer_number']),
                        if (details['customer_email'].isNotEmpty)
                          _SummaryRow('Email', details['customer_email']),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SummarySection(
                      title: 'Delivery Address',
                      items: [
                        _SummaryRow('Address', details['address'], isMultiline: true),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SummarySection(
                      title: 'Order Items',
                      items: items.map((item) {
                        final name = item['name'];
                        final qty = item['quantity'];
                        final price = item['amount'];
                        return _SummaryRow(
                          '$name x $qty',
                          '₹${(price * qty).toStringAsFixed(2)}',
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    if (details['hub_id'].isNotEmpty || details['zone_id'].isNotEmpty)
                      _SummarySection(
                        title: 'Assignment',
                        items: [
                          if (details['hub_id'].isNotEmpty) _SummaryRow('Hub ID', details['hub_id']),
                          if (details['zone_id'].isNotEmpty) _SummaryRow('Zone ID', details['zone_id']),
                        ],
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Amount', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                              Text('₹${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kOrange)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isRazorpay ? Colors.blue[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isRazorpay ? 'Razorpay Payment' : 'Manual Payment',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isRazorpay ? Colors.blue[700] : Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: onConfirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kOrange,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: Text(
                          isRazorpay ? 'Confirm & Pay' : 'Confirm Order',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({required this.title, required this.items});
  final String title;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ).copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 0.5),
          ),
          const SizedBox(height: 12),
          ...items,
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value, {this.isMultiline = false});
  final String label;
  final String value;
  final bool isMultiline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
            ),
          ),
        ],
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  const _QtyBtn(this.icon, this.onTap);
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF4B5563)),
      ),
    );
  }
}