
BEGIN;

CREATE SCHEMA IF NOT EXISTS hr_core;
SET search_path TO hr_core, public;

-- ============================================================
-- 1. USERS MANAGEMENT (RBAC)
-- ============================================================

CREATE TABLE enterprises (
    enterprise_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    company_name   VARCHAR(200) NOT NULL,
    company_email  VARCHAR(255) NOT NULL,
    tax_number     VARCHAR(80),
    company_address TEXT,
    status         VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_enterprises_status
        CHECK (status IN ('active', 'pending', 'suspended', 'inactive'))
);

CREATE UNIQUE INDEX uq_enterprises_company_email_lower
    ON enterprises (LOWER(company_email));

CREATE TABLE users (
    user_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id  BIGINT NOT NULL,
    full_name      VARCHAR(200) NOT NULL,
    email          VARCHAR(255) NOT NULL,
    password_hash  TEXT NOT NULL,
    status         VARCHAR(20) NOT NULL DEFAULT 'active',
    last_login     TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_users_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_users_user_enterprise
        UNIQUE (user_id, enterprise_id),
    CONSTRAINT chk_users_status
        CHECK (status IN ('active', 'pending', 'locked', 'inactive'))
);

CREATE UNIQUE INDEX uq_users_enterprise_email_lower
    ON users (enterprise_id, LOWER(email));
CREATE INDEX ix_users_enterprise_id ON users (enterprise_id);

CREATE TABLE roles (
    role_id        BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id  BIGINT NOT NULL,
    role_name      VARCHAR(100) NOT NULL,
    description    TEXT,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_roles_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_roles_role_enterprise
        UNIQUE (role_id, enterprise_id),
    CONSTRAINT uq_roles_enterprise_name
        UNIQUE (enterprise_id, role_name)
);

CREATE TABLE permissions (
    permission_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    permission_name VARCHAR(120) NOT NULL,
    module          VARCHAR(40) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_permissions_module
        CHECK (module IN ('users_management', 'hr', 'payroll')),
    CONSTRAINT uq_permissions_module_name
        UNIQUE (module, permission_name)
);

-- enterprise_id is included here to enforce that the user and role
-- assigned to one another belong to the same enterprise.
CREATE TABLE user_roles (
    user_role_id  BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id BIGINT NOT NULL,
    user_id       BIGINT NOT NULL,
    role_id       BIGINT NOT NULL,
    assigned_at   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_user_roles_user_enterprise
        FOREIGN KEY (user_id, enterprise_id)
        REFERENCES users (user_id, enterprise_id),
    CONSTRAINT fk_user_roles_role_enterprise
        FOREIGN KEY (role_id, enterprise_id)
        REFERENCES roles (role_id, enterprise_id),
    CONSTRAINT uq_user_roles_assignment
        UNIQUE (user_id, role_id)
);

CREATE INDEX ix_user_roles_enterprise_id ON user_roles (enterprise_id);
CREATE INDEX ix_user_roles_role_id ON user_roles (role_id);

CREATE TABLE role_permissions (
    role_permission_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    role_id            BIGINT NOT NULL,
    permission_id      BIGINT NOT NULL,
    created_at         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_role_permissions_role
        FOREIGN KEY (role_id)
        REFERENCES roles (role_id),
    CONSTRAINT fk_role_permissions_permission
        FOREIGN KEY (permission_id)
        REFERENCES permissions (permission_id),
    CONSTRAINT uq_role_permissions_assignment
        UNIQUE (role_id, permission_id)
);

CREATE INDEX ix_role_permissions_permission_id
    ON role_permissions (permission_id);

-- ============================================================
-- 2. HR MODULE
-- ============================================================

CREATE TABLE departments (
    department_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id   BIGINT NOT NULL,
    department_name VARCHAR(150) NOT NULL,
    description     TEXT,
    status          VARCHAR(20) NOT NULL DEFAULT 'active',
    created_at      TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_departments_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_departments_id_enterprise
        UNIQUE (department_id, enterprise_id),
    CONSTRAINT chk_departments_status
        CHECK (status IN ('active', 'inactive'))
);

CREATE UNIQUE INDEX uq_departments_enterprise_name_lower
    ON departments (enterprise_id, LOWER(department_name));

CREATE TABLE positions (
    position_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id BIGINT NOT NULL,
    position_name VARCHAR(150) NOT NULL,
    description   TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_positions_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_positions_id_enterprise
        UNIQUE (position_id, enterprise_id)
);

CREATE UNIQUE INDEX uq_positions_enterprise_name_lower
    ON positions (enterprise_id, LOWER(position_name));

CREATE TABLE employees (
    employee_id       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id     BIGINT NOT NULL,
    user_id           BIGINT,
    department_id     BIGINT NOT NULL,
    position_id       BIGINT NOT NULL,
    employee_number   VARCHAR(60) NOT NULL,
    first_name        VARCHAR(100) NOT NULL,
    last_name         VARCHAR(100),
    date_of_birth     DATE,
    hire_date         DATE NOT NULL,
    employment_status VARCHAR(25) NOT NULL DEFAULT 'active',
    employment_type   VARCHAR(25) NOT NULL DEFAULT 'permanent',
    base_salary       NUMERIC(15,2) NOT NULL DEFAULT 0,
    bank_account      VARCHAR(100),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_employees_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT fk_employees_user_enterprise
        FOREIGN KEY (user_id, enterprise_id)
        REFERENCES users (user_id, enterprise_id),
    CONSTRAINT fk_employees_department_enterprise
        FOREIGN KEY (department_id, enterprise_id)
        REFERENCES departments (department_id, enterprise_id),
    CONSTRAINT fk_employees_position_enterprise
        FOREIGN KEY (position_id, enterprise_id)
        REFERENCES positions (position_id, enterprise_id),
    CONSTRAINT uq_employees_id_enterprise
        UNIQUE (employee_id, enterprise_id),
    CONSTRAINT uq_employees_number_enterprise
        UNIQUE (enterprise_id, employee_number),
    CONSTRAINT uq_employees_user_enterprise
        UNIQUE (enterprise_id, user_id),
    CONSTRAINT chk_employees_base_salary
        CHECK (base_salary >= 0),
    CONSTRAINT chk_employees_employment_status
        CHECK (employment_status IN ('active', 'on_leave', 'terminated', 'resigned')),
    CONSTRAINT chk_employees_employment_type
        CHECK (employment_type IN ('permanent', 'contract', 'intern', 'part_time', 'temporary')),
    CONSTRAINT chk_employees_hire_date
        CHECK (date_of_birth IS NULL OR date_of_birth <= hire_date)
);

CREATE INDEX ix_employees_enterprise_id ON employees (enterprise_id);
CREATE INDEX ix_employees_department_id ON employees (department_id);
CREATE INDEX ix_employees_position_id ON employees (position_id);
CREATE INDEX ix_employees_name ON employees (last_name, first_name);

-- ============================================================
-- 3. PAYROLL MODULE
-- ============================================================

CREATE TABLE payroll_periods (
    period_id     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id BIGINT NOT NULL,
    period_name   VARCHAR(100) NOT NULL,
    start_date    DATE NOT NULL,
    end_date      DATE NOT NULL,
    payment_date  DATE,
    status        VARCHAR(20) NOT NULL DEFAULT 'open',
    created_at    TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_periods_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_payroll_periods_id_enterprise
        UNIQUE (period_id, enterprise_id),
    CONSTRAINT uq_payroll_periods_enterprise_name
        UNIQUE (enterprise_id, period_name),
    CONSTRAINT chk_payroll_periods_dates
        CHECK (start_date <= end_date),
    CONSTRAINT chk_payroll_periods_payment_date
        CHECK (payment_date IS NULL OR payment_date >= start_date),
    CONSTRAINT chk_payroll_periods_status
        CHECK (status IN ('open', 'processing', 'closed', 'cancelled'))
);

CREATE INDEX ix_payroll_periods_enterprise_dates
    ON payroll_periods (enterprise_id, start_date, end_date);

CREATE TABLE payroll_components (
    component_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id  BIGINT NOT NULL,
    component_name VARCHAR(120) NOT NULL,
    component_type VARCHAR(20) NOT NULL,
    description    TEXT,
    is_active      BOOLEAN NOT NULL DEFAULT TRUE,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_components_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_payroll_components_id_enterprise
        UNIQUE (component_id, enterprise_id),
    CONSTRAINT uq_payroll_components_name_type
        UNIQUE (enterprise_id, component_name, component_type),
    CONSTRAINT chk_payroll_components_type
        CHECK (component_type IN ('earning', 'deduction'))
);

CREATE TABLE payroll_runs (
    payroll_run_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id  BIGINT NOT NULL,
    period_id      BIGINT NOT NULL,
    processed_by   BIGINT,
    run_number     VARCHAR(60) NOT NULL,
    total_gross    NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_deduction NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_net      NUMERIC(15,2) NOT NULL DEFAULT 0,
    status         VARCHAR(25) NOT NULL DEFAULT 'draft',
    processed_at   TIMESTAMPTZ,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_runs_period_enterprise
        FOREIGN KEY (period_id, enterprise_id)
        REFERENCES payroll_periods (period_id, enterprise_id),
    CONSTRAINT fk_payroll_runs_processor_enterprise
        FOREIGN KEY (processed_by, enterprise_id)
        REFERENCES users (user_id, enterprise_id),
    CONSTRAINT fk_payroll_runs_enterprise
        FOREIGN KEY (enterprise_id)
        REFERENCES enterprises (enterprise_id),
    CONSTRAINT uq_payroll_runs_id_enterprise
        UNIQUE (payroll_run_id, enterprise_id),
    CONSTRAINT uq_payroll_runs_number_enterprise
        UNIQUE (enterprise_id, run_number),
    CONSTRAINT chk_payroll_runs_amounts
        CHECK (total_gross >= 0 AND total_deduction >= 0 AND total_net >= 0),
    CONSTRAINT chk_payroll_runs_status
        CHECK (status IN ('draft', 'processing', 'review', 'approved', 'paid', 'cancelled'))
);

CREATE INDEX ix_payroll_runs_enterprise_period
    ON payroll_runs (enterprise_id, period_id);
CREATE INDEX ix_payroll_runs_status
    ON payroll_runs (enterprise_id, status);

-- enterprise_id is repeated on payroll_records and payroll_items so
-- composite foreign keys can guarantee tenant consistency.
CREATE TABLE payroll_records (
    payroll_record_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id     BIGINT NOT NULL,
    payroll_run_id    BIGINT NOT NULL,
    employee_id       BIGINT NOT NULL,
    gross_salary      NUMERIC(15,2) NOT NULL DEFAULT 0,
    total_deduction   NUMERIC(15,2) NOT NULL DEFAULT 0,
    net_salary        NUMERIC(15,2) NOT NULL DEFAULT 0,
    payment_status    VARCHAR(20) NOT NULL DEFAULT 'pending',
    payment_date      DATE,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_records_run_enterprise
        FOREIGN KEY (payroll_run_id, enterprise_id)
        REFERENCES payroll_runs (payroll_run_id, enterprise_id),
    CONSTRAINT fk_payroll_records_employee_enterprise
        FOREIGN KEY (employee_id, enterprise_id)
        REFERENCES employees (employee_id, enterprise_id),
    CONSTRAINT uq_payroll_records_id_enterprise
        UNIQUE (payroll_record_id, enterprise_id),
    CONSTRAINT uq_payroll_records_run_employee
        UNIQUE (payroll_run_id, employee_id),
    CONSTRAINT chk_payroll_records_amounts
        CHECK (gross_salary >= 0 AND total_deduction >= 0 AND net_salary >= 0),
    CONSTRAINT chk_payroll_records_payment_status
        CHECK (payment_status IN ('pending', 'processing', 'paid', 'failed', 'on_hold'))
);

CREATE INDEX ix_payroll_records_enterprise_run
    ON payroll_records (enterprise_id, payroll_run_id);
CREATE INDEX ix_payroll_records_employee
    ON payroll_records (employee_id);
CREATE INDEX ix_payroll_records_payment_status
    ON payroll_records (enterprise_id, payment_status);

CREATE TABLE payroll_items (
    payroll_item_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id    BIGINT NOT NULL,
    payroll_record_id BIGINT NOT NULL,
    component_id      BIGINT NOT NULL,
    amount            NUMERIC(15,2) NOT NULL,
    description       TEXT,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_items_record_enterprise
        FOREIGN KEY (payroll_record_id, enterprise_id)
        REFERENCES payroll_records (payroll_record_id, enterprise_id),
    CONSTRAINT fk_payroll_items_component_enterprise
        FOREIGN KEY (component_id, enterprise_id)
        REFERENCES payroll_components (component_id, enterprise_id),
    CONSTRAINT chk_payroll_items_amount
        CHECK (amount >= 0)
);

CREATE INDEX ix_payroll_items_record
    ON payroll_items (payroll_record_id);
CREATE INDEX ix_payroll_items_component
    ON payroll_items (component_id);

CREATE TABLE payroll_milestones (
    milestone_id   BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    enterprise_id  BIGINT NOT NULL,
    payroll_run_id BIGINT NOT NULL,
    assigned_to    BIGINT,
    milestone_name VARCHAR(150) NOT NULL,
    description    TEXT,
    due_date       DATE,
    completed_at   TIMESTAMPTZ,
    status         VARCHAR(20) NOT NULL DEFAULT 'pending',
    sequence_order INTEGER NOT NULL DEFAULT 1,
    created_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_payroll_milestones_run_enterprise
        FOREIGN KEY (payroll_run_id, enterprise_id)
        REFERENCES payroll_runs (payroll_run_id, enterprise_id),
    CONSTRAINT fk_payroll_milestones_assignee_enterprise
        FOREIGN KEY (assigned_to, enterprise_id)
        REFERENCES users (user_id, enterprise_id),
    CONSTRAINT chk_payroll_milestones_status
        CHECK (status IN ('pending', 'in_progress', 'completed', 'blocked', 'skipped')),
    CONSTRAINT chk_payroll_milestones_sequence
        CHECK (sequence_order > 0)
);

CREATE INDEX ix_payroll_milestones_run_order
    ON payroll_milestones (payroll_run_id, sequence_order);
CREATE INDEX ix_payroll_milestones_assignee_status
    ON payroll_milestones (enterprise_id, assigned_to, status);

-- ============================================================
-- 4. VIEWS FOR THE REQUIRED HR-CORE PAGES
-- ============================================================

-- Employee List page
CREATE OR REPLACE VIEW v_hr_employee_list AS
SELECT
    e.employee_id,
    e.enterprise_id,
    e.employee_number,
    e.first_name,
    e.last_name,
    CONCAT_WS(' ', e.first_name, e.last_name) AS employee_name,
    COALESCE(u.email, '') AS login_email,
    d.department_id,
    d.department_name,
    p.position_id,
    p.position_name,
    e.hire_date,
    e.employment_type,
    e.employment_status,
    e.created_at
FROM employees e
JOIN departments d
  ON d.department_id = e.department_id
 AND d.enterprise_id = e.enterprise_id
JOIN positions p
  ON p.position_id = e.position_id
 AND p.enterprise_id = e.enterprise_id
LEFT JOIN users u
  ON u.user_id = e.user_id
 AND u.enterprise_id = e.enterprise_id;

-- Payroll Hub page: one row per payroll run, with employee/payment counts
CREATE OR REPLACE VIEW v_payroll_hub AS
SELECT
    prun.payroll_run_id,
    prun.enterprise_id,
    pp.period_id,
    pp.period_name,
    pp.start_date,
    pp.end_date,
    pp.payment_date AS scheduled_payment_date,
    prun.run_number,
    prun.status AS payroll_status,
    prun.total_gross,
    prun.total_deduction,
    prun.total_net,
    COUNT(prec.payroll_record_id) AS employee_count,
    COUNT(prec.payroll_record_id)
        FILTER (WHERE prec.payment_status = 'paid') AS paid_count,
    COUNT(prec.payroll_record_id)
        FILTER (WHERE prec.payment_status IN ('pending', 'processing')) AS unpaid_or_processing_count,
    COUNT(prec.payroll_record_id)
        FILTER (WHERE prec.payment_status = 'failed') AS failed_payment_count,
    prun.processed_at,
    prun.created_at
FROM payroll_runs prun
JOIN payroll_periods pp
  ON pp.period_id = prun.period_id
 AND pp.enterprise_id = prun.enterprise_id
LEFT JOIN payroll_records prec
  ON prec.payroll_run_id = prun.payroll_run_id
 AND prec.enterprise_id = prun.enterprise_id
GROUP BY
    prun.payroll_run_id,
    prun.enterprise_id,
    pp.period_id,
    pp.period_name,
    pp.start_date,
    pp.end_date,
    pp.payment_date,
    prun.run_number,
    prun.status,
    prun.total_gross,
    prun.total_deduction,
    prun.total_net,
    prun.processed_at,
    prun.created_at;

CREATE OR REPLACE VIEW v_payroll_milestone_admin AS
SELECT
    pm.milestone_id,
    pm.enterprise_id,
    pm.payroll_run_id,
    prun.run_number,
    pp.period_name,
    pm.milestone_name,
    pm.description,
    pm.sequence_order,
    pm.due_date,
    pm.status AS milestone_status,
    pm.assigned_to,
    u.full_name AS assigned_user_name,
    u.email AS assigned_user_email,
    pm.completed_at,
    prun.status AS payroll_status
FROM payroll_milestones pm
JOIN payroll_runs prun
  ON prun.payroll_run_id = pm.payroll_run_id
 AND prun.enterprise_id = pm.enterprise_id
JOIN payroll_periods pp
  ON pp.period_id = prun.period_id
 AND pp.enterprise_id = prun.enterprise_id
LEFT JOIN users u
  ON u.user_id = pm.assigned_to
 AND u.enterprise_id = pm.enterprise_id;


CREATE OR REPLACE VIEW v_enterprise_login_context AS
SELECT
    u.user_id,
    u.enterprise_id,
    u.full_name,
    u.email,
    u.status AS user_status,
    e.company_name,
    e.status AS enterprise_status,
    u.last_login
FROM users u
JOIN enterprises e
  ON e.enterprise_id = u.enterprise_id;

-- RBAC helper view: effective permissions assigned to each user.
CREATE OR REPLACE VIEW v_user_effective_permissions AS
SELECT DISTINCT
    ur.enterprise_id,
    u.user_id,
    u.email,
    r.role_id,
    r.role_name,
    p.permission_id,
    p.permission_name,
    p.module
FROM user_roles ur
JOIN users u
  ON u.user_id = ur.user_id
 AND u.enterprise_id = ur.enterprise_id
JOIN roles r
  ON r.role_id = ur.role_id
 AND r.enterprise_id = ur.enterprise_id
JOIN role_permissions rp
  ON rp.role_id = r.role_id
JOIN permissions p
  ON p.permission_id = rp.permission_id;

COMMIT;