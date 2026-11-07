-- Fictional sample data for the Miva Bites Portfolio 1 schema.
-- Fixed IDs make the relationships easy to follow in coursework evidence.
BEGIN;

INSERT INTO branch (branch_id, name, address) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Miva Bites Ikeja', '12 Fictional Market Road, Ikeja'),
    (2, 'Miva Bites Lekki', '8 Example Avenue, Lekki');

INSERT INTO employee (employee_id, branch_id, full_name, role) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Tomi Example', 'CASHIER'),
    (2, 1, 'Kemi Sample', 'KITCHEN'),
    (3, 1, 'Bola Demo', 'STOCK_CLERK'),
    (4, 2, 'Seyi Example', 'CASHIER'),
    (5, 2, 'Dele Sample', 'STOCK_CLERK');

INSERT INTO dining_table (table_id, branch_id, table_number, seats) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'A1', 4),
    (2, 2, 'B1', 2);

INSERT INTO customer (customer_id, full_name, phone) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Ada Example', '08000000001');

INSERT INTO menu_category (category_id, name) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Meals'),
    (2, 'Drinks');

INSERT INTO menu_item (menu_item_id, category_id, name, current_price) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 'Grilled Chicken Bowl', 6800.00),
    (2, 2, 'Fresh Lemonade', 1200.00),
    (3, 1, 'Jollof Rice', 2500.00);

INSERT INTO ingredient (ingredient_id, name, unit) OVERRIDING SYSTEM VALUE VALUES
    (1, 'Chicken', 'g'),
    (2, 'Rice', 'g'),
    (3, 'Lemon', 'each'),
    (4, 'Palm Oil', 'ml'),
    (5, 'Water', 'ml');

INSERT INTO recipe (menu_item_id, ingredient_id, quantity_per_item) VALUES
    (1, 1, 250.000), (1, 2, 150.000), (1, 4, 15.000),
    (2, 3, 0.500), (2, 5, 250.000),
    (3, 2, 200.000), (3, 4, 20.000);

INSERT INTO inventory (branch_id, ingredient_id, quantity_on_hand, reorder_level) VALUES
    (1, 1, 9500.000, 2000.000),
    (1, 2, 9700.000, 2000.000),
    (1, 3, 99.500, 20.000),
    (1, 4, 4970.000, 1000.000),
    (1, 5, 49750.000, 10000.000),
    (2, 1, 5000.000, 1500.000),
    (2, 2, 5000.000, 1500.000),
    (2, 3, 50.000, 15.000),
    (2, 4, 2000.000, 500.000),
    (2, 5, 25000.000, 5000.000);

INSERT INTO pos_order (
    order_id, branch_id, employee_id, customer_id, table_id,
    order_type, status, opened_at
) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 1, 1, 1, 'DINE_IN', 'OPEN', CURRENT_TIMESTAMP - INTERVAL '30 minutes'),
    (2, 2, 4, NULL, NULL, 'TAKEAWAY', 'OPEN', CURRENT_TIMESTAMP);

INSERT INTO order_item (
    order_item_id, order_id, menu_item_id, quantity, sale_unit_price, kitchen_status
) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 1, 2, 6800.00, 'PREPARING'),
    (2, 1, 2, 1, 1200.00, 'QUEUED');

UPDATE pos_order SET status = 'IN_PREPARATION' WHERE order_id = 1;

INSERT INTO payment (
    payment_id, order_id, refund_of_payment_id, payment_type, method, amount, status, provider_reference
) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, NULL, 'PAYMENT', 'CARD', 14800.00, 'SUCCESSFUL', 'SIM-PAY-0001');

INSERT INTO payment (
    payment_id, order_id, refund_of_payment_id, payment_type, method, amount, status, provider_reference
) OVERRIDING SYSTEM VALUE VALUES
    (2, 1, 1, 'REFUND', 'CARD', 500.00, 'SUCCESSFUL', 'SIM-REF-0001'),
    (3, 2, NULL, 'PAYMENT', 'CASH', 2500.00, 'FAILED', 'SIM-PAY-0002');

-- Opening balances and the example order's recipe consumption reconcile to INVENTORY.
INSERT INTO stock_movement (
    movement_id, branch_id, ingredient_id, employee_id, order_id,
    movement_type, quantity_change
) OVERRIDING SYSTEM VALUE VALUES
    (1, 1, 1, 3, NULL, 'ADJUSTMENT', 10000.000),
    (2, 1, 2, 3, NULL, 'ADJUSTMENT', 10000.000),
    (3, 1, 3, 3, NULL, 'ADJUSTMENT', 100.000),
    (4, 1, 4, 3, NULL, 'ADJUSTMENT', 5000.000),
    (5, 1, 5, 3, NULL, 'ADJUSTMENT', 50000.000),
    (6, 2, 1, 5, NULL, 'ADJUSTMENT', 5000.000),
    (7, 2, 2, 5, NULL, 'ADJUSTMENT', 5000.000),
    (8, 2, 3, 5, NULL, 'ADJUSTMENT', 50.000),
    (9, 2, 4, 5, NULL, 'ADJUSTMENT', 2000.000),
    (10, 2, 5, 5, NULL, 'ADJUSTMENT', 25000.000),
    (11, 1, 1, 2, 1, 'SALE_CONSUMPTION', -500.000),
    (12, 1, 2, 2, 1, 'SALE_CONSUMPTION', -300.000),
    (13, 1, 3, 2, 1, 'SALE_CONSUMPTION', -0.500),
    (14, 1, 4, 2, 1, 'SALE_CONSUMPTION', -30.000),
    (15, 1, 5, 2, 1, 'SALE_CONSUMPTION', -250.000);

SELECT setval(pg_get_serial_sequence('branch', 'branch_id'), (SELECT MAX(branch_id) FROM branch), TRUE);
SELECT setval(pg_get_serial_sequence('employee', 'employee_id'), (SELECT MAX(employee_id) FROM employee), TRUE);
SELECT setval(pg_get_serial_sequence('dining_table', 'table_id'), (SELECT MAX(table_id) FROM dining_table), TRUE);
SELECT setval(pg_get_serial_sequence('customer', 'customer_id'), (SELECT MAX(customer_id) FROM customer), TRUE);
SELECT setval(pg_get_serial_sequence('menu_category', 'category_id'), (SELECT MAX(category_id) FROM menu_category), TRUE);
SELECT setval(pg_get_serial_sequence('menu_item', 'menu_item_id'), (SELECT MAX(menu_item_id) FROM menu_item), TRUE);
SELECT setval(pg_get_serial_sequence('ingredient', 'ingredient_id'), (SELECT MAX(ingredient_id) FROM ingredient), TRUE);
SELECT setval(pg_get_serial_sequence('pos_order', 'order_id'), (SELECT MAX(order_id) FROM pos_order), TRUE);
SELECT setval(pg_get_serial_sequence('order_item', 'order_item_id'), (SELECT MAX(order_item_id) FROM order_item), TRUE);
SELECT setval(pg_get_serial_sequence('payment', 'payment_id'), (SELECT MAX(payment_id) FROM payment), TRUE);
SELECT setval(pg_get_serial_sequence('stock_movement', 'movement_id'), (SELECT MAX(movement_id) FROM stock_movement), TRUE);

COMMIT;
