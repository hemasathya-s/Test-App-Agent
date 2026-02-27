import 'package:flutter_riverpod/legacy.dart';

class OrderItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final bool isNew;
  final bool isRemoved;

  const OrderItem({
    required this.id,
    required this.name,
    required this.price,
    this.quantity = 1,
    this.isNew = false,
    this.isRemoved = false,
  });

  OrderItem copyWith({String? name, double? price, int? quantity, bool? isRemoved}) {
    return OrderItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      isNew: isNew,
      isRemoved: isRemoved ?? this.isRemoved,
    );
  }
}

class OrderModificationState {
  final List<OrderItem> items;
  final String? note;
  final bool isWaitingForApproval;

  const OrderModificationState({
    this.items = const [],
    this.note,
    this.isWaitingForApproval = false,
  });

  OrderModificationState copyWith({
    List<OrderItem>? items,
    String? note,
    bool? isWaitingForApproval,
  }) {
    return OrderModificationState(
      items: items ?? this.items,
      note: note ?? this.note,
      isWaitingForApproval: isWaitingForApproval ?? this.isWaitingForApproval,
    );
  }

  double get originalTotal => items
      .where((i) => !i.isNew)
      .fold(0, (sum, i) => sum + (i.price * i.quantity));
  double get newTotal => items
      .where((i) => !i.isRemoved)
      .fold(0, (sum, i) => sum + (i.price * i.quantity));
}

class OrderModificationController
    extends StateNotifier<OrderModificationState> {
  OrderModificationController()
    : super(
        const OrderModificationState(
          items: [
            OrderItem(id: '1', name: 'Premium Cleaning', price: 50.0),
            OrderItem(id: '2', name: 'Extra Supplies Kit', price: 12.0),
          ],
        ),
      );

  void addItem(String name, double price) {
    final newItem = OrderItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      price: price,
      isNew: true,
      quantity: 1,
    );
    state = state.copyWith(items: [...state.items, newItem]);
  }

  void replaceItem(String id, String newName, double newPrice) {
    state = state.copyWith(
      items: state.items
          .map((i) => i.id == id ? i.copyWith(name: newName, price: newPrice, quantity: 1, isRemoved: false) : i)
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

  void requestApproval() {
    state = state.copyWith(isWaitingForApproval: true);
  }
}

final orderModificationProvider =
    StateNotifierProvider<OrderModificationController, OrderModificationState>((
      ref,
    ) {
      return OrderModificationController();
    });
