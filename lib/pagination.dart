/// Offset pagination with sane limits, plus a tiny sort helper.
class Page<T> {
  Page(this.items, this.total, this.page, this.perPage);
  final List<T> items;
  final int total;
  final int page;
  final int perPage;

  int get pages => total == 0 ? 1 : (total + perPage - 1) ~/ perPage;

  Map<String, String> get headers => {
        'x-total-count': '$total',
        'x-page': '$page',
        'x-per-page': '$perPage',
        'x-total-pages': '$pages',
      };
}

class PageParams {
  PageParams(this.page, this.perPage);
  final int page;
  final int perPage;

  static const maxPerPage = 100;

  factory PageParams.parse(Map<String, String> q) {
    final p = int.tryParse(q['page'] ?? '') ?? 1;
    final n = int.tryParse(q['per_page'] ?? q['limit'] ?? '') ?? 20;
    return PageParams(p < 1 ? 1 : p, n.clamp(1, maxPerPage));
  }
}

Page<T> paginate<T>(List<T> all, PageParams p) {
  final start = (p.page - 1) * p.perPage;
  final slice = start >= all.length ? <T>[] : all.sublist(start, (start + p.perPage).clamp(0, all.length));
  return Page(slice, all.length, p.page, p.perPage);
}

/// Parses `?sort=amount` or `?sort=-date` into (field, descending).
(String, bool) parseSort(String? raw, {required String fallback, required Set<String> allowed}) {
  var s = (raw == null || raw.isEmpty) ? fallback : raw;
  var desc = false;
  if (s.startsWith('-')) {
    desc = true;
    s = s.substring(1);
  }
  if (!allowed.contains(s)) {
    s = fallback.replaceFirst('-', '');
    desc = fallback.startsWith('-');
  }
  return (s, desc);
}
