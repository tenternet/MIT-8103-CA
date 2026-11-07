-- Reproducible checks for schema.sql + seed.sql.
-- Run after both files against a dedicated, empty Miva Bites database.

SELECT b.name AS branch,
       COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT oi.order_item_id) AS order_items
FROM branch AS b
LEFT JOIN pos_order AS o ON o.branch_id = b.branch_id
LEFT JOIN order_item AS oi ON oi.order_id = o.order_id
GROUP BY b.branch_id, b.name
ORDER BY b.branch_id;

WITH order_totals AS (
    SELECT order_id, SUM(quantity * sale_unit_price) AS order_total
    FROM order_item
    GROUP BY order_id
), payment_totals AS (
    SELECT order_id,
           SUM(amount) FILTER (WHERE payment_type = 'PAYMENT' AND status = 'SUCCESSFUL')
           - COALESCE(SUM(amount) FILTER (WHERE payment_type = 'REFUND' AND status = 'SUCCESSFUL'), 0)
             AS net_successful_payments
    FROM payment
    GROUP BY order_id
)
SELECT o.order_id, ot.order_total, pt.net_successful_payments
FROM pos_order AS o
JOIN order_totals AS ot USING (order_id)
LEFT JOIN payment_totals AS pt USING (order_id)
WHERE o.order_id = 1;

SELECT i.branch_id, ing.name, i.quantity_on_hand,
       SUM(sm.quantity_change) AS ledger_balance
FROM inventory AS i
JOIN ingredient AS ing ON ing.ingredient_id = i.ingredient_id
JOIN stock_movement AS sm
  ON sm.branch_id = i.branch_id AND sm.ingredient_id = i.ingredient_id
GROUP BY i.branch_id, i.ingredient_id, ing.name, i.quantity_on_hand
ORDER BY i.branch_id, i.ingredient_id;

DO $$
DECLARE
    temporary_order_id BIGINT;
    temporary_item_id BIGINT;
BEGIN
    IF (SELECT COUNT(*) FROM branch) <> 2
       OR (SELECT COUNT(*) FROM pos_order) <> 2
       OR (SELECT COUNT(*) FROM order_item) <> 2
       OR (SELECT COUNT(*) FROM payment) <> 3 THEN
        RAISE EXCEPTION 'Seed-data row-count assertion failed';
    END IF;
    IF EXISTS (
        SELECT 1
        FROM inventory AS i
        JOIN stock_movement AS sm
          ON sm.branch_id = i.branch_id AND sm.ingredient_id = i.ingredient_id
        GROUP BY i.branch_id, i.ingredient_id, i.quantity_on_hand
        HAVING SUM(sm.quantity_change) <> i.quantity_on_hand
    ) THEN
        RAISE EXCEPTION 'Inventory and movement-ledger balances differ';
    END IF;
    BEGIN
        INSERT INTO pos_order (branch_id, employee_id, order_type)
        VALUES (1, 4, 'TAKEAWAY');
        RAISE EXCEPTION 'Expected rejection for an employee from another branch';
    EXCEPTION WHEN foreign_key_violation THEN
    END;

    BEGIN
        INSERT INTO pos_order (branch_id, employee_id, order_type)
        VALUES (1, 1, 'DINE_IN');
        RAISE EXCEPTION 'Expected rejection for dine-in order without a table';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO pos_order (branch_id, employee_id, table_id, order_type)
        VALUES (1, 1, 1, 'TAKEAWAY');
        RAISE EXCEPTION 'Expected rejection for takeaway order with a table';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO pos_order (branch_id, employee_id, order_type, status)
        VALUES (1, 1, 'TAKEAWAY', 'PLACED');
        RAISE EXCEPTION 'Expected rejection for placing an empty order';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO pos_order (branch_id, employee_id, order_type)
        VALUES (2, 4, 'TAKEAWAY')
        RETURNING order_id INTO temporary_order_id;
        INSERT INTO order_item (order_id, menu_item_id, quantity, sale_unit_price)
        VALUES (temporary_order_id, 3, 1, 2500.00)
        RETURNING order_item_id INTO temporary_item_id;
        UPDATE pos_order SET status = 'PLACED' WHERE order_id = temporary_order_id;
        DELETE FROM order_item WHERE order_item_id = temporary_item_id;
        RAISE EXCEPTION 'Expected rejection for deleting the final item on a placed order';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO payment (order_id, payment_type, method, amount)
        VALUES (1, 'REFUND', 'CARD', 1.00);
        RAISE EXCEPTION 'Expected rejection for refund without original payment';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO payment (order_id, refund_of_payment_id, payment_type, method, amount)
        VALUES (2, 1, 'REFUND', 'CARD', 1.00);
        RAISE EXCEPTION 'Expected rejection for refund linked across orders';
    EXCEPTION WHEN foreign_key_violation THEN
    END;

    BEGIN
        UPDATE inventory SET quantity_on_hand = -1
        WHERE branch_id = 1 AND ingredient_id = 1;
        RAISE EXCEPTION 'Expected rejection for negative inventory';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO stock_movement (
            branch_id, ingredient_id, employee_id, movement_type, quantity_change
        ) VALUES (1, 1, 3, 'SALE_CONSUMPTION', -1.000);
        RAISE EXCEPTION 'Expected rejection for sale consumption without order';
    EXCEPTION WHEN check_violation THEN
    END;

    BEGIN
        INSERT INTO stock_movement (
            branch_id, ingredient_id, employee_id, movement_type, quantity_change
        ) VALUES (1, 1, 5, 'ADJUSTMENT', 1.000);
        RAISE EXCEPTION 'Expected rejection for movement by another branch employee';
    EXCEPTION WHEN foreign_key_violation THEN
    END;
END;
$$;

SELECT result AS validation_result
FROM (VALUES
    ('PASS: seed rows and relationships are present'),
    ('PASS: inventory balances reconcile to stock movements'),
    ('PASS: an order cannot use an employee from another branch'),
    ('PASS: dine-in order requires a table'),
    ('PASS: takeaway order cannot use a dining table'),
    ('PASS: an order cannot be placed without an order item'),
    ('PASS: a placed order retains at least one item'),
    ('PASS: a refund must identify its original payment'),
    ('PASS: refund and original payment must belong to the same order'),
    ('PASS: inventory balance cannot be negative'),
    ('PASS: sale-consumption movement requires an order'),
    ('PASS: stock movement cannot use another branch employee')
) AS results(result);
