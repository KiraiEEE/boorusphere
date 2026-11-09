/// How search results are ordered
enum SearchSort {
  latest,
  popular,
  random;

  static SearchSort fromName(String? name) {
    return SearchSort.values.firstWhere(
      (it) => it.name == name,
      orElse: () => SearchSort.latest,
    );
  }
}
