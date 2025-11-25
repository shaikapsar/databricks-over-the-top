CREATE TYPE community_enum AS ENUM ('TEST', 'LIVE');
CREATE TYPE household_state_enum AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');
CREATE TYPE device_state_enum AS ENUM ('ACTIVE', 'SUSPENDED', 'DELETED');
CREATE TYPE coupon_state_enum AS ENUM ('ACTIVE', 'USED', 'EXPIRED');
CREATE TYPE purchase_state_enum AS ENUM ('SUCCESSFUL', 'FAILED', 'EXPIRED');
CREATE TYPE product_type_enum AS ENUM ('SVOD', 'Linear', 'TVOD');
CREATE TYPE billing_cycle_enum AS ENUM ('DAILY', 'WEEKLY', 'MONTHLY');
CREATE TYPE currency_enum AS ENUM ('AED');

-- Household Table
CREATE TABLE IF NOT EXISTS household (
    household_id VARCHAR(20) PRIMARY KEY,
    business_unit VARCHAR(20),
    community community_enum NOT NULL DEFAULT 'LIVE',
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    dob DATE,
    nationality VARCHAR(50),
    email VARCHAR(255) UNIQUE,
    mobile VARCHAR(20) UNIQUE,
    email_verified BOOLEAN DEFAULT FALSE,
    mobile_verified BOOLEAN DEFAULT FALSE,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    status household_state_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add useful indexes to household table
CREATE INDEX IF NOT EXISTS idx_household_email ON household (email);
CREATE INDEX IF NOT EXISTS idx_household_mobile ON household (mobile);

-- Set up full replica identity for Debezium
ALTER TABLE household REPLICA IDENTITY FULL;


-- Device Table: Changed ON DELETE action to RESTRICT
CREATE TABLE IF NOT EXISTS device (
    device_id UUID PRIMARY KEY,
    household_id VARCHAR(20) REFERENCES household(household_id) ON DELETE RESTRICT,
    device_name VARCHAR(100),
    device_manufacturer VARCHAR(100),
    device_model VARCHAR(100),
    os_name VARCHAR(50),
    os_version VARCHAR(50),
    device_category VARCHAR(50),
    application_version VARCHAR(50),
    status device_state_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key index for household_id
CREATE INDEX IF NOT EXISTS idx_device_household_id ON device (household_id);

-- Set up full replica identity for Debezium
ALTER TABLE device REPLICA IDENTITY FULL;


-- Product Table
CREATE TABLE IF NOT EXISTS product (
    product_id UUID PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL UNIQUE,
    product_type product_type_enum NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Set up full replica identity for Debezium
ALTER TABLE product REPLICA IDENTITY FULL;


-- Package Table
CREATE TABLE IF NOT EXISTS package (
    package_id UUID PRIMARY KEY,
    product_id UUID REFERENCES product(product_id) ON DELETE RESTRICT,
    package_name VARCHAR(255) NOT NULL UNIQUE,
    billing_cycle billing_cycle_enum NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    currency currency_enum NOT NULL DEFAULT 'AED',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key index for product_id
CREATE INDEX IF NOT EXISTS idx_package_product_id ON package (product_id);

-- Set up full replica identity for Debezium
ALTER TABLE package REPLICA IDENTITY FULL;


-- Content Table
CREATE TABLE IF NOT EXISTS content (
    content_id UUID PRIMARY KEY,
    title VARCHAR(255) NOT NULL UNIQUE,
    content_type product_type_enum NOT NULL,
    genre VARCHAR(100),
    language VARCHAR(50),
    duration_sec INT, -- Use INT for seconds
    release_date DATE,
    region_restriction TEXT,
    drm_protected BOOLEAN DEFAULT FALSE,
    available_from DATE,
    available_to DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- Set up full replica identity for Debezium
ALTER TABLE content REPLICA IDENTITY FULL;

-- Package_Content Map Table
CREATE TABLE IF NOT EXISTS package_contents (
    package_id UUID REFERENCES package(package_id) ON DELETE CASCADE,
    content_id UUID REFERENCES content(content_id) ON DELETE CASCADE,
    available_from DATE,
    available_to DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(package_id, content_id)
);

-- Set up full replica identity for Debezium
ALTER TABLE package_contents REPLICA IDENTITY FULL;

-- Coupon Table (defined before Purchase so it can be referenced)
CREATE TABLE IF NOT EXISTS coupon (
    coupon_id VARCHAR(8) PRIMARY KEY,
    coupon_name VARCHAR(25) NOT NULL,
    coupon_batch VARCHAR(25),
    discount_amount NUMERIC(10, 2) NOT NULL,
    currency currency_enum NOT NULL DEFAULT 'AED',
    valid_from TIMESTAMP WITH TIME ZONE,
    valid_to TIMESTAMP WITH TIME ZONE,
    status coupon_state_enum NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Set up full replica identity for Debezium
ALTER TABLE coupon REPLICA IDENTITY FULL;

-- Purchase Table
CREATE TABLE IF NOT EXISTS purchase (
    purchase_id UUID PRIMARY KEY,
    household_id VARCHAR(20) REFERENCES household(household_id) ON DELETE CASCADE,
    package_id UUID REFERENCES package(package_id) ON DELETE RESTRICT,
    purchase_date TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    price NUMERIC(10, 2) NOT NULL,
    currency VARCHAR(3) NOT NULL,
    payment_method VARCHAR(100),
    status VARCHAR(50) NOT NULL,
    coupon_id VARCHAR(8) REFERENCES coupon(coupon_id) ON DELETE SET NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key indexes
CREATE INDEX IF NOT EXISTS idx_purchase_household_id ON purchase (household_id);
CREATE INDEX IF NOT EXISTS idx_purchase_package_id ON purchase (package_id);

-- Set up full replica identity for Debezium
ALTER TABLE purchase REPLICA IDENTITY FULL;

-- Subscription Table
CREATE TABLE IF NOT EXISTS subscription (
    subscription_id UUID PRIMARY KEY,
    household_id VARCHAR(20) REFERENCES household(household_id) ON DELETE RESTRICT,
    package_id UUID REFERENCES package(package_id) ON DELETE RESTRICT,
    status VARCHAR(50) NOT NULL,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE,
    auto_renew BOOLEAN DEFAULT TRUE,
    payment_method VARCHAR(100),
    last_payment_date DATE,
    next_billing_date DATE,
    trial BOOLEAN DEFAULT FALSE,
    trial_end_date DATE,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key indexes
CREATE INDEX IF NOT EXISTS idx_subscription_household_id ON subscription (household_id);
CREATE INDEX IF NOT EXISTS idx_subscription_package_id ON subscription (package_id);

-- Set up full replica identity for Debezium
ALTER TABLE subscription REPLICA IDENTITY FULL;
