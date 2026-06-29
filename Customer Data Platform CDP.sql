-- ==============================================================================
-- UNIVERSAL DATA MODEL (UDM) Compliant CDP(Customer Data Platform)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. PARTY DOMAIN
-- ------------------------------------------------------------------------------

-- Defines the allowed types of parties (e.g., PERSON, PARTY_GROUP).
-- The 'has_table' flag indicates if a specific sub-table exists (like 'person' table).

CREATE TABLE party_type (
    party_type_id VARCHAR(20) PRIMARY KEY,
    parent_type_id VARCHAR(20) COMMENT 'For hierarchical types (e.g. COMPANY is a child of PARTY_GROUP)',
    external_id VARCHAR(20),
    has_table BOOLEAN COMMENT 'True if there is an extended table for this type',
    FOREIGN KEY (parent_type_id) REFERENCES party_type(party_type_id)
);

-- The root table for all entities interacting with the system.
CREATE TABLE party (
    party_id VARCHAR(20) PRIMARY KEY,
    party_type_id VARCHAR(20) NOT NULL COMMENT 'References party_type to identify if person or group',
    status_id VARCHAR(20) COMMENT 'Tracks enabled/disabled status',
    created_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    last_modified_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (party_type_id) REFERENCES party_type(party_type_id)
);

-- Extended table for individuals. Deletes automatically if the root Party is deleted.
CREATE TABLE person (
    party_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    date_of_birth DATETIME,
    FOREIGN KEY (party_id) REFERENCES party(party_id) ON DELETE CASCADE
);

-- Extended table for organizations or groups.
CREATE TABLE party_group (
    party_id VARCHAR(20) PRIMARY KEY,
    group_name VARCHAR(100) NOT NULL COMMENT 'E.g., "Acme Corp"',
    office_site_name VARCHAR(100),
    FOREIGN KEY (party_id) REFERENCES party(party_id) ON DELETE CASCADE
);


-- ------------------------------------------------------------------------------
-- 2. CONTACT MECHANISM DOMAIN
-- ------------------------------------------------------------------------------

-- Defines allowed types of contact mechanisms (e.g. POSTAL_ADDRESS, EMAIL_ADDRESS).

CREATE TABLE contact_mech_type (
    contact_mech_type_id VARCHAR(20) PRIMARY KEY,
    parent_type_id VARCHAR(20),
    has_table BOOLEAN COMMENT 'True if an extended table like postal_address exists',
    FOREIGN KEY (parent_type_id) REFERENCES contact_mech_type(contact_mech_type_id)
);

-- The base table storing all forms of contact information.
CREATE TABLE contact_mech (
    contact_mech_id VARCHAR(20) PRIMARY KEY,
    contact_mech_type_id VARCHAR(20) NOT NULL,
    infostring VARCHAR(100) COMMENT 'Stores plain string data like Email addresses or URLs',
    FOREIGN KEY (contact_mech_type_id) REFERENCES contact_mech_type(contact_mech_type_id)
);

-- Extended table for structured physical addresses.
CREATE TABLE postal_address (
    contact_mech_id VARCHAR(20) PRIMARY KEY,
    to_name VARCHAR(100) COMMENT 'Attention or care-of name',
    address VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    postalcode VARCHAR(100) NOT NULL,
    FOREIGN KEY (contact_mech_id) REFERENCES contact_mech(contact_mech_id) ON DELETE CASCADE
);

-- Extended table for structured telephone numbers.
CREATE TABLE telecom_number (
    contact_mech_id VARCHAR(20) PRIMARY KEY,
    countrycode VARCHAR(10),
    areacode VARCHAR(10),
    contactnumber VARCHAR(20) NOT NULL,
    FOREIGN KEY (contact_mech_id) REFERENCES contact_mech(contact_mech_id) ON DELETE CASCADE
);


-- ------------------------------------------------------------------------------
-- 3. PARTY RELATIONSHIPS TO CONTACT MECHANISMS
-- ------------------------------------------------------------------------------

-- Links a party to a contact mechanism, using 'from_date' and 'thru_date' 
-- to maintain historical records of active/inactive contact info.
CREATE TABLE party_contact_mech (
    party_id VARCHAR(20),
    contact_mech_id VARCHAR(20),
    from_date DATETIME COMMENT 'When this relationship started',
    thru_date DATETIME COMMENT 'When this relationship ended (Null means active)',
    PRIMARY KEY (party_id, contact_mech_id, from_date),
    FOREIGN KEY (party_id) REFERENCES party(party_id),
    FOREIGN KEY (contact_mech_id) REFERENCES contact_mech(contact_mech_id)
);

-- Defines lookup values for *why* a contact mechanism is being used 
-- (e.g. BILLING_ADDRESS, SHIPPING_ADDRESS, PRIMARY_PHONE).
CREATE TABLE contact_mech_purpose_type (
    contact_mech_purpose_type_id VARCHAR(20) PRIMARY KEY,
    description VARCHAR(100) COMMENT 'Human readable label (e.g. "Shipping Destination")'
);

-- Assigns a purpose (e.g., Billing) to a specific Party Contact Mechanism.
-- It requires a composite foreign key to link uniquely to a specific timeframe in party_contact_mech.
CREATE TABLE party_contact_mech_purpose (
    party_id VARCHAR(20),
    contact_mech_id VARCHAR(20),
    contact_mech_purpose_type_id VARCHAR(20),
    from_date DATETIME,
    thru_date DATETIME,
    PRIMARY KEY (party_id, contact_mech_id, contact_mech_purpose_type_id, from_date),
    FOREIGN KEY (party_id, contact_mech_id, from_date) 
        REFERENCES party_contact_mech(party_id, contact_mech_id, from_date),
    FOREIGN KEY (contact_mech_purpose_type_id) 
        REFERENCES contact_mech_purpose_type(contact_mech_purpose_type_id)
);


-- ------------------------------------------------------------------------------
-- 4. CUSTOMER PREFERENCES
-- ------------------------------------------------------------------------------

-- A scalable table to store any user configuration or preferences 
-- in a Key-Value pair format.
CREATE TABLE preferences (
    party_id VARCHAR(20),
    preference_type VARCHAR(20) COMMENT 'The Key (e.g., "COMMUNICATION_PREFERENCE", "MARKETING_OPT_IN")',
    preference_value VARCHAR(20) NOT NULL COMMENT 'The Value',
    PRIMARY KEY (party_id, preference_type),
    FOREIGN KEY (party_id) REFERENCES party(party_id)
);



