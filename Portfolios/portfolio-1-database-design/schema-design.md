# Relational Schema and Constraint Review

**Status:** Applied to an isolated PostgreSQL 18 database and validated with fictional seed data. The design remains a draft for review. See [validation output](../../Evidence/portfolio1-validation-output.txt).

## Relationship review

| Relationship | Cardinality | Relational mapping and rule |
|---|---|---|
| Branch–employee | One branch to zero or many employees; each employee belongs to one branch | `employee.branch_id` is required. A composite unique key on `(branch_id, employee_id)` supports branch-consistency checks. |
| Branch–dining table | One branch to zero or many tables; each table belongs to one branch | `dining_table.branch_id` is required; table numbers are unique within a branch. |
| Branch–order | One branch to zero or many orders; each order belongs to one branch | `pos_order.branch_id` is required. |
| Employee–order | One employee to zero or many orders; each order is opened by one employee | Composite FK `(branch_id, employee_id)` ensures the employee works at the order's branch. |
| Customer–order | A customer may have many orders; an order has zero or one customer | Nullable `pos_order.customer_id`; walk-in orders need no customer row. |
| Dining table–order | A table may appear on many historical orders; an order has zero or one table | Nullable `table_id` plus a composite branch/table FK. A `CHECK` requires a table for `DINE_IN` and forbids one for `TAKEAWAY`. |
| Order–order item | One order has one or more items once placed; each item belongs to one order | `order_item.order_id` is required. Database triggers prevent entering a submitted state without an item and prevent deleting the last item from a submitted order. |
| Menu item–order item | A menu item may appear on many order lines; each line names one menu item | `order_item.menu_item_id` is required. `sale_unit_price` snapshots the price charged. |
| Order–payment | One order may have zero or many payment/refund rows; each row belongs to one order | `payment.order_id` is required. Attempts and refunds remain separate rows. |
| Payment–refund | One successful payment may have zero or many refunds; each refund references one original payment | `payment.refund_of_payment_id` is a nullable self-FK. A row-level check requires it for refunds and forbids it for ordinary payment attempts; a composite FK keeps both rows on the same order. |
| Menu category–menu item | One category may contain many items; each item has one category | `menu_item.category_id` is required; item names are unique within a category. |
| Menu item–ingredient | Many-to-many | `recipe` is the junction table, keyed by `(menu_item_id, ingredient_id)`, with the required quantity per item. |
| Branch–ingredient inventory | Many-to-many | `inventory` is keyed by `(branch_id, ingredient_id)` and stores the current balance and reorder level. |
| Inventory–stock movement | One inventory balance has many movement rows; each movement affects one branch/ingredient pair | Composite FK `(branch_id, ingredient_id)` points to `inventory`. Movement rows are append-only audit entries by convention. |
| Employee/order–stock movement | One employee or order may be associated with many movements; each movement has one employee and an optional order | Composite FKs enforce that the employee and optional order belong to the movement's branch. A sale-consumption movement must identify its order. |

The ERD cardinalities are consistent with these rules. The relational design adds composite unique keys on branch-scoped identifiers so PostgreSQL can enforce that orders and stock movements never cross branches.

## Relational mapping

- `BRANCH`(**branch_id**, name, address)
- `EMPLOYEE`(**employee_id**, branch_id FK, full_name, role, active); `UNIQUE (branch_id, employee_id)`
- `DINING_TABLE`(**table_id**, branch_id FK, table_number, seats, status); `UNIQUE (branch_id, table_id)`, `UNIQUE (branch_id, table_number)`
- `CUSTOMER`(**customer_id**, full_name, phone)
- `MENU_CATEGORY`(**category_id**, name)
- `MENU_ITEM`(**menu_item_id**, category_id FK, name, current_price, active); `UNIQUE (category_id, name)`
- `INGREDIENT`(**ingredient_id**, name, unit)
- `RECIPE`(**menu_item_id** FK, **ingredient_id** FK, quantity_per_item); composite primary key `(menu_item_id, ingredient_id)`
- `INVENTORY`(**branch_id** FK, **ingredient_id** FK, quantity_on_hand, reorder_level); composite primary key `(branch_id, ingredient_id)`
- `POS_ORDER`(**order_id**, branch_id FK, employee_id, customer_id FK nullable, table_id nullable, order_type, status, opened_at, closed_at); composite FKs `(branch_id, employee_id)` and `(branch_id, table_id)`; `UNIQUE (branch_id, order_id)`
- `ORDER_ITEM`(**order_item_id**, order_id FK, menu_item_id FK, quantity, sale_unit_price, kitchen_status)
- `PAYMENT`(**payment_id**, order_id FK, refund_of_payment_id FK nullable, payment_type, method, amount, status, provider_reference, recorded_at); `UNIQUE (order_id, payment_id)` supports the same-order refund FK
- `STOCK_MOVEMENT`(**movement_id**, branch_id, ingredient_id, employee_id, order_id nullable, movement_type, quantity_change, recorded_at); composite FKs to inventory, employee, and order

`schema.sql` supplies PostgreSQL types, `NOT NULL` rules, primary/foreign keys, unique constraints, and row-level `CHECK` constraints for these relations.

## Constraint decisions

- All amounts use `NUMERIC(12,2)`; all ingredient quantities use `NUMERIC(14,3)`. Ingredient recipe, inventory, and movement values use the ingredient's canonical unit.
- Prices and reorder levels cannot be negative; order-item quantity and recipe quantity must be positive; inventory balance cannot be negative.
- `quantity_change` is signed: receipts are positive, sale consumption and waste are negative, and adjustments may be either sign.
- Dine-in orders require a table from the same branch. Takeaway orders must not reference a table.
- Table occupancy is derived from active dine-in orders. `dining_table.status` only tracks operational availability (`AVAILABLE` or `OUT_OF_SERVICE`) to avoid keeping two competing occupancy states.
- Order totals are derived from order items; the sale-time unit price is retained on each item so later menu price changes do not alter history.
- Refund rows point to the original payment attempt on the same order. A refund may be partial, so the original payment can have multiple refund rows.
- The current menu catalogue and price are shared across both branches in this draft. Branch inventory and sales remain separate. If branches need different prices or item availability, add a `BRANCH_MENU_ITEM` relation rather than putting branch-specific values into `MENU_ITEM`.
- Deletes are restricted for records referenced by sales, recipes, inventory, or audit history. Menu items and employees can be deactivated instead of deleting historical records.

## Normalization notes

- **1NF:** Each column stores one value. Order lines, recipe ingredients, payments, and stock movements are separate rows rather than lists embedded in an order or menu item.
- **2NF:** The non-key recipe quantity depends on the full `(menu_item_id, ingredient_id)` key. An inventory balance depends on the full `(branch_id, ingredient_id)` key.
- **3NF:** Branch, customer, category, menu item, ingredient, and employee details live in their own relations. For example, category names are stored once in `MENU_CATEGORY`, not repeated on every order line.
- `ORDER_ITEM.sale_unit_price` is a historical snapshot, not a duplicate of today's `MENU_ITEM.current_price`. `INVENTORY.quantity_on_hand` is a maintained balance for operational use and must be changed in the same transaction as its movement ledger row.

## Rules that need transaction logic

These multi-row rules need triggers or transaction logic:

1. **Implemented in the DDL:** an order must have at least one `ORDER_ITEM` before it changes from `OPEN` to `PLACED`, `IN_PREPARATION`, or `COMPLETED`. The triggers also preserve at least one line on submitted orders.
2. A stock decrement must lock or conditionally update the `INVENTORY` row, reject a negative result, and insert its `STOCK_MOVEMENT` row in the same transaction. The `CHECK` on the balance protects the stored row, while locking prevents concurrent overselling.
3. A refund must point to a successful original payment, and cumulative successful refunds must not exceed that payment's amount. The self-FK checks that both rows belong to the same order; the successful-payment and refund-total rules need transaction logic. An order may be completed only when successful payments less successful refunds equal the derived order total.

## Working assumptions

1. Both branches share a menu and current prices.
2. Each employee is assigned to one branch at a time.
3. One role is stored per employee in this first version.
4. Quantities are expressed in one canonical unit per ingredient; unit conversions are outside the initial scope.
5. Walk-in customers are optional, and sample customer data will be fictional.
