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


-- Product Table
CREATE TABLE IF NOT EXISTS product (
    product_id UUID PRIMARY KEY,
    product_name VARCHAR(255) NOT NULL UNIQUE,
    product_type product_type_enum NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);


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

-- Entitlement Table
CREATE TABLE IF NOT EXISTS entitlement (
    entitlement_id UUID PRIMARY KEY, -- Removed DEFAULT gen_random_uuid()
    household_id UUID REFERENCES household(household_id) ON DELETE CASCADE,
    package_id UUID REFERENCES package(package_id) ON DELETE RESTRICT,
    entitlement_start TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status VARCHAR(50) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Add foreign key indexes
CREATE INDEX IF NOT EXISTS idx_entitlement_household_id ON entitlement (household_id);
CREATE INDEX IF NOT EXISTS idx_entitlement_package_id ON entitlement (package_id);


-- Events Table (High-Frequency)
CREATE TABLE IF NOT EXISTS events (
    event_id UUID PRIMARY KEY,
    household_id VARCHAR(20) REFERENCES household(household_id),
    device_id UUID REFERENCES device(device_id),
    event_category VARCHAR(100),
    event_type VARCHAR(100),
    content_id UUID,
    session_id UUID,
    position_start_sec INT,
    position_end_sec INT,
    session_start_time TIMESTAMP WITH TIME ZONE,
    session_end_time TIMESTAMP WITH TIME ZONE,
    session_duration_sec INT,
    session_status VARCHAR(50),
    teardown_reason VARCHAR(100),
    network_type VARCHAR(50),
    ip_address INET,
    isp_name VARCHAR(100),
    edge_cache_fqdn_start VARCHAR(255),
    edge_cache_fqdn_buffering VARCHAR(255),
    bitrate_kbps INT,
    network_bandwidth_kbps INT,
    profile_attempted VARCHAR(100),
    buffer_duration_sec INT,
    stall_count INT,
    latency_ms INT,
    app_version VARCHAR(50),
    os_name VARCHAR(50),
    os_version VARCHAR(50),
    device_category VARCHAR(50),
    purchase_id UUID REFERENCES purchase(purchase_id),
    event_start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    event_end_time TIMESTAMP WITH TIME ZONE,
    event_reported_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Index frequently queried columns for performance in analytical queries
CREATE INDEX IF NOT EXISTS idx_events_household_id_time ON events (household_id, event_start_time DESC);
CREATE INDEX IF NOT EXISTS idx_events_device_id ON events (device_id);
CREATE INDEX IF NOT EXISTS idx_events_content_id ON events (content_id);

-- ====================================================================
-- Trigger Function and Trigger for Status Synchronization/Validation
-- ====================================================================

-- Function to handle status synchronization AND validation
CREATE OR REPLACE FUNCTION sync_device_status_and_validate_deletion()
RETURNS TRIGGER AS $$
DECLARE
    active_devices_count INT;
BEGIN
    -- Check for status change
    IF NEW.status IS DISTINCT FROM OLD.status THEN

        -- --- Logic for BLOCKING/SUSPENDING devices (Household -> Device) ---
        -- If household becomes 'DELETED' or 'SUSPENDED', block/delete devices
        IF NEW.status IN ('DELETED', 'SUSPENDED') THEN
            UPDATE device
            SET status = CAST(NEW.status AS device_state_enum),
                updated_at = CURRENT_TIMESTAMP
            WHERE household_id = NEW.household_id;
        
        -- If household becomes 'ACTIVE', activate devices that were blocked/deleted due to household status
        ELSIF NEW.status = 'ACTIVE' THEN
            UPDATE device
            SET status = 'ACTIVE',
                updated_at = CURRENT_TIMESTAMP
            WHERE household_id = NEW.household_id
              AND status <> 'ACTIVE';
        END IF;

        -- --- Logic for PREVENTING HOUSEHOLD DELETE until devices are all DELETED ---
        -- This part only fires if the NEW status is 'DELETED' and we are checking validation
        IF NEW.status = 'DELETED' THEN
            SELECT COUNT(*)
            INTO active_devices_count
            FROM device
            WHERE household_id = NEW.household_id
              AND status IN ('ACTIVE', 'SUSPENDED'); -- Check for any non-deleted devices

            IF active_devices_count > 0 THEN
                -- Raise an error, preventing the household update to 'DELETED'
                RAISE EXCEPTION 'Cannot delete household_id % because % associated devices are still active or suspended.', NEW.household_id, active_devices_count;
            END IF;
        END IF;

    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger that fires BEFORE an update on the household table (to validate the deletion request)
CREATE TRIGGER trigger_sync_and_validate_household_status
BEFORE UPDATE OF status ON household
FOR EACH ROW
EXECUTE FUNCTION sync_device_status_and_validate_deletion();

-- Create a replication role for logical decoding / CDC connectors
DO $$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'replicator') THEN
        CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_pass';
    END IF;
END
$$;

-- Optional: grant CONNECT on the database to the replicator (redundant for superuser)
GRANT CONNECT ON DATABASE ott TO replicator;