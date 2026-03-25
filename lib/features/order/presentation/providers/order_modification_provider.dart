import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../../core/services/apiservices.dart';

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

  // API payload fields
  /// The original order item UUID from the server (used for REPLACE/DELETE)
  final String? originalOrderItemId;
  /// The original service/product UUID (used to detect entity changes)
  final String? originalEntityId;
  /// The new service/product UUID (used for ADD/REPLACE)
  final String? newEntityId;
  /// REPLACE | ADD | REMOVE
  final String? modificationType;
  /// SERVICE | PRODUCT
  final String? itemType;

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
    this.originalOrderItemId,
    this.originalEntityId,
    this.newEntityId,
    this.modificationType,
    this.itemType,
  });

  OrderItem copyWith({
    String? name,
    double? price,
    int? quantity,
    bool? isRemoved,
    String? imageUrl,
    String? type,
    String? originalOrderItemId,
    String? originalEntityId,
    String? newEntityId,
    String? modificationType,
    String? itemType,
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
      originalOrderItemId: originalOrderItemId ?? this.originalOrderItemId,
      originalEntityId: originalEntityId ?? this.originalEntityId,
      newEntityId: newEntityId ?? this.newEntityId,
      modificationType: modificationType ?? this.modificationType,
      itemType: itemType ?? this.itemType,
    );
  }

  bool get isChanged => !isNew && (quantity != originalQuantity || price != originalPrice || newEntityId != originalEntityId);
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
  final double basePrice;

  const OrderModificationState({
    this.items = const [],
    this.note,
    this.isWaitingForApproval = false,
    this.requestHistory = const [],
    this.basePrice = 0.0,
  });

  OrderModificationState copyWith({
    List<OrderItem>? items,
    String? note,
    bool? isWaitingForApproval,
    List<RequestRecord>? requestHistory,
    double? basePrice,
  }) {
    return OrderModificationState(
      items: items ?? this.items,
      note: note ?? this.note,
      isWaitingForApproval: isWaitingForApproval ?? this.isWaitingForApproval,
      requestHistory: requestHistory ?? this.requestHistory,
      basePrice: basePrice ?? this.basePrice,
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
  double get newTotal {
    final activeItems = items.where((i) => !i.isRemoved);
    final itemsTotal = activeItems.fold(0.0, (sum, i) => sum + (i.price * i.quantity));
    
    // Add base price only if ALL items are removed
    if (activeItems.isEmpty && basePrice > 0) {
      return basePrice;
    }
    return itemsTotal;
  }
}

class OrderModificationController extends StateNotifier<OrderModificationState> {
  OrderModificationController() : super(const OrderModificationState(items: [], requestHistory: [])) {
    fetchBasePrice();
  }

  Future<void> fetchBasePrice() async {
    try {
      final settings = await ApiService.getAppSettings();
      if (settings != null && settings['base_price'] != null) {
        final bp = double.tryParse(settings['base_price'].toString()) ?? 0.0;
        state = state.copyWith(basePrice: bp);
      }
    } catch (e) {
      debugPrint('Error fetching base price: $e');
    }
  }

  /// Load real items from the API OrderDetails into the modification state
  void loadFromOrderItems(List<OrderItem> items) {
    state = state.copyWith(items: items);
  }

  /// Add a brand-new item.
  /// [newEntityId] = the service/product UUID from the catalogue.
  /// [type] = 'service' or 'product'.
  /// Returns false if the item is a duplicate and already exists in the list.
  bool addItem(String name, double price, {String? type, String? newEntityId}) {
    // Check if item already exists and is NOT removed
    final exists = state.items.any((i) => !i.isRemoved && (i.newEntityId == newEntityId || i.originalEntityId == newEntityId));
    if (exists) return false;

    // Check if item was removed, if so, restore it
    final removedItem = state.items.where((i) => i.isRemoved && (i.newEntityId == newEntityId || i.originalEntityId == newEntityId)).firstOrNull;
    if (removedItem != null) {
      updateQuantity(removedItem.id, 1);
      return true;
    }

    final itemTypeUpper = (type ?? '').toUpperCase();
    final newItem = OrderItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_${state.items.length}',
      name: name,
      price: price,
      isNew: true,
      quantity: 1,
      originalPrice: 0,
      originalQuantity: 0,
      type: type,
      newEntityId: newEntityId,
      modificationType: 'ADD',
      itemType: itemTypeUpper,
    );
    state = state.copyWith(items: [...state.items, newItem]);
    return true;
  }

  /// Replace an existing order item with a new service/product.
  /// [id] = the local OrderItem.id (also the original order_item_id from server for original items).
  /// [newEntityId] = the new service/product UUID.
  void replaceItem(String id, String newName, double newPrice, {String? newEntityId}) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == id) {
          return i.copyWith(
            name: newName,
            price: newPrice,
            quantity: 1,
            isRemoved: false,
            newEntityId: newEntityId,
            modificationType: 'REPLACE',
            itemType: (i.type ?? '').toUpperCase(),
          );
        }
        return i;
      }).toList(),
    );
  }

  /// Mark an existing order item as removed.
  void removeItem(String id) {
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == id) {
          return i.copyWith(
            isRemoved: true,
            quantity: 0,
            modificationType: 'REMOVE',
            itemType: (i.itemType ?? i.type ?? '').toUpperCase(),
          );
        }
        return i;
      }).toList(),
    );
  }

  void updateQuantity(String id, int qty) {
    if (qty < 0) return;
    if (qty == 0) {
      removeItem(id);
      return;
    }
    state = state.copyWith(
      items: state.items.map((i) {
        if (i.id == id) {
          final isChanged = !i.isNew && (qty != i.originalQuantity || i.price != i.originalPrice || i.newEntityId != i.originalEntityId);
          return i.copyWith(
            quantity: qty,
            isRemoved: false,
            modificationType: i.isNew
                ? 'ADD'
                : (isChanged ? 'REPLACE' : null),
          );
        }
        return i;
      }).toList(),
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
