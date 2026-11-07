BEGIN;

-- Customers and loyalty
CREATE TABLE customers (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  country_code TEXT DEFAULT '+91',
  address TEXT,
  notes TEXT,
  tag_counts TEXT DEFAULT NULL,
  is_active INTEGER DEFAULT 1,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  phone_digits TEXT GENERATED ALWAYS AS (
    CASE WHEN phone IS NULL THEN NULL
    ELSE REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
      phone, '+', ''), ' ', ''), '-', ''), '(', ''), ')', ''), '.', '')
    END
  ) STORED
);

CREATE TABLE loyalty_ledger (
  id BIGSERIAL PRIMARY KEY,
  customer_id TEXT NOT NULL,
  bill_id BIGINT,
  type TEXT NOT NULL,
  amount DOUBLE PRECISION NOT NULL,
  description TEXT,
  expires_at TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- Settings and numbering
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT,
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE sequences (
  name TEXT NOT NULL,
  date TEXT NOT NULL,
  current_value INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (name, date)
);

-- Held orders and item add-ons
CREATE TABLE held_orders (
  id TEXT PRIMARY KEY,
  table_id TEXT NOT NULL,
  items TEXT NOT NULL,
  customer_id TEXT,
  guest_count INTEGER DEFAULT 1,
  order_notes TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE order_item_addons (
  id BIGSERIAL PRIMARY KEY,
  order_item_id BIGINT NOT NULL
    REFERENCES order_items(id) ON DELETE CASCADE,
  addon_id TEXT REFERENCES addons(id) ON DELETE SET NULL,
  addon_name TEXT NOT NULL,
  price NUMERIC NOT NULL DEFAULT 0,
  quantity INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

-- Inventory and purchasing
CREATE TABLE stock_movements (
  id BIGSERIAL PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id),
  movement_type TEXT NOT NULL CHECK (
    movement_type IN (
      'opening', 'purchase', 'sale',
      'sale_cancelled', 'refund', 'adjustment'
    )
  ),
  quantity_delta DOUBLE PRECISION NOT NULL,
  quantity_before DOUBLE PRECISION NOT NULL,
  quantity_after DOUBLE PRECISION NOT NULL,
  reference_type TEXT,
  reference_id TEXT,
  reason TEXT,
  actor_user_id TEXT REFERENCES users(id),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  variant_id TEXT DEFAULT NULL
);

CREATE TABLE purchases (
  id TEXT PRIMARY KEY,
  supplier TEXT,
  reference TEXT,
  purchased_at TEXT NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id),
  total DOUBLE PRECISION NOT NULL DEFAULT 0 CHECK (total >= 0),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE purchase_items (
  id BIGSERIAL PRIMARY KEY,
  purchase_id TEXT NOT NULL REFERENCES purchases(id),
  product_id TEXT NOT NULL REFERENCES products(id),
  quantity DOUBLE PRECISION NOT NULL CHECK (quantity > 0),
  unit_cost DOUBLE PRECISION NOT NULL CHECK (unit_cost >= 0),
  total DOUBLE PRECISION NOT NULL CHECK (total >= 0),
  variant_id TEXT DEFAULT NULL
);

CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  amount DOUBLE PRECISION NOT NULL CHECK (amount > 0),
  category TEXT NOT NULL,
  description TEXT,
  expense_date TEXT NOT NULL,
  created_by TEXT NOT NULL REFERENCES users(id),
  voided_at TEXT,
  voided_by TEXT REFERENCES users(id),
  void_reason TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- Tax and country configuration
CREATE TABLE country_packs (
  id TEXT PRIMARY KEY,
  publisher TEXT NOT NULL,
  country TEXT NOT NULL,
  jurisdiction TEXT NOT NULL,
  active_version_id TEXT,
  status TEXT NOT NULL DEFAULT 'installed',
  disclaimer_acknowledged_at TEXT,
  disclaimer_acknowledged_by TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE country_pack_versions (
  id TEXT PRIMARY KEY,
  pack_id TEXT NOT NULL,
  version TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  manifest_json TEXT NOT NULL,
  pack_json TEXT NOT NULL,
  digest TEXT,
  signature TEXT,
  effective_from TEXT NOT NULL,
  effective_to TEXT,
  min_flo_version TEXT NOT NULL,
  published_at TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'staged',
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  UNIQUE (pack_id, version)
);

CREATE TABLE tax_categories (
  id TEXT PRIMARY KEY,
  pack_version_id TEXT NOT NULL,
  category_id TEXT NOT NULL,
  label TEXT NOT NULL,
  default_behavior TEXT,
  definition_json TEXT NOT NULL,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  UNIQUE (pack_version_id, category_id)
);

CREATE TABLE tax_rules (
  id TEXT PRIMARY KEY,
  pack_version_id TEXT NOT NULL,
  rule_id TEXT NOT NULL,
  label TEXT NOT NULL,
  calculation_type TEXT NOT NULL,
  rate TEXT,
  amount TEXT,
  applies_per TEXT,
  base_rule_ids TEXT,
  definition_json TEXT NOT NULL,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  UNIQUE (pack_version_id, rule_id)
);

CREATE TABLE tax_overrides (
  id TEXT PRIMARY KEY,
  pack_version_id TEXT NOT NULL,
  entity_type TEXT NOT NULL,
  entity_id TEXT,
  field_name TEXT NOT NULL,
  value_json TEXT NOT NULL,
  created_by_user_id TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE tax_config_audit (
  id BIGSERIAL PRIMARY KEY,
  action TEXT NOT NULL,
  pack_id TEXT,
  pack_version_id TEXT,
  override_id TEXT,
  actor_user_id TEXT,
  details_json TEXT,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- Printing
CREATE TABLE installed_print_templates (
  template_id TEXT PRIMARY KEY,
  pack_id TEXT NOT NULL,
  pack_version_id TEXT NOT NULL,
  country TEXT NOT NULL,
  jurisdiction TEXT NOT NULL,
  display_name TEXT NOT NULL,
  paper_widths_json TEXT NOT NULL,
  renderer_json TEXT NOT NULL,
  template_payload_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'installed',
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE merchant_print_templates (
  id TEXT PRIMARY KEY,
  business_id TEXT NOT NULL DEFAULT 'local',
  name TEXT NOT NULL,
  origin TEXT NOT NULL DEFAULT 'created'
    CHECK (origin IN ('created', 'imported', 'cloned')),
  derived_from TEXT,
  document_type TEXT NOT NULL DEFAULT 'receipt'
    CHECK (document_type IN ('receipt')),
  schema_version INTEGER NOT NULL DEFAULT 1
    CHECK (schema_version >= 1),
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'active', 'archived')),
  previous_payload_json TEXT,
  checksum TEXT NOT NULL DEFAULT '',
  created_by TEXT,
  updated_by TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE print_logs (
  id BIGSERIAL PRIMARY KEY,
  bill_id BIGINT NOT NULL REFERENCES bills(id),
  user_id TEXT NOT NULL REFERENCES users(id),
  printed_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
  print_type TEXT DEFAULT 'receipt'
);

-- KDS
CREATE TABLE kds_pairing_tokens (
  id TEXT PRIMARY KEY,
  token TEXT UNIQUE NOT NULL,
  station_id TEXT,
  expires_at TEXT NOT NULL,
  created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- Audit logs
CREATE TABLE order_audit_log (
  id BIGSERIAL PRIMARY KEY,
  order_id BIGINT NOT NULL REFERENCES orders(id),
  order_item_id BIGINT REFERENCES order_items(id),
  actor_user_id TEXT NOT NULL REFERENCES users(id),
  action TEXT NOT NULL,
  details_json TEXT,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE TABLE catalog_audit_log (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  actor_user_id TEXT REFERENCES users(id) ON DELETE SET NULL,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- Product images and catalog identifiers
CREATE TABLE product_images (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  data_uri TEXT DEFAULT NULL,
  uses_legacy_image INTEGER NOT NULL DEFAULT 0
    CHECK (uses_legacy_image IN (0, 1)),
  mime_type TEXT DEFAULT NULL,
  byte_size INTEGER DEFAULT NULL,
  width INTEGER DEFAULT NULL,
  height INTEGER DEFAULT NULL,
  alt_text TEXT DEFAULT NULL,
  sort_order INTEGER NOT NULL DEFAULT 0,
  is_primary INTEGER NOT NULL DEFAULT 0
    CHECK (is_primary IN (0, 1)),
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  CHECK (
    (uses_legacy_image = 1 AND data_uri IS NULL)
    OR (uses_legacy_image = 0 AND data_uri IS NOT NULL)
  )
);

CREATE TABLE catalog_identifier_assignments (
  id TEXT PRIMARY KEY,
  identifier_type TEXT NOT NULL
    CHECK (identifier_type IN ('sku', 'barcode')),
  normalized_value TEXT NOT NULL,
  owner_kind TEXT NOT NULL
    CHECK (owner_kind IN ('product', 'variant')),
  product_id TEXT REFERENCES products(id) ON DELETE RESTRICT,
  variant_id TEXT REFERENCES product_variants(id) ON DELETE RESTRICT,
  assigned_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  assigned_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  released_at TEXT DEFAULT NULL,
  released_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  release_reason TEXT DEFAULT NULL,
  CHECK (
    (owner_kind = 'product' AND product_id IS NOT NULL AND variant_id IS NULL)
    OR
    (owner_kind = 'variant' AND variant_id IS NOT NULL AND product_id IS NULL)
  )
);

CREATE UNIQUE INDEX catalog_identifier_active_unique
  ON catalog_identifier_assignments(identifier_type, LOWER(normalized_value))
  WHERE released_at IS NULL;

-- Collections
CREATE TABLE collections (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  slug TEXT NOT NULL,
  description TEXT DEFAULT NULL,
  is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

CREATE UNIQUE INDEX collections_slug_nocase
  ON collections(LOWER(slug));

CREATE TABLE collection_products (
  collection_id TEXT NOT NULL REFERENCES collections(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
  PRIMARY KEY (collection_id, product_id)
);

-- Useful operational indexes
CREATE INDEX stock_movements_product_idx ON stock_movements(product_id);
CREATE INDEX stock_movements_created_at_idx ON stock_movements(created_at);
CREATE INDEX purchase_items_purchase_idx ON purchase_items(purchase_id);
CREATE INDEX expenses_date_idx ON expenses(expense_date);
CREATE INDEX order_audit_order_idx ON order_audit_log(order_id);
CREATE INDEX print_logs_bill_idx ON print_logs(bill_id);
CREATE INDEX product_images_product_idx ON product_images(product_id);

COMMIT;
