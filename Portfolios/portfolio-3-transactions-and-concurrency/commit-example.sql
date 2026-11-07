-- Run in miva_bites_transaction_lab after concurrency-setup.sql.
-- The balance update and matching movement become durable together.
BEGIN;

UPDATE inventory
SET quantity_on_hand = quantity_on_hand + 100.000
WHERE branch_id = 1 AND ingredient_id = 2
RETURNING branch_id, ingredient_id, quantity_on_hand;

INSERT INTO stock_movement (
    branch_id, ingredient_id, employee_id, order_id,
    movement_type, quantity_change
) VALUES (
    1, 2, 3, NULL,
    'RECEIPT', 100.000
);

COMMIT;

SELECT i.quantity_on_hand AS rice_balance_g,
       COUNT(sm.movement_id) AS committed_demo_receipts
FROM inventory AS i
LEFT JOIN stock_movement AS sm
  ON sm.branch_id = i.branch_id
 AND sm.ingredient_id = i.ingredient_id
 AND sm.employee_id = 3
 AND sm.movement_type = 'RECEIPT'
 AND sm.order_id IS NULL
WHERE i.branch_id = 1 AND i.ingredient_id = 2
GROUP BY i.quantity_on_hand;
