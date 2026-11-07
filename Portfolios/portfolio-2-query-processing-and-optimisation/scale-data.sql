-- One-time Portfolio 2 workload data for a fresh miva_bites_query_lab database.
-- Run after Portfolio 1 schema.sql and seed.sql. Do not run on the practice DB.
-- Adds 10,000 completed takeaway orders across both branches over 180 days.
BEGIN;

CREATE TEMP TABLE query_lab_orders ON COMMIT DROP AS
SELECT
    n AS sequence_no,
    (1000 + n)::BIGINT AS order_id,
    CASE WHEN n % 2 = 0 THEN 2 ELSE 1 END::BIGINT AS branch_id,
    CASE WHEN n % 2 = 0 THEN 4 ELSE 1 END::BIGINT AS cashier_id,
    CURRENT_TIMESTAMP
        - (n % 180) * INTERVAL '1 day'
        - (n % 24) * INTERVAL '1 hour' AS opened_at
FROM generate_series(1, 10000) AS generated(n);

INSERT INTO pos_order (
    order_id, branch_id, employee_id, order_type, status, opened_at
) OVERRIDING SYSTEM VALUE
SELECT
    order_id, branch_id, cashier_id, 'TAKEAWAY', 'OPEN', opened_at
FROM query_lab_orders;

SELECT setval(
    pg_get_serial_sequence('pos_order', 'order_id'),
    (SELECT MAX(order_id) FROM pos_order),
    TRUE
);

INSERT INTO order_item (
    order_id, menu_item_id, quantity, sale_unit_price, kitchen_status
)
SELECT
    q.order_id,
    ((q.sequence_no - 1) % 3 + 1)::BIGINT,
    ((q.sequence_no - 1) % 3 + 1)::INTEGER,
    mi.current_price,
    'SERVED'
FROM query_lab_orders AS q
JOIN menu_item AS mi
    ON mi.menu_item_id = ((q.sequence_no - 1) % 3 + 1);

UPDATE pos_order AS o
SET status = 'COMPLETED',
    closed_at = q.opened_at + INTERVAL '20 minutes'
FROM query_lab_orders AS q
WHERE o.order_id = q.order_id;

CREATE TEMP TABLE query_lab_consumption ON COMMIT DROP AS
SELECT
    q.branch_id,
    q.order_id,
    CASE WHEN q.branch_id = 1 THEN 3 ELSE 5 END::BIGINT AS employee_id,
    r.ingredient_id,
    SUM(r.quantity_per_item * oi.quantity)::NUMERIC(14, 3) AS quantity
FROM query_lab_orders AS q
JOIN order_item AS oi
    ON oi.order_id = q.order_id
JOIN recipe AS r
    ON r.menu_item_id = oi.menu_item_id
GROUP BY
    q.branch_id,
    q.order_id,
    CASE WHEN q.branch_id = 1 THEN 3 ELSE 5 END,
    r.ingredient_id;

CREATE TEMP TABLE query_lab_restock ON COMMIT DROP AS
SELECT
    branch_id,
    ingredient_id,
    (SUM(quantity) + 1000.000)::NUMERIC(14, 3) AS quantity
FROM query_lab_consumption
GROUP BY branch_id, ingredient_id;

INSERT INTO stock_movement (
    branch_id, ingredient_id, employee_id, order_id,
    movement_type, quantity_change
)
SELECT
    branch_id,
    ingredient_id,
    CASE WHEN branch_id = 1 THEN 3 ELSE 5 END,
    NULL,
    'RECEIPT',
    quantity
FROM query_lab_restock;

UPDATE inventory AS inv
SET quantity_on_hand = inv.quantity_on_hand + restock.quantity
FROM query_lab_restock AS restock
WHERE inv.branch_id = restock.branch_id
  AND inv.ingredient_id = restock.ingredient_id;

INSERT INTO stock_movement (
    branch_id, ingredient_id, employee_id, order_id,
    movement_type, quantity_change
)
SELECT
    branch_id,
    ingredient_id,
    employee_id,
    order_id,
    'SALE_CONSUMPTION',
    -quantity
FROM query_lab_consumption;

WITH total_consumption AS (
    SELECT branch_id, ingredient_id, SUM(quantity) AS quantity
    FROM query_lab_consumption
    GROUP BY branch_id, ingredient_id
)
UPDATE inventory AS inv
SET quantity_on_hand = inv.quantity_on_hand - consumed.quantity
FROM total_consumption AS consumed
WHERE inv.branch_id = consumed.branch_id
  AND inv.ingredient_id = consumed.ingredient_id;

INSERT INTO payment (
    payment_id, order_id, refund_of_payment_id, payment_type, method,
    amount, status, provider_reference, recorded_at
) OVERRIDING SYSTEM VALUE
SELECT
    q.order_id + 20000,
    q.order_id,
    NULL,
    'PAYMENT',
    'CARD',
    oi.quantity * oi.sale_unit_price,
    'SUCCESSFUL',
    'Q2-PAY-' || q.order_id::TEXT,
    q.opened_at + INTERVAL '5 minutes'
FROM query_lab_orders AS q
JOIN order_item AS oi
    ON oi.order_id = q.order_id;

INSERT INTO payment (
    payment_id, order_id, refund_of_payment_id, payment_type, method,
    amount, status, provider_reference, recorded_at
) OVERRIDING SYSTEM VALUE
SELECT
    q.order_id + 40000,
    q.order_id,
    q.order_id + 20000,
    'REFUND',
    'CARD',
    100.00,
    'SUCCESSFUL',
    'Q2-REF-' || q.order_id::TEXT,
    q.opened_at + INTERVAL '10 minutes'
FROM query_lab_orders AS q
WHERE q.sequence_no % 50 = 0;

SELECT setval(
    pg_get_serial_sequence('payment', 'payment_id'),
    (SELECT MAX(payment_id) FROM payment),
    TRUE
);

ANALYZE pos_order;
ANALYZE order_item;
ANALYZE payment;
ANALYZE stock_movement;
ANALYZE inventory;

COMMIT;
