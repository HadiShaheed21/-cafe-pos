
-- ============================================================
-- CAFE POS — Migration 001
-- Core POS Foundation
-- PostgreSQL / Neon
-- ============================================================

BEGIN;

-- 1. USERS
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    password TEXT NOT NULL,
    role TEXT NOT NULL DEFAULT 'cashier'
        CHECK (role IN ('owner', 'manager', 'cashier', 'server', 'chef')),
    pin TEXT,
    pin_hash TEXT,
    category_ids TEXT,
    is_active INTEGER DEFAULT 1,
    terms_accepted_at TEXT,
    tokens_valid_after TEXT,
    station_assignments_configured INTEGER NOT NULL DEFAULT 0,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 2. CATEGORIES
CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    image_url TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    parent_id TEXT,
    slug TEXT,
    color TEXT,
    icon TEXT,
    deleted_at TEXT,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 3. PRODUCTS
CREATE TABLE products (
    id TEXT PRIMARY KEY,
    category_id TEXT REFERENCES categories(id),
    name TEXT NOT NULL,
    description TEXT,
    price DOUBLE PRECISION NOT NULL DEFAULT 0,
    cost DOUBLE PRECISION DEFAULT 0,
    sku TEXT,
    barcode TEXT,
    sale_unit TEXT NOT NULL DEFAULT 'each'
        CHECK (sale_unit IN ('each', 'kg', 'g', 'lb')),
    allow_fractional_quantity INTEGER NOT NULL DEFAULT 0,
    weight_precision INTEGER NOT NULL DEFAULT 3
        CHECK (weight_precision BETWEEN 0 AND 4),
    image_url TEXT,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    track_inventory INTEGER DEFAULT 0,
    stock_quantity DOUBLE PRECISION DEFAULT 0,
    low_stock_threshold DOUBLE PRECISION DEFAULT 5,
    tax_type TEXT DEFAULT 'none',
    tax_rate DOUBLE PRECISION DEFAULT 0,
    tax_category_id TEXT,
    tax_behavior TEXT DEFAULT 'country_default',
    cb_percent DOUBLE PRECISION DEFAULT 0,
    tags TEXT,
    deleted_at TEXT,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    quality TEXT,
    catalog_status TEXT NOT NULL DEFAULT 'draft'
        CHECK (catalog_status IN ('draft', 'published', 'unpublished')),
    published_at TEXT,
    original_price DOUBLE PRECISION
        CHECK (original_price IS NULL OR original_price >= 0),
    variant_mode INTEGER NOT NULL DEFAULT 0
        CHECK (variant_mode IN (0, 1)),
    shop_reserved_quantity DOUBLE PRECISION NOT NULL DEFAULT 0
);

CREATE INDEX idx_products_category ON products(category_id);
CREATE INDEX idx_products_active ON products(is_active);

-- 4. ADD-ON GROUPS
CREATE TABLE addon_groups (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    is_required INTEGER DEFAULT 0,
    min_selection INTEGER DEFAULT 0,
    max_selection INTEGER DEFAULT 1,
    allow_multiple_quantities INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 5. ADD-ONS
CREATE TABLE addons (
    id TEXT PRIMARY KEY,
    addon_group_id TEXT NOT NULL REFERENCES addon_groups(id),
    name TEXT NOT NULL,
    price DOUBLE PRECISION NOT NULL DEFAULT 0,
    tax_category_id TEXT,
    tax_behavior TEXT DEFAULT 'country_default',
    inherit_parent_tax_category INTEGER DEFAULT 1,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 6. PRODUCT / ADD-ON GROUP RELATIONSHIP
CREATE TABLE addon_group_product (
    product_id TEXT NOT NULL,
    addon_group_id TEXT NOT NULL,
    PRIMARY KEY (product_id, addon_group_id)
);

-- 7. PRODUCT OPTION GROUPS
CREATE TABLE product_option_groups (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    normalized_name TEXT NOT NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    UNIQUE (product_id, normalized_name)
);

-- 8. PRODUCT OPTION VALUES
CREATE TABLE product_option_values (
    id TEXT PRIMARY KEY,
    option_group_id TEXT NOT NULL
        REFERENCES product_option_groups(id) ON DELETE CASCADE,
    label TEXT NOT NULL,
    normalized_label TEXT NOT NULL,
    color_hex TEXT,
    sort_order INTEGER NOT NULL DEFAULT 0,
    is_active INTEGER NOT NULL DEFAULT 1 CHECK (is_active IN (0, 1)),
    created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    UNIQUE (option_group_id, normalized_label)
);

-- 9. PRODUCT VARIANTS
CREATE TABLE product_variants (
    id TEXT PRIMARY KEY,
    product_id TEXT NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
    option_signature TEXT NOT NULL,
    display_name TEXT NOT NULL,
    sku TEXT,
    barcode TEXT,
    price_override DOUBLE PRECISION
        CHECK (price_override IS NULL OR price_override >= 0),
    cost_override DOUBLE PRECISION
        CHECK (cost_override IS NULL OR cost_override >= 0),
    track_inventory INTEGER NOT NULL DEFAULT 1
        CHECK (track_inventory IN (0, 1)),
    stock_quantity INTEGER NOT NULL DEFAULT 0
        CHECK (stock_quantity >= 0),
    low_stock_threshold INTEGER NOT NULL DEFAULT 0
        CHECK (low_stock_threshold >= 0),
    is_active INTEGER NOT NULL DEFAULT 1
        CHECK (is_active IN (0, 1)),
    deleted_at TEXT,
    created_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT NOT NULL DEFAULT (CURRENT_TIMESTAMP::TEXT),
    shop_reserved_quantity DOUBLE PRECISION NOT NULL DEFAULT 0,
    UNIQUE (product_id, option_signature)
);

CREATE INDEX idx_product_variants_product_active
    ON product_variants(product_id, is_active, deleted_at);

-- 10. VARIANT OPTION VALUES
CREATE TABLE product_variant_option_values (
    variant_id TEXT NOT NULL
        REFERENCES product_variants(id) ON DELETE CASCADE,
    option_group_id TEXT NOT NULL
        REFERENCES product_option_groups(id) ON DELETE RESTRICT,
    option_value_id TEXT NOT NULL
        REFERENCES product_option_values(id) ON DELETE RESTRICT,
    PRIMARY KEY (variant_id, option_group_id),
    UNIQUE (variant_id, option_value_id)
);

CREATE INDEX idx_variant_option_values_option
    ON product_variant_option_values(option_value_id);

-- 11. PRINTERS
CREATE TABLE printers (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    connection_type TEXT NOT NULL
        CHECK (connection_type IN ('network', 'usb', 'webusb')),
    ip_address TEXT,
    port INTEGER DEFAULT 9100,
    is_default INTEGER DEFAULT 0,
    cash_drawer_pulse_enabled INTEGER NOT NULL DEFAULT 0,
    paper_width TEXT DEFAULT '80mm',
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 12. KITCHEN STATIONS
CREATE TABLE kitchen_stations (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    category_ids TEXT,
    printer_id TEXT REFERENCES printers(id) ON DELETE SET NULL,
    printer_ip TEXT,
    printer_port INTEGER DEFAULT 9100,
    printer_name TEXT,
    is_active INTEGER DEFAULT 1,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

-- 13. STATION USERS
CREATE TABLE station_users (
    user_id TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    station_id TEXT NOT NULL REFERENCES kitchen_stations(id) ON DELETE CASCADE,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    PRIMARY KEY (user_id, station_id)
);

-- 14. CAFÉ TABLES
CREATE TABLE tables (
    id TEXT PRIMARY KEY,
    number TEXT NOT NULL UNIQUE,
    capacity INTEGER DEFAULT 4,
    status TEXT DEFAULT 'available',
    floor TEXT,
    section TEXT,
    position_x DOUBLE PRECISION,
    position_y DOUBLE PRECISION,
    kitchen_station_id TEXT,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT),
    updated_at TEXT DEFAULT (CURRENT_TIMESTAMP::TEXT)
);

COMMIT;
