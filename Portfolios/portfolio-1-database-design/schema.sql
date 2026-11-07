-- Miva Bites Restaurant POS relational schema (PostgreSQL draft)
-- Apply to an empty database. Cross-row workflow rules use triggers or
-- transaction logic as documented in schema-design.md.

CREATE TABLE branch (
    branch_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    address TEXT NOT NULL
);

CREATE TABLE employee (
    employee_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id BIGINT NOT NULL REFERENCES branch (branch_id) ON DELETE RESTRICT,
    full_name VARCHAR(160) NOT NULL,
    role VARCHAR(30) NOT NULL
        CHECK (role IN ('CASHIER', 'KITCHEN', 'STOCK_CLERK', 'MANAGER')),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    -- Required so orders and movements can enforce same-branch membership.
    CONSTRAINT uq_employee_branch_employee UNIQUE (branch_id, employee_id)
);

CREATE TABLE dining_table (
    table_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id BIGINT NOT NULL REFERENCES branch (branch_id) ON DELETE RESTRICT,
    table_number VARCHAR(20) NOT NULL,
    seats SMALLINT NOT NULL CHECK (seats > 0),
    -- Occupancy is derived from open dine-in orders; status is operational.
    status VARCHAR(20) NOT NULL DEFAULT 'AVAILABLE'
        CHECK (status IN ('AVAILABLE', 'OUT_OF_SERVICE')),
    CONSTRAINT uq_dining_table_branch_table UNIQUE (branch_id, table_id),
    CONSTRAINT uq_dining_table_branch_number UNIQUE (branch_id, table_number)
);

CREATE TABLE customer (
    customer_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    full_name VARCHAR(160) NOT NULL,
    phone VARCHAR(30)
);

CREATE TABLE menu_category (
    category_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE menu_item (
    menu_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id BIGINT NOT NULL
        REFERENCES menu_category (category_id) ON DELETE RESTRICT,
    name VARCHAR(120) NOT NULL,
    current_price NUMERIC(12, 2) NOT NULL CHECK (current_price >= 0),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT uq_menu_item_category_name UNIQUE (category_id, name)
);

CREATE TABLE ingredient (
    ingredient_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(120) NOT NULL UNIQUE,
    unit VARCHAR(20) NOT NULL
);

CREATE TABLE recipe (
    menu_item_id BIGINT NOT NULL
        REFERENCES menu_item (menu_item_id) ON DELETE RESTRICT,
    ingredient_id BIGINT NOT NULL
        REFERENCES ingredient (ingredient_id) ON DELETE RESTRICT,
    quantity_per_item NUMERIC(14, 3) NOT NULL
        CHECK (quantity_per_item > 0),
    PRIMARY KEY (menu_item_id, ingredient_id)
);

CREATE TABLE inventory (
    branch_id BIGINT NOT NULL
        REFERENCES branch (branch_id) ON DELETE RESTRICT,
    ingredient_id BIGINT NOT NULL
        REFERENCES ingredient (ingredient_id) ON DELETE RESTRICT,
    quantity_on_hand NUMERIC(14, 3) NOT NULL DEFAULT 0
        CHECK (quantity_on_hand >= 0),
    reorder_level NUMERIC(14, 3) NOT NULL DEFAULT 0
        CHECK (reorder_level >= 0),
    PRIMARY KEY (branch_id, ingredient_id)
);

CREATE TABLE pos_order (
    order_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id BIGINT NOT NULL
        REFERENCES branch (branch_id) ON DELETE RESTRICT,
    employee_id BIGINT NOT NULL,
    customer_id BIGINT
        REFERENCES customer (customer_id) ON DELETE RESTRICT,
    table_id BIGINT,
    order_type VARCHAR(20) NOT NULL
        CHECK (order_type IN ('DINE_IN', 'TAKEAWAY')),
    status VARCHAR(24) NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'PLACED', 'IN_PREPARATION', 'COMPLETED', 'CANCELLED')),
    opened_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMPTZ,
    CONSTRAINT uq_pos_order_branch_order UNIQUE (branch_id, order_id),
    CONSTRAINT fk_pos_order_employee_branch
        FOREIGN KEY (branch_id, employee_id)
        REFERENCES employee (branch_id, employee_id) ON DELETE RESTRICT,
    CONSTRAINT fk_pos_order_table_branch
        FOREIGN KEY (branch_id, table_id)
        REFERENCES dining_table (branch_id, table_id) ON DELETE RESTRICT,
    CONSTRAINT ck_pos_order_table_by_type CHECK (
        (order_type = 'DINE_IN' AND table_id IS NOT NULL)
        OR (order_type = 'TAKEAWAY' AND table_id IS NULL)
    ),
    CONSTRAINT ck_pos_order_closed_after_opened
        CHECK (closed_at IS NULL OR closed_at >= opened_at)
);

CREATE TABLE order_item (
    order_item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL
        REFERENCES pos_order (order_id) ON DELETE RESTRICT,
    menu_item_id BIGINT NOT NULL
        REFERENCES menu_item (menu_item_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    sale_unit_price NUMERIC(12, 2) NOT NULL CHECK (sale_unit_price >= 0),
    kitchen_status VARCHAR(20) NOT NULL DEFAULT 'QUEUED'
        CHECK (kitchen_status IN ('QUEUED', 'PREPARING', 'READY', 'SERVED', 'CANCELLED'))
);

CREATE FUNCTION require_order_items_before_placement()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.status IN ('PLACED', 'IN_PREPARATION', 'COMPLETED')
       AND NOT EXISTS (
           SELECT 1
           FROM order_item
           WHERE order_id = NEW.order_id
       ) THEN
        RAISE EXCEPTION 'Order % must have at least one item before placement', NEW.order_id
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_pos_order_items_on_insert
BEFORE INSERT ON pos_order
FOR EACH ROW
EXECUTE FUNCTION require_order_items_before_placement();

CREATE TRIGGER trg_pos_order_items_on_status_change
BEFORE UPDATE OF status ON pos_order
FOR EACH ROW
EXECUTE FUNCTION require_order_items_before_placement();

CREATE FUNCTION preserve_item_on_submitted_order()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    current_status VARCHAR(24);
    remaining_items BIGINT;
BEGIN
    SELECT status INTO current_status
    FROM pos_order
    WHERE order_id = OLD.order_id;

    IF current_status IS DISTINCT FROM 'OPEN' THEN
        SELECT COUNT(*) INTO remaining_items
        FROM order_item
        WHERE order_id = OLD.order_id;

        IF remaining_items <= 1 THEN
            RAISE EXCEPTION 'Cannot remove the final item from submitted order %', OLD.order_id
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_order_item_preserve_submitted_order
BEFORE DELETE ON order_item
FOR EACH ROW
EXECUTE FUNCTION preserve_item_on_submitted_order();

CREATE TRIGGER trg_order_item_preserve_submitted_order_on_move
BEFORE UPDATE OF order_id ON order_item
FOR EACH ROW
EXECUTE FUNCTION preserve_item_on_submitted_order();

CREATE TABLE payment (
    payment_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id BIGINT NOT NULL
        REFERENCES pos_order (order_id) ON DELETE RESTRICT,
    refund_of_payment_id BIGINT,
    payment_type VARCHAR(12) NOT NULL
        CHECK (payment_type IN ('PAYMENT', 'REFUND')),
    method VARCHAR(20) NOT NULL
        CHECK (method IN ('CASH', 'CARD', 'MOBILE_MONEY', 'BANK_TRANSFER', 'OTHER')),
    amount NUMERIC(12, 2) NOT NULL CHECK (amount > 0),
    status VARCHAR(12) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SUCCESSFUL', 'FAILED', 'CANCELLED')),
    provider_reference VARCHAR(120),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- A refund points to the original charge on the same order.
    CONSTRAINT uq_payment_order_payment UNIQUE (order_id, payment_id),
    CONSTRAINT fk_payment_refund_of_same_order
        FOREIGN KEY (order_id, refund_of_payment_id)
        REFERENCES payment (order_id, payment_id) ON DELETE RESTRICT,
    CONSTRAINT ck_payment_refund_reference CHECK (
        (payment_type = 'PAYMENT' AND refund_of_payment_id IS NULL)
        OR (payment_type = 'REFUND' AND refund_of_payment_id IS NOT NULL)
    ),
    CONSTRAINT ck_payment_not_self_refund
        CHECK (refund_of_payment_id IS NULL OR refund_of_payment_id <> payment_id)
);

CREATE TABLE stock_movement (
    movement_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id BIGINT NOT NULL,
    ingredient_id BIGINT NOT NULL,
    employee_id BIGINT NOT NULL,
    order_id BIGINT,
    movement_type VARCHAR(24) NOT NULL
        CHECK (movement_type IN ('RECEIPT', 'SALE_CONSUMPTION', 'WASTE', 'ADJUSTMENT')),
    quantity_change NUMERIC(14, 3) NOT NULL CHECK (quantity_change <> 0),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_stock_movement_inventory
        FOREIGN KEY (branch_id, ingredient_id)
        REFERENCES inventory (branch_id, ingredient_id) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movement_employee_branch
        FOREIGN KEY (branch_id, employee_id)
        REFERENCES employee (branch_id, employee_id) ON DELETE RESTRICT,
    CONSTRAINT fk_stock_movement_order_branch
        FOREIGN KEY (branch_id, order_id)
        REFERENCES pos_order (branch_id, order_id) ON DELETE RESTRICT,
    CONSTRAINT ck_stock_movement_sign CHECK (
        (movement_type = 'RECEIPT' AND quantity_change > 0)
        OR (movement_type IN ('SALE_CONSUMPTION', 'WASTE') AND quantity_change < 0)
        OR (movement_type = 'ADJUSTMENT' AND quantity_change <> 0)
    ),
    CONSTRAINT ck_sale_consumption_has_order CHECK (
        movement_type <> 'SALE_CONSUMPTION' OR order_id IS NOT NULL
    )
);
