-- Run only in the isolated miva_bites_transaction_lab database.
-- This is repeatable: it restores the demo rows to their fresh-seed values.
BEGIN;

-- Remove this exercise's previous movements and orders before resetting.
DELETE FROM stock_movement
WHERE order_id IN (9001, 9002)
   OR (branch_id = 1 AND ingredient_id = 2
       AND employee_id = 3 AND movement_type = 'RECEIPT'
       AND order_id IS NULL);

DELETE FROM order_item WHERE order_id IN (9001, 9002);
DELETE FROM pos_order WHERE order_id IN (9001, 9002);

-- Restore the balances used in the commit/rollback and concurrency examples.
UPDATE inventory
SET quantity_on_hand = CASE ingredient_id
    WHEN 2 THEN 9700.000
    WHEN 3 THEN 99.500
END
WHERE branch_id = 1 AND ingredient_id IN (2, 3);

INSERT INTO pos_order (
    order_id, branch_id, employee_id, table_id, order_type, status
) OVERRIDING SYSTEM VALUE VALUES
    (9001, 1, 1, NULL, 'TAKEAWAY', 'OPEN'),
    (9002, 1, 1, NULL, 'TAKEAWAY', 'OPEN');

INSERT INTO order_item (
    order_id, menu_item_id, quantity, sale_unit_price
) VALUES
    (9001, 2, 120, 1200.00),
    (9002, 2, 120, 1200.00);

-- Keep future generated order IDs above the two fixed demonstration IDs.
SELECT setval(
    pg_get_serial_sequence('pos_order', 'order_id'),
    (SELECT MAX(order_id) FROM pos_order),
    TRUE
);

-- A small helper row makes transaction snapshots easy to see in two sessions.
CREATE TABLE IF NOT EXISTS portfolio3_isolation_demo (
    demo_id SMALLINT PRIMARY KEY CHECK (demo_id = 1),
    observed_value INTEGER NOT NULL CHECK (observed_value >= 0)
);

INSERT INTO portfolio3_isolation_demo (demo_id, observed_value)
VALUES (1, 100)
ON CONFLICT (demo_id) DO UPDATE
SET observed_value = EXCLUDED.observed_value;

COMMIT;

SELECT 'Lab setup ready' AS setup_result,
       (SELECT quantity_on_hand FROM inventory
        WHERE branch_id = 1 AND ingredient_id = 2) AS ikeja_rice_g,
       (SELECT quantity_on_hand FROM inventory
        WHERE branch_id = 1 AND ingredient_id = 3) AS ikeja_lemons,
       (SELECT COUNT(*) FROM pos_order
        WHERE order_id IN (9001, 9002) AND status = 'OPEN') AS open_demo_orders;
