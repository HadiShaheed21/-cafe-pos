BEGIN;

CREATE TABLE orders (
  id BIGSERIAL PRIMARY KEY,
  order_number TEXT UNIQUE NOT NULL,
  table_id TEXT,
  customer_id TEXT,
  user_id TEXT REFERENCES users(id),
  type TEXT DEFAULT 'takeaway',
  guest_count INTEGER,
  special_instructions TEXT,
  packaging_charge DOUBLE PRECISION DEFAULT 0,
  delivery_charge DOUBLE PRECISION DEFAULT 0,
  service_charge DOUBLE PRECISION DEFAULT 0,
  status TEXT DEFAULT 'pending',
  subtotal DOUBLE PRECISION DEFAULT 0,
  tax_amount DOUBLE PRECISION DEFAULT 0,
  tax_breakdown TEXT,
  tax_snapshot TEXT DEFAULT NULL,
  packaging_tax_category_id TEXT DEFAULT NULL,
  delivery_tax_category_id TEXT DEFAULT NULL,
  service_charge_tax_category_id TEXT DEFAULT NULL,
  discount_amount DOUBLE PRECISION DEFAULT 0,
  discount_type TEXT,
  discount_value DOUBLE PRECISION,
  discount_reason TEXT,
  round_off DOUBLE PRECISION DEFAULT 0,
  total DOUBLE PRECISION DEFAULT 0,
  cooking_started_at TEXT,
  ready_at TEXT,
  served_at TEXT,
  completed_at TEXT,
  cancelled_at TEXT,
  cancellation_reason TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  online_platform TEXT DEFAULT NULL,
  external_order_id TEXT DEFAULT NULL
);

CREATE TABLE order_items (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  product_sku TEXT,
  unit_price DOUBLE PRECISION NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 1,
  inventory_deducted_quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
  subtotal DOUBLE PRECISION NOT NULL,
  tax_amount DOUBLE PRECISION DEFAULT 0,
  tax_breakdown TEXT,
  tax_snapshot TEXT DEFAULT NULL,
  tax_type TEXT,
  discount_amount DOUBLE PRECISION DEFAULT 0,
  total DOUBLE PRECISION NOT NULL,
  variant_selection TEXT,
  modifier_selection TEXT,
  special_instructions TEXT,
  status TEXT DEFAULT 'pending',
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  voided_at TEXT DEFAULT NULL,
  variant_id TEXT DEFAULT NULL
);

CREATE TABLE bills (
  id BIGSERIAL PRIMARY KEY,
  bill_number TEXT UNIQUE NOT NULL,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  customer_id TEXT,
  subtotal DOUBLE PRECISION DEFAULT 0,
  tax_amount DOUBLE PRECISION DEFAULT 0,
  tax_breakdown TEXT,
  tax_snapshot TEXT DEFAULT NULL,
  discount_amount DOUBLE PRECISION DEFAULT 0,
  discount_type TEXT,
  discount_value DOUBLE PRECISION,
  discount_reason TEXT,
  delivery_charge DOUBLE PRECISION DEFAULT 0,
  packaging_charge DOUBLE PRECISION DEFAULT 0,
  service_charge DOUBLE PRECISION DEFAULT 0,
  round_off DOUBLE PRECISION DEFAULT 0,
  total DOUBLE PRECISION DEFAULT 0,
  paid_amount DOUBLE PRECISION DEFAULT 0,
  balance DOUBLE PRECISION DEFAULT 0,
  payment_status TEXT DEFAULT 'unpaid',
  payment_details TEXT,
  paid_at TEXT,
  printed_at TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  split_group_id TEXT,
  split_label TEXT
);

CREATE TABLE bill_items (
  bill_id BIGINT NOT NULL REFERENCES bills(id) ON DELETE CASCADE,
  order_item_id BIGINT NOT NULL REFERENCES order_items(id),
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  PRIMARY KEY (bill_id, order_item_id)
);

CREATE TABLE payment_methods (
  id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE UNIQUE INDEX payment_methods_name_nocase
  ON payment_methods (LOWER(name));

CREATE TABLE payment_transaction_refs (
  method TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  bill_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (method, transaction_id)
);

CREATE TABLE payment_transaction_ref_conflicts (
  method TEXT NOT NULL,
  transaction_id TEXT NOT NULL,
  bill_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  detected_at TEXT NOT NULL
);

CREATE TABLE payment_idempotency (
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  bill_id TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  response_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, idempotency_key)
);

CREATE TABLE order_idempotency (
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  response_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, idempotency_key)
);

CREATE TABLE refund_idempotency (
  user_id TEXT NOT NULL,
  idempotency_key TEXT NOT NULL,
  bill_id TEXT NOT NULL,
  request_hash TEXT NOT NULL,
  response_json TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, idempotency_key)
);

CREATE TABLE revoked_tokens (
  token_hash TEXT PRIMARY KEY,
  expires_at BIGINT NOT NULL,
  revoked_at TEXT NOT NULL
);

CREATE TABLE refunds (
  id BIGSERIAL PRIMARY KEY,
  bill_id BIGINT NOT NULL REFERENCES bills(id),
  order_item_id BIGINT REFERENCES order_items(id),
  amount_cents BIGINT NOT NULL CHECK (amount_cents > 0),
  method TEXT NOT NULL,
  reason TEXT,
  shift_id TEXT,
  approved_by TEXT NOT NULL REFERENCES users(id),
  created_by TEXT NOT NULL REFERENCES users(id),
  created_at TEXT NOT NULL
);

CREATE TABLE cash_closures (
  id BIGSERIAL PRIMARY KEY,
  scope TEXT NOT NULL DEFAULT 'day'
    CHECK (scope IN ('day', 'session')),
  business_date TEXT NOT NULL
    CHECK (business_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  period_start TEXT NOT NULL,
  period_end TEXT NOT NULL,
  opening_float_cents BIGINT NOT NULL DEFAULT 0
    CHECK (opening_float_cents >= 0),
  expected_cash_cents BIGINT NOT NULL,
  counted_cash_cents BIGINT NOT NULL
    CHECK (counted_cash_cents >= 0),
  variance_cents BIGINT NOT NULL,
  gross_collected_cents BIGINT NOT NULL,
  refunded_cents BIGINT NOT NULL,
  net_collected_cents BIGINT NOT NULL,
  bill_count INTEGER NOT NULL,
  refund_count INTEGER NOT NULL,
  payment_methods_json TEXT NOT NULL DEFAULT '[]',
  staff_sales_json TEXT NOT NULL DEFAULT '[]',
  tax_components_json TEXT NOT NULL DEFAULT '[]',
  z_number BIGINT UNIQUE NOT NULL,
  closed_by TEXT NOT NULL REFERENCES users(id),
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE INDEX orders_created_at_idx ON orders(created_at);
CREATE INDEX orders_status_idx ON orders(status);
CREATE INDEX order_items_order_id_idx ON order_items(order_id);
CREATE INDEX bills_order_id_idx ON bills(order_id);
CREATE INDEX bills_created_at_idx ON bills(created_at);
CREATE INDEX refunds_bill_id_idx ON refunds(bill_id);

COMMIT;
