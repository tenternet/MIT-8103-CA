-- Session A, run after Session B has started its competing UPDATE.
-- The movement, order status, and stock balance are committed together.
INSERT INTO stock_movement (
    branch_id, ingredient_id, employee_id, order_id,
    movement_type, quantity_change
) VALUES (
    1, 3, 2, 9001,
    'SALE_CONSUMPTION', -60.000
);

UPDATE pos_order
SET status = 'IN_PREPARATION'
WHERE order_id = 9001 AND status = 'OPEN';

COMMIT;
