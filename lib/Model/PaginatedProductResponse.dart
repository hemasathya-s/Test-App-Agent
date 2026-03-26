class PaginatedProductResponse {
  final List<Map<String, dynamic>> products;
  final int total;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  PaginatedProductResponse({
    required this.products,
    required this.total,
    required this.totalPages,
    required this.currentPage,
    required this.hasMore,
  });
}
