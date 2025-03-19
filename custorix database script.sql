-- Enhanced Custorix CRM Database Schema
-- Improvements include:
-- 1. Additional tables for comprehensive CRM functionality
-- 2. Enhanced security and audit capabilities
-- 3. Support for email automation and notifications
-- 4. Improved data extraction and reporting
-- 5. Enhanced user roles and privileges system
-- 6. Support for all required business areas (CRM, ARM, Accounting, etc.)

-- Enable UUID extension for unique identifiers
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" SCHEMA public;

-- Enable pgcrypto for secure password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Create the custorix schema
CREATE SCHEMA IF NOT EXISTS custorix;

-- Set the search path to include both public and custorix schemas
SET search_path TO custorix, public;

-- Begin transaction
BEGIN;

-- =============================================
-- SECURITY AND USER MANAGEMENT TABLES
-- =============================================

-- Table: Roles (Enhanced with permissions)
CREATE TABLE custorix.roles (
    role_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_system_role BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Permissions
CREATE TABLE custorix.permissions (
    permission_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    permission_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    resource_type VARCHAR(50) NOT NULL,
    action_type VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Role Permissions (Many-to-Many)
CREATE TABLE custorix.role_permissions (
    role_id UUID REFERENCES custorix.roles(role_id) ON DELETE CASCADE,
    permission_id UUID REFERENCES custorix.permissions(permission_id) ON DELETE CASCADE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (role_id, permission_id)
);

-- Table: Departments (Enhanced)
CREATE TABLE custorix.departments (
    department_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    parent_department_id UUID REFERENCES custorix.departments(department_id) ON DELETE SET NULL,
    manager_id UUID, -- Will reference users table (forward reference)
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Users (Employees/Admins) (Enhanced)
CREATE TABLE custorix.users (
    user_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id UUID REFERENCES custorix.roles(role_id) ON DELETE SET NULL,
    department_id UUID REFERENCES custorix.departments(department_id) ON DELETE SET NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    phone VARCHAR(20),
    job_title VARCHAR(100),
    profile_image_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    is_email_verified BOOLEAN DEFAULT FALSE,
    last_login_at TIMESTAMP,
    password_reset_token VARCHAR(255),
    password_reset_expires TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Add the forward reference for department manager
ALTER TABLE custorix.departments 
ADD CONSTRAINT fk_department_manager 
FOREIGN KEY (manager_id) REFERENCES custorix.users(user_id) ON DELETE SET NULL;

-- Table: User Permissions (Direct permissions override)
CREATE TABLE custorix.user_permissions (
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    permission_id UUID REFERENCES custorix.permissions(permission_id) ON DELETE CASCADE,
    is_granted BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, permission_id)
);

-- Table: Teams
CREATE TABLE custorix.teams (
    team_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    team_name VARCHAR(100) NOT NULL,
    description TEXT,
    team_leader_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Team Members
CREATE TABLE custorix.team_members (
    team_id UUID REFERENCES custorix.teams(team_id) ON DELETE CASCADE,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (team_id, user_id)
);

-- Table: Authentication Tokens
CREATE TABLE custorix.tokens (
    token_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    token_type VARCHAR(50) DEFAULT 'access' CHECK (token_type IN ('access', 'refresh', 'api')),
    device_info JSONB,
    ip_address VARCHAR(45),
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Login History
CREATE TABLE custorix.login_history (
    login_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    ip_address VARCHAR(45),
    user_agent TEXT,
    device_info JSONB,
    login_status VARCHAR(20) CHECK (login_status IN ('success', 'failed')),
    failure_reason VARCHAR(100),
    login_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- LOCATION AND CONTACT INFORMATION TABLES
-- =============================================

-- Table: Countries
CREATE TABLE custorix.countries (
    country_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL UNIQUE,
    country_code VARCHAR(3) NOT NULL UNIQUE,
    phone_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: States/Provinces
CREATE TABLE custorix.states (
    state_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    country_id UUID REFERENCES custorix.countries(country_id) ON DELETE CASCADE,
    state_name VARCHAR(100) NOT NULL,
    state_code VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (country_id, state_name)
);

-- Table: Cities
CREATE TABLE custorix.cities (
    city_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    state_id UUID REFERENCES custorix.states(state_id) ON DELETE CASCADE,
    city_name VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (state_id, city_name, postal_code)
);

-- Table: Locations (Enhanced)
CREATE TABLE custorix.locations (
    location_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    address_line1 VARCHAR(255) NOT NULL,
    address_line2 VARCHAR(255),
    city_id UUID REFERENCES custorix.cities(city_id) ON DELETE SET NULL,
    state_id UUID REFERENCES custorix.states(state_id) ON DELETE SET NULL,
    country_id UUID REFERENCES custorix.countries(country_id) ON DELETE SET NULL,
    postal_code VARCHAR(20),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    is_primary BOOLEAN DEFAULT FALSE,
    location_type VARCHAR(50) DEFAULT 'business' CHECK (location_type IN ('business', 'shipping', 'billing', 'home', 'other')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- CUSTOMER RELATIONSHIP MANAGEMENT TABLES
-- =============================================

-- Table: Industries
CREATE TABLE custorix.industries (
    industry_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    industry_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Account Types
CREATE TABLE custorix.account_types (
    account_type_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Account Categories
CREATE TABLE custorix.account_categories (
    category_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Accounts (Customers/Organizations) (Enhanced)
CREATE TABLE custorix.accounts (
    account_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    account_type_id UUID REFERENCES custorix.account_types(account_type_id) ON DELETE SET NULL,
    category_id UUID REFERENCES custorix.account_categories(category_id) ON DELETE SET NULL,
    industry_id UUID REFERENCES custorix.industries(industry_id) ON DELETE SET NULL,
    parent_account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    website VARCHAR(255),
    phone VARCHAR(20),
    email VARCHAR(100),
    logo_url VARCHAR(255),
    tax_id VARCHAR(50),
    annual_revenue NUMERIC(15, 2),
    employee_count INTEGER,
    founded_year INTEGER,
    description TEXT,
    primary_location_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    billing_location_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    shipping_location_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    account_owner_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'prospect' CHECK (status IN ('prospect', 'lead', 'customer', 'partner', 'vendor', 'competitor', 'other', 'inactive')),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    source VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Account Locations (Many-to-Many)
CREATE TABLE custorix.account_locations (
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    location_id UUID REFERENCES custorix.locations(location_id) ON DELETE CASCADE,
    location_type VARCHAR(50) DEFAULT 'business' CHECK (location_type IN ('business', 'shipping', 'billing', 'other')),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_id, location_id)
);

-- Table: Contact Titles
CREATE TABLE custorix.contact_titles (
    title_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    title_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Contacts (Individual Customer Contacts) (Enhanced)
CREATE TABLE custorix.contacts (
    contact_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    title_id UUID REFERENCES custorix.contact_titles(title_id) ON DELETE SET NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    job_title VARCHAR(100),
    department VARCHAR(100),
    reports_to_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    date_of_birth DATE,
    linkedin_url VARCHAR(255),
    twitter_handle VARCHAR(100),
    profile_image_url VARCHAR(255),
    is_primary BOOLEAN DEFAULT FALSE,
    is_decision_maker BOOLEAN DEFAULT FALSE,
    contact_owner_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_contact_email CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Table: Contact Locations (Many-to-Many)
CREATE TABLE custorix.contact_locations (
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    location_id UUID REFERENCES custorix.locations(location_id) ON DELETE CASCADE,
    location_type VARCHAR(50) DEFAULT 'business' CHECK (location_type IN ('business', 'home', 'other')),
    is_primary BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (contact_id, location_id)
);

-- Table: Contact Preferences
CREATE TABLE custorix.contact_preferences (
    preference_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    email_opt_in BOOLEAN DEFAULT TRUE,
    sms_opt_in BOOLEAN DEFAULT TRUE,
    phone_opt_in BOOLEAN DEFAULT TRUE,
    mail_opt_in BOOLEAN DEFAULT TRUE,
    preferred_contact_method VARCHAR(50) DEFAULT 'email' CHECK (preferred_contact_method IN ('email', 'phone', 'sms', 'mail')),
    preferred_language VARCHAR(50) DEFAULT 'English',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- LEAD MANAGEMENT TABLES
-- =============================================

-- Table: Lead Sources
CREATE TABLE custorix.lead_sources (
    source_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Lead Statuses
CREATE TABLE custorix.lead_statuses (
    status_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_default BOOLEAN DEFAULT FALSE,
    is_converted BOOLEAN DEFAULT FALSE,
    is_closed BOOLEAN DEFAULT FALSE,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Leads (Potential Customers) (Enhanced)
CREATE TABLE custorix.leads (
    lead_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    mobile VARCHAR(20),
    company_name VARCHAR(100),
    job_title VARCHAR(100),
    industry_id UUID REFERENCES custorix.industries(industry_id) ON DELETE SET NULL,
    website VARCHAR(255),
    employee_count INTEGER,
    annual_revenue NUMERIC(15, 2),
    location_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    source_id UUID REFERENCES custorix.lead_sources(source_id) ON DELETE SET NULL,
    status_id UUID REFERENCES custorix.lead_statuses(status_id) ON DELETE SET NULL,
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    estimated_value NUMERIC(15, 2),
    notes TEXT,
    assigned_to_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    assigned_team_id UUID REFERENCES custorix.teams(team_id) ON DELETE SET NULL,
    is_qualified BOOLEAN DEFAULT FALSE,
    converted_account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    converted_contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    converted_opportunity_id UUID, -- Will reference opportunities table
    converted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_lead_email CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Table: Lead Scoring Rules
CREATE TABLE custorix.lead_scoring_rules (
    rule_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    description TEXT,
    field_name VARCHAR(100) NOT NULL,
    operator VARCHAR(50) NOT NULL CHECK (operator IN ('equals', 'not_equals', 'contains', 'not_contains', 'greater_than', 'less_than', 'between')),
    value TEXT NOT NULL,
    score_value INTEGER NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Lead Scores
CREATE TABLE custorix.lead_scores (
    score_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    lead_id UUID REFERENCES custorix.leads(lead_id) ON DELETE CASCADE,
    total_score INTEGER NOT NULL DEFAULT 0,
    score_details JSONB,
    calculated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- SALES MANAGEMENT TABLES
-- =============================================

-- Table: Sales Stages
CREATE TABLE custorix.sales_stages (
    stage_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    stage_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    probability NUMERIC(5, 2) CHECK (probability BETWEEN 0 AND 100),
    display_order INTEGER,
    is_won BOOLEAN DEFAULT FALSE,
    is_lost BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Opportunity Types
CREATE TABLE custorix.opportunity_types (
    type_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Sales Pipeline (Deals/Opportunities) (Enhanced)
CREATE TABLE custorix.opportunities (
    opportunity_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    opportunity_name VARCHAR(100) NOT NULL,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    primary_contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    type_id UUID REFERENCES custorix.opportunity_types(type_id) ON DELETE SET NULL,
    source_id UUID REFERENCES custorix.lead_sources(source_id) ON DELETE SET NULL,
    stage_id UUID REFERENCES custorix.sales_stages(stage_id) ON DELETE SET NULL,
    amount NUMERIC(15, 2),
    expected_revenue NUMERIC(15, 2),
    probability NUMERIC(5, 2) CHECK (probability BETWEEN 0 AND 100),
    forecast_category VARCHAR(50) CHECK (forecast_category IN ('pipeline', 'best_case', 'commit', 'closed')),
    close_date DATE,
    next_step VARCHAR(255),
    competition TEXT,
    description TEXT,
    assigned_to_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    assigned_team_id UUID REFERENCES custorix.teams(team_id) ON DELETE SET NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    is_won BOOLEAN DEFAULT FALSE,
    closed_at TIMESTAMP,
    lost_reason TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add the forward reference for converted opportunity
ALTER TABLE custorix.leads 
ADD CONSTRAINT fk_converted_opportunity 
FOREIGN KEY (converted_opportunity_id) REFERENCES custorix.opportunities(opportunity_id) ON DELETE SET NULL;

-- Table: Opportunity Contacts (Many-to-Many)
CREATE TABLE custorix.opportunity_contacts (
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    role VARCHAR(100),
    is_decision_maker BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (opportunity_id, contact_id)
);

-- Table: Opportunity Products (Many-to-Many)
CREATE TABLE custorix.opportunity_products (
    opportunity_product_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE CASCADE,
    product_id UUID, -- Will reference products table
    quantity INTEGER NOT NULL DEFAULT 1,
    unit_price NUMERIC(15, 2) NOT NULL,
    discount_percentage NUMERIC(5, 2) DEFAULT 0,
    total_price NUMERIC(15, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Sales Forecasts
CREATE TABLE custorix.sales_forecasts (
    forecast_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    forecast_amount NUMERIC(15, 2) NOT NULL,
    actual_amount NUMERIC(15, 2),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Sales Quotas
CREATE TABLE custorix.sales_quotas (
    quota_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    team_id UUID REFERENCES custorix.teams(team_id) ON DELETE CASCADE,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    quota_amount NUMERIC(15, 2) NOT NULL,
    achieved_amount NUMERIC(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (user_id IS NOT NULL OR team_id IS NOT NULL)
);

-- =============================================
-- PRODUCT AND PRICING TABLES
-- =============================================

-- Table: Product Categories
CREATE TABLE custorix.product_categories (
    category_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    parent_category_id UUID REFERENCES custorix.product_categories(category_id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Products
CREATE TABLE custorix.products (
    product_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    product_code VARCHAR(50) UNIQUE,
    category_id UUID REFERENCES custorix.product_categories(category_id) ON DELETE SET NULL,
    description TEXT,
    standard_price NUMERIC(15, 2) NOT NULL,
    list_price NUMERIC(15, 2) NOT NULL,
    cost_price NUMERIC(15, 2),
    tax_rate NUMERIC(5, 2) DEFAULT 0,
    unit_of_measure VARCHAR(50),
    image_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    inventory_count INTEGER,
    reorder_level INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add the forward reference for opportunity products
ALTER TABLE custorix.opportunity_products 
ADD CONSTRAINT fk_opportunity_product 
FOREIGN KEY (product_id) REFERENCES custorix.products(product_id) ON DELETE CASCADE;

-- Table: Price Books
CREATE TABLE custorix.price_books (
    price_book_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    price_book_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    is_standard BOOLEAN DEFAULT FALSE,
    currency_code VARCHAR(3) DEFAULT 'USD',
    start_date DATE,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Price Book Entries
CREATE TABLE custorix.price_book_entries (
    entry_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    price_book_id UUID REFERENCES custorix.price_books(price_book_id) ON DELETE CASCADE,
    product_id UUID REFERENCES custorix.products(product_id) ON DELETE CASCADE,
    list_price NUMERIC(15, 2) NOT NULL,
    discount_percentage NUMERIC(5, 2) DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (price_book_id, product_id)
);

-- =============================================
-- MARKETING TABLES
-- =============================================

-- Table: Campaign Types
CREATE TABLE custorix.campaign_types (
    type_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Campaign Statuses
CREATE TABLE custorix.campaign_statuses (
    status_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Marketing Campaigns (Enhanced)
CREATE TABLE custorix.campaigns (
    campaign_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL,
    type_id UUID REFERENCES custorix.campaign_types(type_id) ON DELETE SET NULL,
    status_id UUID REFERENCES custorix.campaign_statuses(status_id) ON DELETE SET NULL,
    parent_campaign_id UUID REFERENCES custorix.campaigns(campaign_id) ON DELETE SET NULL,
    start_date DATE,
    end_date DATE,
    expected_revenue NUMERIC(15, 2),
    budgeted_cost NUMERIC(15, 2),
    actual_cost NUMERIC(15, 2),
    expected_response NUMERIC(5, 2),
    description TEXT,
    owner_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Campaign Members
CREATE TABLE custorix.campaign_members (
    member_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    campaign_id UUID REFERENCES custorix.campaigns(campaign_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    lead_id UUID REFERENCES custorix.leads(lead_id) ON DELETE CASCADE,
    status VARCHAR(50) DEFAULT 'sent' CHECK (status IN ('planned', 'sent', 'responded', 'converted', 'bounced')),
    response_date TIMESTAMP,
    response_channel VARCHAR(50),
    response_details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (contact_id IS NOT NULL OR lead_id IS NOT NULL)
);

-- Table: Email Templates
CREATE TABLE custorix.email_templates (
    template_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    template_name VARCHAR(100) NOT NULL,
    subject VARCHAR(255) NOT NULL,
    body_html TEXT,
    body_text TEXT,
    category VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Email Campaigns
CREATE TABLE custorix.email_campaigns (
    email_campaign_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    campaign_id UUID REFERENCES custorix.campaigns(campaign_id) ON DELETE CASCADE,
    template_id UUID REFERENCES custorix.email_templates(template_id) ON DELETE SET NULL,
    sender_email VARCHAR(100) NOT NULL,
    sender_name VARCHAR(100),
    subject VARCHAR(255),
    scheduled_at TIMESTAMP,
    sent_at TIMESTAMP,
    total_recipients INTEGER DEFAULT 0,
    opened_count INTEGER DEFAULT 0,
    clicked_count INTEGER DEFAULT 0,
    bounced_count INTEGER DEFAULT 0,
    unsubscribed_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Email Tracking
CREATE TABLE custorix.email_tracking (
    tracking_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    email_campaign_id UUID REFERENCES custorix.email_campaigns(email_campaign_id) ON DELETE CASCADE,
    recipient_email VARCHAR(100) NOT NULL,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    lead_id UUID REFERENCES custorix.leads(lead_id) ON DELETE SET NULL,
    sent_at TIMESTAMP,
    opened_at TIMESTAMP,
    clicked_at TIMESTAMP,
    bounce_type VARCHAR(50),
    bounce_reason TEXT,
    unsubscribed_at TIMESTAMP,
    tracking_data JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Marketing Assets
CREATE TABLE custorix.marketing_assets (
    asset_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    asset_name VARCHAR(100) NOT NULL,
    asset_type VARCHAR(50) CHECK (asset_type IN ('whitepaper', 'ebook', 'webinar', 'infographic', 'video', 'case_study', 'other')),
    description TEXT,
    file_url VARCHAR(255),
    thumbnail_url VARCHAR(255),
    download_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Landing Pages
CREATE TABLE custorix.landing_pages (
    page_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    page_name VARCHAR(100) NOT NULL,
    page_url VARCHAR(255) NOT NULL,
    campaign_id UUID REFERENCES custorix.campaigns(campaign_id) ON DELETE SET NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    visit_count INTEGER DEFAULT 0,
    conversion_count INTEGER DEFAULT 0,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- CUSTOMER SUPPORT TABLES
-- =============================================

-- Table: Ticket Categories
CREATE TABLE custorix.ticket_categories (
    category_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id UUID REFERENCES custorix.ticket_categories(category_id) ON DELETE SET NULL,
    sla_hours INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Ticket Priorities
CREATE TABLE custorix.ticket_priorities (
    priority_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    priority_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    sla_hours INTEGER,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Ticket Statuses
CREATE TABLE custorix.ticket_statuses (
    status_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    status_name VARCHAR(50) NOT NULL UNIQUE,
    description TEXT,
    is_closed BOOLEAN DEFAULT FALSE,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Support Tickets (Enhanced)
CREATE TABLE custorix.support_tickets (
    ticket_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    ticket_number VARCHAR(50) UNIQUE NOT NULL,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    category_id UUID REFERENCES custorix.ticket_categories(category_id) ON DELETE SET NULL,
    priority_id UUID REFERENCES custorix.ticket_priorities(priority_id) ON DELETE SET NULL,
    status_id UUID REFERENCES custorix.ticket_statuses(status_id) ON DELETE SET NULL,
    subject VARCHAR(200) NOT NULL,
    description TEXT,
    source VARCHAR(50) CHECK (source IN ('email', 'phone', 'web', 'chat', 'social', 'other')),
    assigned_to_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    assigned_team_id UUID REFERENCES custorix.teams(team_id) ON DELETE SET NULL,
    due_date TIMESTAMP,
    sla_violation BOOLEAN DEFAULT FALSE,
    first_response_at TIMESTAMP,
    resolved_at TIMESTAMP,
    closed_at TIMESTAMP,
    resolution TEXT,
    satisfaction_rating INTEGER CHECK (satisfaction_rating BETWEEN 1 AND 5),
    feedback TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Ticket Comments
CREATE TABLE custorix.ticket_comments (
    comment_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    ticket_id UUID REFERENCES custorix.support_tickets(ticket_id) ON DELETE CASCADE,
    comment_text TEXT NOT NULL,
    is_private BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Ticket Attachments
CREATE TABLE custorix.ticket_attachments (
    attachment_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    ticket_id UUID REFERENCES custorix.support_tickets(ticket_id) ON DELETE CASCADE,
    comment_id UUID REFERENCES custorix.ticket_comments(comment_id) ON DELETE CASCADE,
    file_name VARCHAR(255) NOT NULL,
    file_size INTEGER NOT NULL,
    file_type VARCHAR(100),
    file_url VARCHAR(255) NOT NULL,
    uploaded_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Knowledge Base Categories
CREATE TABLE custorix.kb_categories (
    category_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    parent_category_id UUID REFERENCES custorix.kb_categories(category_id) ON DELETE SET NULL,
    display_order INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Knowledge Base Articles
CREATE TABLE custorix.kb_articles (
    article_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category_id UUID REFERENCES custorix.kb_categories(category_id) ON DELETE SET NULL,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    summary TEXT,
    keywords TEXT,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    author_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Service Level Agreements
CREATE TABLE custorix.service_level_agreements (
    sla_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    sla_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    response_time_hours INTEGER,
    resolution_time_hours INTEGER,
    business_hours_only BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Account SLAs
CREATE TABLE custorix.account_slas (
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    sla_id UUID REFERENCES custorix.service_level_agreements(sla_id) ON DELETE CASCADE,
    start_date DATE NOT NULL,
    end_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (account_id, sla_id)
);

-- =============================================
-- ACCOUNTING AND FINANCIAL TABLES
-- =============================================

-- Table: Currencies
CREATE TABLE custorix.currencies (
    currency_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    currency_code VARCHAR(3) NOT NULL UNIQUE,
    currency_name VARCHAR(100) NOT NULL UNIQUE,
    currency_symbol VARCHAR(10),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Exchange Rates
CREATE TABLE custorix.exchange_rates (
    rate_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    from_currency_id UUID REFERENCES custorix.currencies(currency_id) ON DELETE CASCADE,
    to_currency_id UUID REFERENCES custorix.currencies(currency_id) ON DELETE CASCADE,
    rate NUMERIC(15, 6) NOT NULL,
    effective_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (from_currency_id, to_currency_id, effective_date)
);

-- Table: Payment Terms
CREATE TABLE custorix.payment_terms (
    term_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    term_name VARCHAR(100) NOT NULL UNIQUE,
    days_due INTEGER NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Payment Methods
CREATE TABLE custorix.payment_methods (
    method_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    method_name VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Tax Rates
CREATE TABLE custorix.tax_rates (
    tax_rate_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    tax_name VARCHAR(100) NOT NULL,
    rate NUMERIC(5, 2) NOT NULL,
    country_id UUID REFERENCES custorix.countries(country_id) ON DELETE SET NULL,
    state_id UUID REFERENCES custorix.states(state_id) ON DELETE SET NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Chart of Accounts
CREATE TABLE custorix.chart_of_accounts (
    account_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_number VARCHAR(50) NOT NULL UNIQUE,
    account_name VARCHAR(100) NOT NULL,
    account_type VARCHAR(50) CHECK (account_type IN ('asset', 'liability', 'equity', 'revenue', 'expense')),
    parent_account_id UUID REFERENCES custorix.chart_of_accounts(account_id) ON DELETE SET NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Fiscal Years
CREATE TABLE custorix.fiscal_years (
    fiscal_year_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    year_name VARCHAR(50) NOT NULL UNIQUE,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Fiscal Periods
CREATE TABLE custorix.fiscal_periods (
    period_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    fiscal_year_id UUID REFERENCES custorix.fiscal_years(fiscal_year_id) ON DELETE CASCADE,
    period_name VARCHAR(50) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (fiscal_year_id, period_name)
);

-- Table: Invoices (Enhanced)
CREATE TABLE custorix.invoices (
    invoice_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE SET NULL,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    billing_address_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    shipping_address_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    currency_id UUID REFERENCES custorix.currencies(currency_id) ON DELETE SET NULL,
    payment_term_id UUID REFERENCES custorix.payment_terms(term_id) ON DELETE SET NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    subtotal NUMERIC(15, 2) NOT NULL,
    tax_amount NUMERIC(15, 2) DEFAULT 0,
    discount_amount NUMERIC(15, 2) DEFAULT 0,
    total_amount NUMERIC(15, 2) NOT NULL,
    balance_due NUMERIC(15, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'draft' CHECK (status IN ('draft', 'sent', 'partial', 'paid', 'overdue', 'cancelled')),
    notes TEXT,
    terms_and_conditions TEXT,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Invoice Line Items
CREATE TABLE custorix.invoice_line_items (
    line_item_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    invoice_id UUID REFERENCES custorix.invoices(invoice_id) ON DELETE CASCADE,
    product_id UUID REFERENCES custorix.products(product_id) ON DELETE SET NULL,
    description TEXT NOT NULL,
    quantity NUMERIC(10, 2) NOT NULL,
    unit_price NUMERIC(15, 2) NOT NULL,
    tax_rate NUMERIC(5, 2) DEFAULT 0,
    tax_amount NUMERIC(15, 2) DEFAULT 0,
    discount_percentage NUMERIC(5, 2) DEFAULT 0,
    discount_amount NUMERIC(15, 2) DEFAULT 0,
    total_amount NUMERIC(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Payments
CREATE TABLE custorix.payments (
    payment_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    payment_number VARCHAR(50) UNIQUE NOT NULL,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    payment_method_id UUID REFERENCES custorix.payment_methods(method_id) ON DELETE SET NULL,
    payment_date DATE NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    currency_id UUID REFERENCES custorix.currencies(currency_id) ON DELETE SET NULL,
    reference_number VARCHAR(100),
    notes TEXT,
    status VARCHAR(50) DEFAULT 'completed' CHECK (status IN ('pending', 'completed', 'failed', 'refunded')),
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Invoice Payments
CREATE TABLE custorix.invoice_payments (
    invoice_payment_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    invoice_id UUID REFERENCES custorix.invoices(invoice_id) ON DELETE CASCADE,
    payment_id UUID REFERENCES custorix.payments(payment_id) ON DELETE CASCADE,
    amount NUMERIC(15, 2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Expenses (Enhanced)
CREATE TABLE custorix.expenses (
    expense_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    expense_number VARCHAR(50) UNIQUE NOT NULL,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    category VARCHAR(100) NOT NULL,
    amount NUMERIC(15, 2) NOT NULL,
    tax_amount NUMERIC(15, 2) DEFAULT 0,
    currency_id UUID REFERENCES custorix.currencies(currency_id) ON DELETE SET NULL,
    expense_date DATE NOT NULL,
    payment_method_id UUID REFERENCES custorix.payment_methods(method_id) ON DELETE SET NULL,
    reference_number VARCHAR(100),
    description TEXT,
    receipt_url VARCHAR(255),
    is_billable BOOLEAN DEFAULT FALSE,
    is_reimbursable BOOLEAN DEFAULT FALSE,
    status VARCHAR(50) DEFAULT 'submitted' CHECK (status IN ('draft', 'submitted', 'approved', 'rejected', 'paid')),
    submitted_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    approved_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    approved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Journal Entries
CREATE TABLE custorix.journal_entries (
    entry_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    entry_number VARCHAR(50) UNIQUE NOT NULL,
    entry_date DATE NOT NULL,
    description TEXT,
    reference_number VARCHAR(100),
    is_posted BOOLEAN DEFAULT FALSE,
    posted_at TIMESTAMP,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Journal Entry Lines
CREATE TABLE custorix.journal_entry_lines (
    line_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    entry_id UUID REFERENCES custorix.journal_entries(entry_id) ON DELETE CASCADE,
    account_id UUID REFERENCES custorix.chart_of_accounts(account_id) ON DELETE CASCADE,
    description TEXT,
    debit_amount NUMERIC(15, 2) DEFAULT 0,
    credit_amount NUMERIC(15, 2) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CHECK (debit_amount >= 0 AND credit_amount >= 0),
    CHECK (debit_amount = 0 OR credit_amount = 0)
);

-- =============================================
-- ACTIVITY AND TASK MANAGEMENT TABLES
-- =============================================

-- Table: Activity Types
CREATE TABLE custorix.activity_types (
    type_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    type_name VARCHAR(50) NOT NULL UNIQUE,
    icon VARCHAR(50),
    color VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Activities (Enhanced)
CREATE TABLE custorix.activities (
    activity_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    activity_type_id UUID REFERENCES custorix.activity_types(type_id) ON DELETE SET NULL,
    subject VARCHAR(255) NOT NULL,
    description TEXT,
    start_date TIMESTAMP,
    end_date TIMESTAMP,
    is_all_day BOOLEAN DEFAULT FALSE,
    location VARCHAR(255),
    status VARCHAR(50) DEFAULT 'planned' CHECK (status IN ('planned', 'in_progress', 'completed', 'cancelled')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    lead_id UUID REFERENCES custorix.leads(lead_id) ON DELETE SET NULL,
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE SET NULL,
    ticket_id UUID REFERENCES custorix.support_tickets(ticket_id) ON DELETE SET NULL,
    assigned_to_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    assigned_by_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    completed_at TIMESTAMP,
    completed_by_id UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Activity Participants
CREATE TABLE custorix.activity_participants (
    activity_id UUID REFERENCES custorix.activities(activity_id) ON DELETE CASCADE,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    response_status VARCHAR(50) DEFAULT 'none' CHECK (response_status IN ('none', 'accepted', 'declined', 'tentative')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (activity_id, user_id)
);

-- Table: Notes
CREATE TABLE custorix.notes (
    note_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    title VARCHAR(255),
    content TEXT NOT NULL,
    is_private BOOLEAN DEFAULT FALSE,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    lead_id UUID REFERENCES custorix.leads(lead_id) ON DELETE SET NULL,
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE SET NULL,
    ticket_id UUID REFERENCES custorix.support_tickets(ticket_id) ON DELETE SET NULL,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Documents
CREATE TABLE custorix.documents (
    document_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    document_name VARCHAR(255) NOT NULL,
    file_url VARCHAR(255) NOT NULL,
    file_type VARCHAR(100),
    file_size INTEGER,
    description TEXT,
    is_private BOOLEAN DEFAULT FALSE,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE SET NULL,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE SET NULL,
    opportunity_id UUID REFERENCES custorix.opportunities(opportunity_id) ON DELETE SET NULL,
    ticket_id UUID REFERENCES custorix.support_tickets(ticket_id) ON DELETE SET NULL,
    uploaded_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- AUTOMATION AND WORKFLOW TABLES
-- =============================================

-- Table: Workflow Rules
CREATE TABLE custorix.workflow_rules (
    rule_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    rule_name VARCHAR(100) NOT NULL,
    description TEXT,
    object_type VARCHAR(50) NOT NULL,
    trigger_type VARCHAR(50) CHECK (trigger_type IN ('on_create', 'on_update', 'on_delete', 'scheduled')),
    condition_logic TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Workflow Actions
CREATE TABLE custorix.workflow_actions (
    action_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    rule_id UUID REFERENCES custorix.workflow_rules(rule_id) ON DELETE CASCADE,
    action_type VARCHAR(50) CHECK (action_type IN ('update_field', 'create_task', 'send_email', 'send_notification', 'call_webhook')),
    action_order INTEGER NOT NULL,
    action_config JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Workflow Execution Logs
CREATE TABLE custorix.workflow_execution_logs (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    rule_id UUID REFERENCES custorix.workflow_rules(rule_id) ON DELETE SET NULL,
    record_id UUID NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    execution_status VARCHAR(50) CHECK (execution_status IN ('success', 'partial_success', 'failed')),
    execution_details JSONB,
    executed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Email Notifications
CREATE TABLE custorix.email_notifications (
    notification_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    notification_name VARCHAR(100) NOT NULL,
    description TEXT,
    template_id UUID REFERENCES custorix.email_templates(template_id) ON DELETE SET NULL,
    event_type VARCHAR(50) NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Scheduled Jobs
CREATE TABLE custorix.scheduled_jobs (
    job_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    description TEXT,
    job_type VARCHAR(50) NOT NULL,
    cron_expression VARCHAR(100) NOT NULL,
    parameters JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    last_run_at TIMESTAMP,
    next_run_at TIMESTAMP,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Job Execution Logs
CREATE TABLE custorix.job_execution_logs (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    job_id UUID REFERENCES custorix.scheduled_jobs(job_id) ON DELETE SET NULL,
    execution_status VARCHAR(50) CHECK (execution_status IN ('success', 'failed')),
    start_time TIMESTAMP NOT NULL,
    end_time TIMESTAMP,
    execution_details JSONB,
    error_message TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- REPORTING AND ANALYTICS TABLES
-- =============================================

-- Table: Reports
CREATE TABLE custorix.reports (
    report_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    report_name VARCHAR(100) NOT NULL,
    description TEXT,
    report_type VARCHAR(50) NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    filter_criteria JSONB,
    columns JSONB,
    grouping JSONB,
    sorting JSONB,
    is_public BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Dashboards
CREATE TABLE custorix.dashboards (
    dashboard_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    dashboard_name VARCHAR(100) NOT NULL,
    description TEXT,
    layout JSONB,
    is_public BOOLEAN DEFAULT FALSE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Dashboard Widgets
CREATE TABLE custorix.dashboard_widgets (
    widget_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    dashboard_id UUID REFERENCES custorix.dashboards(dashboard_id) ON DELETE CASCADE,
    widget_name VARCHAR(100) NOT NULL,
    widget_type VARCHAR(50) NOT NULL,
    data_source VARCHAR(50) NOT NULL,
    report_id UUID REFERENCES custorix.reports(report_id) ON DELETE SET NULL,
    configuration JSONB,
    position_x INTEGER,
    position_y INTEGER,
    width INTEGER,
    height INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Report Schedules
CREATE TABLE custorix.report_schedules (
    schedule_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    report_id UUID REFERENCES custorix.reports(report_id) ON DELETE CASCADE,
    schedule_name VARCHAR(100) NOT NULL,
    frequency VARCHAR(50) CHECK (frequency IN ('daily', 'weekly', 'monthly', 'quarterly')),
    day_of_week INTEGER,
    day_of_month INTEGER,
    time_of_day TIME,
    recipients JSONB,
    format VARCHAR(20) CHECK (format IN ('pdf', 'excel', 'csv')),
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Data Export Jobs
CREATE TABLE custorix.data_export_jobs (
    job_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    job_name VARCHAR(100) NOT NULL,
    object_type VARCHAR(50) NOT NULL,
    filter_criteria JSONB,
    columns JSONB,
    format VARCHAR(20) CHECK (format IN ('csv', 'excel', 'json')),
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed')),
    file_url VARCHAR(255),
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    started_at TIMESTAMP,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- AUDIT AND SECURITY TABLES
-- =============================================

-- Table: Audit Log (Enhanced)
CREATE TABLE custorix.audit_log (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE', 'LOGIN', 'LOGOUT', 'EXPORT', 'IMPORT')),
    old_data JSONB,
    new_data JSONB,
    changes JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    performed_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Security Settings
CREATE TABLE custorix.security_settings (
    setting_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    setting_name VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: API Keys
CREATE TABLE custorix.api_keys (
    key_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    api_key VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    permissions JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    expires_at TIMESTAMP,
    last_used_at TIMESTAMP,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: API Request Logs
CREATE TABLE custorix.api_request_logs (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    api_key_id UUID REFERENCES custorix.api_keys(key_id) ON DELETE SET NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    request_headers JSONB,
    request_body JSONB,
    response_code INTEGER,
    response_time INTEGER, -- in milliseconds
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- INTEGRATION TABLES
-- =============================================

-- Table: Integration Providers
CREATE TABLE custorix.integration_providers (
    provider_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    provider_name VARCHAR(100) NOT NULL UNIQUE,
    provider_type VARCHAR(50) NOT NULL,
    description TEXT,
    logo_url VARCHAR(255),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Integration Connections
CREATE TABLE custorix.integration_connections (
    connection_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    provider_id UUID REFERENCES custorix.integration_providers(provider_id) ON DELETE CASCADE,
    connection_name VARCHAR(100) NOT NULL,
    credentials JSONB,
    settings JSONB,
    status VARCHAR(50) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'error')),
    last_sync_at TIMESTAMP,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Integration Sync Logs
CREATE TABLE custorix.integration_sync_logs (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    connection_id UUID REFERENCES custorix.integration_connections(connection_id) ON DELETE CASCADE,
    sync_type VARCHAR(50) NOT NULL,
    status VARCHAR(50) CHECK (status IN ('success', 'partial_success', 'failed')),
    records_processed INTEGER DEFAULT 0,
    records_created INTEGER DEFAULT 0,
    records_updated INTEGER DEFAULT 0,
    records_failed INTEGER DEFAULT 0,
    error_details JSONB,
    started_at TIMESTAMP NOT NULL,
    completed_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Webhooks
CREATE TABLE custorix.webhooks (
    webhook_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    webhook_name VARCHAR(100) NOT NULL,
    target_url VARCHAR(255) NOT NULL,
    event_types JSONB NOT NULL,
    secret_key VARCHAR(255),
    headers JSONB,
    is_active BOOLEAN DEFAULT TRUE,
    created_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Webhook Delivery Logs
CREATE TABLE custorix.webhook_delivery_logs (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    webhook_id UUID REFERENCES custorix.webhooks(webhook_id) ON DELETE CASCADE,
    event_type VARCHAR(100) NOT NULL,
    payload JSONB NOT NULL,
    response_code INTEGER,
    response_body TEXT,
    status VARCHAR(50) CHECK (status IN ('success', 'failed')),
    retry_count INTEGER DEFAULT 0,
    delivered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- =============================================
-- VIEWS FOR COMMON QUERIES
-- =============================================

-- View: Active Accounts with Open Opportunities
CREATE VIEW custorix.active_accounts_with_open_opportunities AS
SELECT 
    a.account_id,
    a.account_name,
    a.status,
    COUNT(o.opportunity_id) AS open_opportunities_count,
    SUM(o.amount) AS total_opportunity_amount
FROM 
    custorix.accounts a
LEFT JOIN 
    custorix.opportunities o ON a.account_id = o.account_id AND o.is_closed = FALSE
WHERE 
    a.status = 'active'
GROUP BY 
    a.account_id, a.account_name, a.status;

-- View: Support Tickets by Priority and Status
CREATE VIEW custorix.support_tickets_by_priority_status AS
SELECT 
    p.priority_name,
    s.status_name,
    COUNT(t.ticket_id) AS ticket_count
FROM 
    custorix.support_tickets t
JOIN 
    custorix.ticket_priorities p ON t.priority_id = p.priority_id
JOIN 
    custorix.ticket_statuses s ON t.status_id = s.status_id
GROUP BY 
    p.priority_name, s.status_name;

-- View: Monthly Revenue
CREATE VIEW custorix.monthly_revenue AS
SELECT 
    DATE_TRUNC('month', i.issue_date) AS month,
    SUM(i.total_amount) AS total_revenue,
    COUNT(DISTINCT i.account_id) AS unique_customers
FROM 
    custorix.invoices i
WHERE 
    i.status IN ('paid', 'partial')
GROUP BY 
    DATE_TRUNC('month', i.issue_date)
ORDER BY 
    month DESC;

-- View: Sales Pipeline by Stage
CREATE VIEW custorix.sales_pipeline_by_stage AS
SELECT 
    s.stage_name,
    COUNT(o.opportunity_id) AS opportunity_count,
    SUM(o.amount) AS total_amount,
    AVG(o.amount) AS average_amount,
    s.probability AS stage_probability
FROM 
    custorix.opportunities o
JOIN 
    custorix.sales_stages s ON o.stage_id = s.stage_id
WHERE 
    o.is_closed = FALSE
GROUP BY 
    s.stage_name, s.probability, s.display_order
ORDER BY 
    s.display_order;

-- View: User Activity Summary
CREATE VIEW custorix.user_activity_summary AS
SELECT 
    u.user_id,
    u.first_name || ' ' || u.last_name AS user_name,
    COUNT(DISTINCT a.activity_id) AS activities_count,
    COUNT(DISTINCT o.opportunity_id) AS opportunities_count,
    COUNT(DISTINCT t.ticket_id) AS tickets_count,
    MAX(a.created_at) AS last_activity_date
FROM 
    custorix.users u
LEFT JOIN 
    custorix.activities a ON u.user_id = a.assigned_to_id
LEFT JOIN 
    custorix.opportunities o ON u.user_id = o.assigned_to_id
LEFT JOIN 
    custorix.support_tickets t ON u.user_id = t.assigned_to_id
GROUP BY 
    u.user_id, user_name;

-- View: Active Tokens
CREATE VIEW custorix.active_tokens AS
SELECT 
    t.token_id,
    t.user_id,
    u.username,
    t.token_type,
    t.device_info,
    t.ip_address,
    t.expires_at
FROM 
    custorix.tokens t
JOIN 
    custorix.users u ON t.user_id = u.user_id
WHERE 
    t.expires_at > CURRENT_TIMESTAMP;

-- =============================================
-- FUNCTIONS AND TRIGGERS
-- =============================================

-- Function: Update Account Status Based on Opportunities
CREATE OR REPLACE FUNCTION custorix.update_account_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_closed = TRUE AND NEW.is_won = TRUE THEN
        UPDATE custorix.accounts SET status = 'customer' WHERE account_id = NEW.account_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_account_status
AFTER UPDATE ON custorix.opportunities
FOR EACH ROW
EXECUTE FUNCTION custorix.update_account_status();

-- Function: Calculate Invoice Totals
CREATE OR REPLACE FUNCTION custorix.calculate_invoice_totals()
RETURNS TRIGGER AS $$
DECLARE
    v_subtotal NUMERIC(15, 2);
    v_tax_amount NUMERIC(15, 2);
    v_discount_amount NUMERIC(15, 2);
    v_total_amount NUMERIC(15, 2);
BEGIN
    -- Calculate subtotal
    SELECT COALESCE(SUM(total_amount), 0) INTO v_subtotal
    FROM custorix.invoice_line_items
    WHERE invoice_id = NEW.invoice_id;
    
    -- Calculate tax amount
    SELECT COALESCE(SUM(tax_amount), 0) INTO v_tax_amount
    FROM custorix.invoice_line_items
    WHERE invoice_id = NEW.invoice_id;
    
    -- Calculate discount amount
    SELECT COALESCE(SUM(discount_amount), 0) INTO v_discount_amount
    FROM custorix.invoice_line_items
    WHERE invoice_id = NEW.invoice_id;
    
    -- Calculate total amount
    v_total_amount := v_subtotal + v_tax_amount - v_discount_amount;
    
    -- Update the invoice
    UPDATE custorix.invoices
    SET subtotal = v_subtotal,
        tax_amount = v_tax_amount,
        discount_amount = v_discount_amount,
        total_amount = v_total_amount,
        balance_due = v_total_amount
    WHERE invoice_id = NEW.invoice_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calculate_invoice_totals
AFTER INSERT OR UPDATE OR DELETE ON custorix.invoice_line_items
FOR EACH ROW
EXECUTE FUNCTION custorix.calculate_invoice_totals();

-- Function: Update Invoice Balance After Payment
CREATE OR REPLACE FUNCTION custorix.update_invoice_balance()
RETURNS TRIGGER AS $$
DECLARE
    v_total_paid NUMERIC(15, 2);
    v_total_amount NUMERIC(15, 2);
    v_balance_due NUMERIC(15, 2);
    v_status VARCHAR(50);
BEGIN
    -- Get total amount paid for this invoice
    SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
    FROM custorix.invoice_payments
    WHERE invoice_id = NEW.invoice_id;
    
    -- Get invoice total amount
    SELECT total_amount INTO v_total_amount
    FROM custorix.invoices
    WHERE invoice_id = NEW.invoice_id;
    
    -- Calculate balance due
    v_balance_due := v_total_amount - v_total_paid;
    
    -- Determine status
    IF v_balance_due <= 0 THEN
        v_status := 'paid';
    ELSIF v_total_paid > 0 THEN
        v_status := 'partial';
    ELSE
        -- Keep existing status if no payment has been made
        SELECT status INTO v_status
        FROM custorix.invoices
        WHERE invoice_id = NEW.invoice_id;
    END IF;
    
    -- Update the invoice
    UPDATE custorix.invoices
    SET balance_due = v_balance_due,
        status = v_status
    WHERE invoice_id = NEW.invoice_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_invoice_balance
AFTER INSERT OR UPDATE OR DELETE ON custorix.invoice_payments
FOR EACH ROW
EXECUTE FUNCTION custorix.update_invoice_balance();

-- Function: Check Overdue Invoices
CREATE OR REPLACE FUNCTION custorix.check_overdue_invoices()
RETURNS void AS $$
BEGIN
    UPDATE custorix.invoices
    SET status = 'overdue'
    WHERE due_date < CURRENT_DATE
    AND status IN ('draft', 'sent', 'partial');
END;
$$ LANGUAGE plpgsql;

-- Function: Set Application User for Audit Context
CREATE OR REPLACE FUNCTION custorix.set_application_user(app_user_id UUID) 
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', app_user_id::text, false);
END;
$$ LANGUAGE plpgsql;

-- Improved Audit Log Function that dynamically identifies primary keys
CREATE OR REPLACE FUNCTION custorix.log_audit()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_record_id uuid;
    v_pk_column text;
    v_changes jsonb;
BEGIN
    -- Get the authenticated application user ID if possible, or use NULL if not available
    BEGIN
        -- Try to get a user ID from the application context if available
        v_user_id := current_setting('app.current_user_id', true)::uuid;
    EXCEPTION WHEN OTHERS THEN
        -- If no application user context is set, try to find a matching database user
        BEGIN
            SELECT user_id INTO v_user_id
            FROM custorix.users
            WHERE username = current_user;
        EXCEPTION WHEN OTHERS THEN
            v_user_id := NULL; -- If we can't find a match, use NULL
        END;
    END;

    -- Dynamically determine the primary key column of the table
    -- This assumes tables follow the convention of having a primary key named <table_name without schema>_id
    v_pk_column := split_part(TG_TABLE_NAME, '.', 2) || '_id';

    -- Get the record ID
    IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN
        EXECUTE format('SELECT $1.%I', v_pk_column) USING NEW INTO v_record_id;
    ELSIF TG_OP = 'DELETE' THEN
        EXECUTE format('SELECT $1.%I', v_pk_column) USING OLD INTO v_record_id;
    END IF;
    
    -- Calculate changes for UPDATE operations
    IF TG_OP = 'UPDATE' THEN
        v_changes := jsonb_object_agg(key, value) 
        FROM (
            SELECT 
                key, 
                jsonb_build_object('old', old_value, 'new', new_value) AS value
            FROM 
                jsonb_each_text(to_jsonb(OLD)) AS o(key, old_value)
            JOIN 
                jsonb_each_text(to_jsonb(NEW)) AS n(key, new_value)
            ON 
                o.key = n.key
            WHERE 
                o.old_value IS DISTINCT FROM n.new_value
        ) AS changes;
    ELSE
        v_changes := NULL;
    END IF;

    -- Insert into the audit log
    INSERT INTO custorix.audit_log (
        table_name, 
        record_id, 
        action, 
        old_data, 
        new_data, 
        changes,
        ip_address,
        performed_by
    )
    VALUES (
        TG_TABLE_NAME, 
        v_record_id, 
        TG_OP, 
        CASE WHEN TG_OP IN ('UPDATE', 'DELETE') THEN to_jsonb(OLD) ELSE NULL END,
        CASE WHEN TG_OP IN ('UPDATE', 'INSERT') THEN to_jsonb(NEW) ELSE NULL END,
        v_changes,
        NULL, -- IP address would be set by application
        v_user_id
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply the audit trigger to key tables
CREATE TRIGGER trg_audit_users
AFTER INSERT OR UPDATE OR DELETE ON custorix.users
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_accounts
AFTER INSERT OR UPDATE OR DELETE ON custorix.accounts
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_opportunities
AFTER INSERT OR UPDATE OR DELETE ON custorix.opportunities
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_invoices
AFTER INSERT OR UPDATE OR DELETE ON custorix.invoices
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_contacts
AFTER INSERT OR UPDATE OR DELETE ON custorix.contacts
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_leads
AFTER INSERT OR UPDATE OR DELETE ON custorix.leads
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_support_tickets
AFTER INSERT OR UPDATE OR DELETE ON custorix.support_tickets
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

-- Function: Generate Ticket Number
CREATE OR REPLACE FUNCTION custorix.generate_ticket_number()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix VARCHAR(10) := 'TKT';
    v_year VARCHAR(4) := to_char(CURRENT_DATE, 'YYYY');
    v_next_number INTEGER;
BEGIN
    -- Get the next number
    SELECT COALESCE(MAX(CAST(SUBSTRING(ticket_number FROM 9) AS INTEGER)), 0) + 1 INTO v_next_number
    FROM custorix.support_tickets
    WHERE ticket_number LIKE v_prefix || v_year || '-%';
    
    -- Set the ticket number
    NEW.ticket_number := v_prefix || v_year || '-' || LPAD(v_next_number::TEXT, 6, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_ticket_number
BEFORE INSERT ON custorix.support_tickets
FOR EACH ROW
EXECUTE FUNCTION custorix.generate_ticket_number();

-- Function: Generate Invoice Number
CREATE OR REPLACE FUNCTION custorix.generate_invoice_number()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix VARCHAR(10) := 'INV';
    v_year VARCHAR(4) := to_char(CURRENT_DATE, 'YYYY');
    v_next_number INTEGER;
BEGIN
    -- Get the next number
    SELECT COALESCE(MAX(CAST(SUBSTRING(invoice_number FROM 9) AS INTEGER)), 0) + 1 INTO v_next_number
    FROM custorix.invoices
    WHERE invoice_number LIKE v_prefix || v_year || '-%';
    
    -- Set the invoice number
    NEW.invoice_number := v_prefix || v_year || '-' || LPAD(v_next_number::TEXT, 6, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_invoice_number
BEFORE INSERT ON custorix.invoices
FOR EACH ROW
WHEN (NEW.invoice_number IS NULL)
EXECUTE FUNCTION custorix.generate_invoice_number();

-- Function: Generate Expense Number
CREATE OR REPLACE FUNCTION custorix.generate_expense_number()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix VARCHAR(10) := 'EXP';
    v_year VARCHAR(4) := to_char(CURRENT_DATE, 'YYYY');
    v_next_number INTEGER;
BEGIN
    -- Get the next number
    SELECT COALESCE(MAX(CAST(SUBSTRING(expense_number FROM 9) AS INTEGER)), 0) + 1 INTO v_next_number
    FROM custorix.expenses
    WHERE expense_number LIKE v_prefix || v_year || '-%';
    
    -- Set the expense number
    NEW.expense_number := v_prefix || v_year || '-' || LPAD(v_next_number::TEXT, 6, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_expense_number
BEFORE INSERT ON custorix.expenses
FOR EACH ROW
WHEN (NEW.expense_number IS NULL)
EXECUTE FUNCTION custorix.generate_expense_number();

-- Function: Generate Payment Number
CREATE OR REPLACE FUNCTION custorix.generate_payment_number()
RETURNS TRIGGER AS $$
DECLARE
    v_prefix VARCHAR(10) := 'PMT';
    v_year VARCHAR(4) := to_char(CURRENT_DATE, 'YYYY');
    v_next_number INTEGER;
BEGIN
    -- Get the next number
    SELECT COALESCE(MAX(CAST(SUBSTRING(payment_number FROM 9) AS INTEGER)), 0) + 1 INTO v_next_number
    FROM custorix.payments
    WHERE payment_number LIKE v_prefix || v_year || '-%';
    
    -- Set the payment number
    NEW.payment_number := v_prefix || v_year || '-' || LPAD(v_next_number::TEXT, 6, '0');
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_generate_payment_number
BEFORE INSERT ON custorix.payments
FOR EACH ROW
WHEN (NEW.payment_number IS NULL)
EXECUTE FUNCTION custorix.generate_payment_number();

-- Function: List Tables in Schema
CREATE OR REPLACE FUNCTION custorix.list_tables() RETURNS TABLE (
    table_name VARCHAR,
    table_type VARCHAR,
    row_count BIGINT
) AS $$
DECLARE
    v_table RECORD;
    v_count BIGINT;
    v_query TEXT;
BEGIN
    FOR v_table IN 
        SELECT tablename 
        FROM pg_tables 
        WHERE schemaname = 'custorix'
        ORDER BY tablename
    LOOP
        v_query := 'SELECT COUNT(*) FROM custorix.' || quote_ident(v_table.tablename);
        EXECUTE v_query INTO v_count;
        
        table_name := v_table.tablename;
        table_type := 'TABLE';
        row_count := v_count;
        RETURN NEXT;
    END LOOP;
    
    FOR v_table IN 
        SELECT viewname 
        FROM pg_views 
        WHERE schemaname = 'custorix'
        ORDER BY viewname
    LOOP
        table_name := v_table.viewname;
        table_type := 'VIEW';
        row_count := NULL;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function: List Views in Schema
CREATE OR REPLACE FUNCTION custorix.list_views() RETURNS TABLE (
    view_name VARCHAR,
    view_definition TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        v.viewname::VARCHAR,
        pg_get_viewdef(c.oid)::TEXT
    FROM 
        pg_views v
    JOIN 
        pg_class c ON v.viewname = c.relname
    JOIN 
        pg_namespace n ON c.relnamespace = n.oid
    WHERE 
        v.schemaname = 'custorix'
    ORDER BY 
        v.viewname;
END;
$$ LANGUAGE plpgsql;

-- Insert default data for testing
-- Roles
INSERT INTO custorix.roles (role_name, description, is_system_role) 
VALUES 
('Administrator', 'Full system access', TRUE),
('Sales Manager', 'Manages sales team and has access to sales reports', TRUE),
('Sales Representative', 'Handles leads, opportunities and customer accounts', TRUE),
('Marketing Manager', 'Manages marketing campaigns and assets', TRUE),
('Support Agent', 'Handles customer support tickets', TRUE),
('Accountant', 'Manages invoices, payments and financial reports', TRUE),
('Customer', 'External customer access', TRUE);

-- Departments
INSERT INTO custorix.departments (department_name, description)
VALUES
('Sales', 'Sales department'),
('Marketing', 'Marketing department'),
('Customer Support', 'Customer support department'),
('Finance', 'Finance and accounting department'),
('IT', 'Information technology department'),
('Human Resources', 'Human resources department');

-- Commit the transaction
COMMIT;
