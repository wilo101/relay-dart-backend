# Changelog

## 2.0.0
- Roles (`admin`, `viewer`) with salted, iterated password hashes. Viewers are read-only.
- Customers: CRUD, search, tag and city filters, lifetime value per customer.
- Orders: line items, status history, detail endpoint, bulk status update, delete, CSV export.
- Pagination (`page`, `per_page`) with `x-total-count` style headers, plus `sort` on every list.
- Filtering by status, customer, amount range and date range.
- Webhooks: subscribe by event, HMAC-signed payloads, retries with exponential backoff, delivery log, test endpoint.
- Rate limiting (fixed window, `429` plus `retry-after`), request ids, JSON error handling.
- Stats: status breakdown, top customers, top products, average order, date range.
- Focus stats with streak calculation, session tags and deletes.
- Admin audit log.
- Tests grouped by area: auth, orders, customers, webhooks, rate limiting, focus, AI proxy.

## 1.0.0
- Auth, orders, stats, focus sessions and the AI proxy.
