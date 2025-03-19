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

-- Table: Roles
CREATE TABLE custorix.roles (
    role_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    role_name VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Departments
CREATE TABLE custorix.departments (
    department_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    department_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Users (Employees/Admins)
CREATE TABLE custorix.users (
    user_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role_id UUID REFERENCES custorix.roles(role_id) ON DELETE SET NULL,
    department_id UUID REFERENCES custorix.departments(department_id) ON DELETE SET NULL,
    username VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Table: Locations
CREATE TABLE custorix.locations (
    location_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL,
    postal_code VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Accounts (Customers/Organizations)
CREATE TABLE custorix.accounts (
    account_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_name VARCHAR(100) NOT NULL,
    industry VARCHAR(100),
    website VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),
    location_id UUID REFERENCES custorix.locations(location_id) ON DELETE SET NULL,
    account_owner UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    status VARCHAR(50) DEFAULT 'prospect' CHECK (status IN ('prospect', 'active', 'inactive')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Contacts (Individual Customer Contacts)
CREATE TABLE custorix.contacts (
    contact_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    job_title VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Leads (Potential Customers)
CREATE TABLE custorix.leads (
    lead_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    company_name VARCHAR(100),
    status VARCHAR(50) DEFAULT 'new' CHECK (status IN ('new', 'contacted', 'qualified', 'closed')),
    assigned_to UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Sales Pipeline (Deals/Opportunities)
CREATE TABLE custorix.sales_pipeline (
    deal_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    deal_name VARCHAR(100) NOT NULL,
    amount NUMERIC(15, 2),
    stage VARCHAR(50) DEFAULT 'prospecting' CHECK (stage IN ('prospecting', 'negotiation', 'closed-won', 'closed-lost')),
    close_date DATE,
    assigned_to UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Marketing Campaigns
CREATE TABLE custorix.marketing_campaigns (
    campaign_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    campaign_name VARCHAR(100) NOT NULL,
    campaign_type VARCHAR(50) CHECK (campaign_type IN ('email', 'social', 'event', 'other')),
    start_date DATE,
    end_date DATE,
    budget NUMERIC(15, 2),
    status VARCHAR(50) DEFAULT 'planned' CHECK (status IN ('planned', 'active', 'completed', 'cancelled')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Support Tickets
CREATE TABLE custorix.support_tickets (
    ticket_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    subject VARCHAR(200) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'open' CHECK (status IN ('open', 'in-progress', 'resolved', 'closed')),
    priority VARCHAR(50) DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high')),
    assigned_to UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Accounting (Invoices and Payments)
CREATE TABLE custorix.invoices (
    invoice_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    invoice_number VARCHAR(50) UNIQUE NOT NULL,
    issue_date DATE,
    due_date DATE,
    amount NUMERIC(15, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid', 'overdue')),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Expenses
CREATE TABLE custorix.expenses (
    expense_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    category VARCHAR(100),
    amount NUMERIC(15, 2) NOT NULL,
    description TEXT,
    expense_date DATE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Activities
CREATE TABLE custorix.activities (
    activity_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    account_id UUID REFERENCES custorix.accounts(account_id) ON DELETE CASCADE,
    contact_id UUID REFERENCES custorix.contacts(contact_id) ON DELETE CASCADE,
    activity_type VARCHAR(50) CHECK (activity_type IN ('call', 'email', 'meeting', 'task')),
    description TEXT,
    due_date DATE,
    status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'completed')),
    assigned_to UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Tokens (for authentication or other purposes)
CREATE TABLE custorix.tokens (
    token_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES custorix.users(user_id) ON DELETE CASCADE,
    token VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Table: Audit Log
CREATE TABLE custorix.audit_log (
    log_id UUID DEFAULT public.uuid_generate_v4() PRIMARY KEY,
    table_name VARCHAR(100) NOT NULL,
    record_id UUID NOT NULL,
    action VARCHAR(50) NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    old_data JSONB,
    new_data JSONB,
    performed_by UUID REFERENCES custorix.users(user_id) ON DELETE SET NULL,
    performed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Indexes for Faster Queries
CREATE INDEX idx_users_email ON custorix.users(email);
CREATE INDEX idx_accounts_account_name ON custorix.accounts(account_name);
CREATE INDEX idx_leads_status ON custorix.leads(status);
CREATE INDEX idx_sales_pipeline_stage ON custorix.sales_pipeline(stage);
CREATE INDEX idx_invoices_status ON custorix.invoices(status);
CREATE INDEX idx_support_tickets_status ON custorix.support_tickets(status);
CREATE INDEX idx_tokens_user_id ON custorix.tokens(user_id);

-- Trigger: Update Account Status Based on Sales Pipeline
CREATE OR REPLACE FUNCTION custorix.update_account_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.stage = 'closed-won' THEN
        UPDATE custorix.accounts SET status = 'active' WHERE account_id = NEW.account_id;
    ELSIF NEW.stage = 'closed-lost' THEN
        UPDATE custorix.accounts SET status = 'inactive' WHERE account_id = NEW.account_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_account_status
AFTER UPDATE ON custorix.sales_pipeline
FOR EACH ROW
EXECUTE FUNCTION custorix.update_account_status();

-- Improved Audit Log Function that dynamically identifies primary keys
CREATE OR REPLACE FUNCTION custorix.log_audit()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id uuid;
    v_record_id uuid;
    v_pk_column text;
BEGIN
    -- Get the authenticated application user ID if possible, or use NULL if not available
    BEGIN
        -- Try to get a user ID from the application context if available
        -- This could be set by your application when connecting
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

    -- Insert into the audit log
    INSERT INTO custorix.audit_log (table_name, record_id, action, old_data, new_data, performed_by)
    VALUES (TG_TABLE_NAME, v_record_id, TG_OP, to_jsonb(OLD), to_jsonb(NEW), v_user_id);

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

CREATE TRIGGER trg_audit_sales_pipeline
AFTER INSERT OR UPDATE OR DELETE ON custorix.sales_pipeline
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

CREATE TRIGGER trg_audit_invoices
AFTER INSERT OR UPDATE OR DELETE ON custorix.invoices
FOR EACH ROW
EXECUTE FUNCTION custorix.log_audit();

-- View: Active Accounts with Open Deals
CREATE VIEW custorix.active_accounts_with_open_deals AS
SELECT a.account_id, a.account_name, COUNT(d.deal_id) AS open_deals
FROM custorix.accounts a
LEFT JOIN custorix.sales_pipeline d ON a.account_id = d.account_id AND d.stage = 'prospecting'
WHERE a.status = 'active'
GROUP BY a.account_id, a.account_name;

-- View: Support Tickets by Priority
CREATE VIEW custorix.support_tickets_by_priority AS
SELECT priority, COUNT(ticket_id) AS ticket_count
FROM custorix.support_tickets
GROUP BY priority;

-- View: Monthly Revenue
CREATE VIEW custorix.monthly_revenue AS
SELECT EXTRACT(YEAR FROM issue_date) AS year, EXTRACT(MONTH FROM issue_date) AS month, SUM(amount) AS total_revenue
FROM custorix.invoices
WHERE status = 'paid'
GROUP BY year, month
ORDER BY year DESC, month DESC;

-- View: Active Tokens
CREATE VIEW custorix.active_tokens AS
SELECT token_id, user_id, token, expires_at
FROM custorix.tokens
WHERE expires_at > CURRENT_TIMESTAMP;

-- Procedure: Close Support Ticket
CREATE OR REPLACE PROCEDURE custorix.close_support_ticket(ticket_uuid UUID)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM custorix.support_tickets WHERE ticket_id = ticket_uuid) THEN
        RAISE EXCEPTION 'Ticket % does not exist.', ticket_uuid;
    END IF;

    UPDATE custorix.support_tickets SET status = 'closed' WHERE ticket_id = ticket_uuid;
    RAISE NOTICE 'Support Ticket % has been closed.', ticket_uuid;
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'An error occurred while closing the ticket: %', SQLERRM;
END;
$$;

-- Procedure: Generate Monthly Sales Report
CREATE OR REPLACE PROCEDURE custorix.generate_monthly_sales_report(month INT, year INT)
LANGUAGE plpgsql
AS $$
BEGIN
    RAISE NOTICE 'Sales Report for %/%:', month, year;
    RAISE NOTICE 'Total Deals: %', (SELECT COUNT(deal_id) FROM custorix.sales_pipeline WHERE EXTRACT(MONTH FROM created_at) = month AND EXTRACT(YEAR FROM created_at) = year);
    RAISE NOTICE 'Total Revenue: %', (SELECT SUM(amount) FROM custorix.sales_pipeline WHERE EXTRACT(MONTH FROM created_at) = month AND EXTRACT(YEAR FROM created_at) = year AND stage = 'closed-won');
EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'An error occurred while generating the sales report: %', SQLERRM;
END;
$$;

-- Function to set app.current_user_id for use with audit log
CREATE OR REPLACE FUNCTION custorix.set_application_user(app_user_id UUID) 
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.current_user_id', app_user_id::text, false);
END;
$$ LANGUAGE plpgsql;

-- Insert Sample Data
INSERT INTO custorix.roles (role_name) VALUES ('admin'), ('sales'), ('support'), ('marketing'), ('finance'), ('hr');

INSERT INTO custorix.departments (department_name) VALUES ('Sales'), ('Marketing'), ('Support'), ('HR'), ('Finance');

-- Insert users with proper usernames
INSERT INTO custorix.users (first_name, last_name, email, password_hash, role_id, department_id, username) VALUES
('John', 'Doe', 'john.doe@example.com', crypt('password123', gen_salt('bf')), 
 (SELECT role_id FROM custorix.roles WHERE role_name = 'admin'), 
 (SELECT department_id FROM custorix.departments WHERE department_name = 'Finance'), 
 'john.doe'),
('Jane', 'Smith', 'jane.smith@example.com', crypt('password456', gen_salt('bf')), 
 (SELECT role_id FROM custorix.roles WHERE role_name = 'sales'), 
 (SELECT department_id FROM custorix.departments WHERE department_name = 'Sales'), 
 'jane.smith');

INSERT INTO custorix.locations (address, city, state, country, postal_code) VALUES
('123 Main St', 'New York', 'NY', 'USA', '10001');

INSERT INTO custorix.accounts (account_name, industry, email, phone, location_id, account_owner) VALUES
('Acme Corp', 'Manufacturing', 'acme@example.com', '+1234567890', 
 (SELECT location_id FROM custorix.locations WHERE address = '123 Main St'), 
 (SELECT user_id FROM custorix.users WHERE email = 'john.doe@example.com'));

INSERT INTO custorix.contacts (account_id, first_name, last_name, email, phone) VALUES
((SELECT account_id FROM custorix.accounts WHERE account_name = 'Acme Corp'), 
 'Alice', 'Johnson', 'alice@example.com', '+1234567891');

INSERT INTO custorix.leads (first_name, last_name, email, company_name, assigned_to) VALUES
('Bob', 'Brown', 'bob@example.com', 'Brown Industries', 
 (SELECT user_id FROM custorix.users WHERE email = 'jane.smith@example.com'));

INSERT INTO custorix.sales_pipeline (account_id, deal_name, amount, stage, assigned_to) VALUES
((SELECT account_id FROM custorix.accounts WHERE account_name = 'Acme Corp'), 
 'Acme Deal 1', 10000.00, 'prospecting', 
 (SELECT user_id FROM custorix.users WHERE email = 'jane.smith@example.com'));

INSERT INTO custorix.marketing_campaigns (campaign_name, campaign_type, start_date, end_date, budget, status) VALUES
('Summer Sale', 'email', '2023-07-01', '2023-07-31', 5000.00, 'completed');

INSERT INTO custorix.support_tickets (account_id, contact_id, subject, description, status, priority, assigned_to) VALUES
((SELECT account_id FROM custorix.accounts WHERE account_name = 'Acme Corp'), 
 (SELECT contact_id FROM custorix.contacts WHERE email = 'alice@example.com'), 
 'Login Issue', 'Unable to log in to the portal.', 'open', 'high', 
 (SELECT user_id FROM custorix.users WHERE email = 'john.doe@example.com'));

INSERT INTO custorix.invoices (account_id, invoice_number, issue_date, due_date, amount, status) VALUES
((SELECT account_id FROM custorix.accounts WHERE account_name = 'Acme Corp'), 
 'INV-001', '2023-10-01', '2023-10-15', 1500.00, 'unpaid');

INSERT INTO custorix.expenses (category, amount, description, expense_date) VALUES
('Travel', 200.00, 'Client meeting in New York', '2023-09-15');

INSERT INTO custorix.activities (account_id, contact_id, activity_type, description, due_date, status, assigned_to) VALUES
((SELECT account_id FROM custorix.accounts WHERE account_name = 'Acme Corp'), 
 (SELECT contact_id FROM custorix.contacts WHERE email = 'alice@example.com'), 
 'meeting', 'Discuss project requirements.', '2023-10-10', 'pending', 
 (SELECT user_id FROM custorix.users WHERE email = 'jane.smith@example.com'));

-- Add helper functions for displaying database objects

-- Function to list all tables in custorix schema
CREATE OR REPLACE FUNCTION custorix.list_tables() RETURNS TABLE (
    table_name text,
    row_count bigint
) AS $$
DECLARE
    t text;
BEGIN
    FOR t IN (SELECT c.relname
              FROM pg_class c
              JOIN pg_namespace n ON n.oid = c.relnamespace
              WHERE n.nspname = 'custorix' AND c.relkind = 'r')
    LOOP
        table_name := t;
        EXECUTE format('SELECT count(*) FROM custorix.%I', t) INTO row_count;
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Function to list all views in custorix schema
CREATE OR REPLACE FUNCTION custorix.list_views() RETURNS TABLE (
    view_name text
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.relname::text
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'custorix' AND c.relkind = 'v';
END;
$$ LANGUAGE plpgsql;

-- Commit the changes
COMMIT;