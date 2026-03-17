import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

class OrderItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final double originalPrice;    // Track price at load time
  final int originalQuantity;    // Track quantity at load time
  final bool isNew;
  final bool isRemoved;
  final String? imageUrl;
  final String? type;

  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    required this.originalPrice,
    required this.originalQuantity,
    this.isNew = false,
    this.isRemoved = false,
    this.imageUrl,
    this.type,
  });

  OrderItem copyWith({
    String? name,
    double? price,
    int? quantity,
    bool? isRemoved,
    String? imageUrl,
    String? type,
  }) {
    return OrderItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      originalPrice: originalPrice,
      originalQuantity: originalQuantity,
      isNew: isNew,
      isRemoved: isRemoved ?? this.isRemoved,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
    );
  }

  bool get isChanged => !isNew && (quantity != originalQuantity || price != originalPrice);
}

class RequestRecord {
  final String id;
  final String orderId;
  final String type;
  final String status;
  final String time;
  final String items;
  final String note;

  RequestRecord({
    required this.id,
    required this.orderId,
    required this.type,
    required this.status,
    required this.time,
    required this.items,
    required this.note,
  });
}

class OrderModificationState {
  final List<OrderItem> items;
  final String? note;
  final bool isWaitingForApproval;
  final List<RequestRecord> requestHistory;

  const OrderModificationState({
    this.items = const [],
    this.note,
    this.isWaitingForApproval = false,
    this.requestHistory = const [],
  });

  OrderModificationState copyWith({
    List<OrderItem>? items,
    String? note,
    bool? isWaitingForApproval,
    List<RequestRecord>? requestHistory,
  }) {
    return OrderModificationState(
      items: items ?? this.items,
      note: note ?? this.note,
      isWaitingForApproval: isWaitingForApproval ?? this.isWaitingForApproval,
      requestHistory: requestHistory ?? this.requestHistory,
    );
  }

  // Original items that remain unchanged
  List<OrderItem> get unmodifiedItems =>
      items.where((i) => !i.isNew && !i.isRemoved && !i.isChanged).toList();

  // Original items that were modified (price/qty change)
  List<OrderItem> get modifiedOriginalItems =>
      items.where((i) => !i.isNew && !i.isRemoved && i.isChanged).toList();

  // New items added during this session
  List<OrderItem> get newlyAddedItems =>
      items.where((i) => i.isNew && !i.isRemoved).toList();

  // Items marked for removal
  List<OrderItem> get removedItems =>
      items.where((i) => i.isRemoved).toList();

  double get originalTotal =>
      items.where((i) => !i.isNew).fold(0, (sum, i) => sum + (i.originalPrice * i.originalQuantity));

  // New total reflects the current modifications
  double get newTotal =>
      items.where((i) => !i.isRemoved).fold(0, (sum, i) => sum + (i.price * i.quantity));
}

class OrderModificationController extends StateNotifier<OrderModificationState> {
  OrderModificationController() : super(const OrderModificationState(items: [], requestHistory: []));

  /// Load real items from the API OrderDetails into the modification state
  void loadFromOrderItems(List<OrderItem> items) {
    state = state.copyWith(items: items);
  }

  void addItem(String name, double price, {String? type}) {
    final newItem = OrderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      price: price,
      isNew: true,
      quantity: 1,
      originalPrice: 0,
      originalQuantity: 0,
      type: type,
    );
    state = state.copyWith(items: [...state.items, newItem]);
  }

  void replaceItem(String id, String newName, double newPrice) {
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id
              ? i.copyWith(name: newName, price: newPrice, quantity: 1, isRemoved: false)
              : i)
          .toList(),
    );
  }

  void removeItem(String id) {
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(isRemoved: true, quantity: 0) : i)
          .toList(),
    );
  }

  void updateQuantity(String id, int qty) {
    if (qty < 0) return;
    if (qty == 0) {
      removeItem(id);
      return;
    }
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(quantity: qty) : i)
          .toList(),
    );
  }

  void setNote(String note) {
    state = state.copyWith(note: note);
  }

  void submitRequest() {
    final newRequest = RequestRecord(
      id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      orderId: 'ORD-123',
      type: 'Order Modification',
      status: 'Pending',
      time: 'Just now',
      items: state.items
          .where((i) => !i.isRemoved && i.isNew)
          .map((i) => i.name)
          .join(', '),
      note: state.note ?? 'No note provided',
    );

    debugPrint('TEST LOG: Request submitted with ID: ${newRequest.id}');
    debugPrint('TEST LOG: Modified Items: ${newRequest.items}');

    state = state.copyWith(
      isWaitingForApproval: true,
      requestHistory: [newRequest, ...state.requestHistory],
    );
  }

  void updateRequestStatus(String requestId, String status) {
    debugPrint('TEST LOG: Updating Request $requestId to status: $status');
    state = state.copyWith(
      requestHistory: state.requestHistory.map((req) {
        if (req.id == requestId) {
          return RequestRecord(
            id: req.id,
            orderId: req.orderId,
            type: req.type,
            status: status,
            time: req.time,
            items: req.items,
            note: req.note,
          );
        }
        return req;
      }).toList(),
    );
  }
}

final orderModificationProvider =
    StateNotifierProvider<OrderModificationController, OrderModificationState>((ref) {
  return OrderModificationController();
});
