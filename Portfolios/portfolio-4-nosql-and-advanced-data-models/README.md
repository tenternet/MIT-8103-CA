# Portfolio 4: NoSQL and Advanced Data Models

**Status:** MongoDB setup, read queries, and embedded-document view are complete; index and validation evidence is next.

## Goal

Implement one NoSQL model for the same Miva Bites Restaurant POS case study and explain when it is suitable. This portfolio uses a MongoDB document model. The CA brief asks for a NoSQL model, an example implementation, evidence, and a suitability explanation; it does not require implementing every NoSQL model type.

## Model choice: one order per document

The `orders` collection stores one document for each POS order. Its `lineItems` array contains the items on the ticket, and its `paymentAttempts` array contains payment and refund attempts for that order. A cashier or kitchen user can load the order and its bounded child records in one read.

Each line item keeps the menu item ID plus the item name and sale-time price. The ID still points conceptually to the shared PostgreSQL menu catalogue; the copied name and price preserve what the customer saw and paid at that time. Branch and employee IDs are retained, with their names copied into the order for display.

### Mapping from the relational schema

| PostgreSQL tables | MongoDB document fields | Why |
|---|---|---|
| `pos_order` | Root order fields such as `orderId`, `branchId`, `orderType`, `status`, and `openedAt` | One document represents one POS ticket. |
| `order_item` + `menu_item` | Embedded `lineItems[]` with `menuItemId`, name snapshot, quantity, price snapshot, and kitchen status | Ticket lines are commonly read and updated with their parent order. |
| `payment` | Embedded `paymentAttempts[]`, including failures and refunds | Cashiers can see the payment history beside the order; `refundOfPaymentId` points to the earlier payment attempt within the same order. |
| `branch`, `employee`, `customer`, `dining_table` | IDs and small display snapshots on the order | The order can be displayed without lookups; authoritative records remain in PostgreSQL. |
| `inventory`, `stock_movement`, `recipe` | Not copied into this model | Branch stock and its audit ledger need cross-order constraints and concurrency control, already demonstrated in PostgreSQL. |

The stored document does not save a second copy of the order total. Queries calculate line sales from quantity and sale-time price, and net collections from successful payments less successful refunds. This avoids maintaining derived totals whenever a line or payment changes.

### Suitability and limitations

- **Good fit:** cashier and kitchen screens usually need a complete order ticket, including its lines and payment history.
- **Good fit:** an order and its embedded children can be updated atomically as one MongoDB document.
- **History:** line item names and prices are snapshots, so a later menu edit does not rewrite an old ticket.
- **Validation:** a MongoDB JSON Schema validator checks document shape and allowed values. It does not provide PostgreSQL-style foreign keys between the IDs in this document and the relational tables.
- **Trade-off:** branch, employee, customer, and menu details are repeated in order documents. If their authoritative values change, those display snapshots do not update automatically.
- **Growth limit:** line items and payment attempts are expected to stay small for each order. If an order can accumulate a very large or unbounded event history, store that history in a separate collection.
- **System boundary:** this is a portfolio model, not a live synchronization service. PostgreSQL remains authoritative for the relational POS and inventory. The NoSQL sample is a separate implementation of the order-reading use case.

### Query results

- The ticket lookup returns order `9301` as one document with embedded line items, a successful card payment, and its linked refund.
- Menu sales aggregate to 2 Grilled Chicken Bowls worth ₦13,600, 2 Jollof Rice portions worth ₦5,000, and 2 Fresh Lemonades worth ₦2,400.
- Net collections are ₦14,300 for order `9301` after its ₦500 refund, and ₦6,200 for order `9302` after excluding a failed cash attempt.
- The Ikeja active-kitchen query returns an empty array as expected: Ikeja order `9301` is completed, while the active order `9302` is at Lekki.

## Files

- [`setup.js`](setup.js) creates the `miva_bites_nosql_lab` database's `orders` collection, applies document validation, inserts two repeatable example orders, and creates indexes. It only replaces demo orders 9301 and 9302 when rerun.
- [`queries.js`](queries.js) prints an order ticket, popular menu items, net successful collections, and active kitchen work.
- Screenshots and other output evidence belong in [`Evidence/portfolio4`](../../Evidence/portfolio4/).
- [`portfolio4-setup-output.png`](../../Evidence/portfolio4/portfolio4-setup-output.png) records the successful setup, inserted demo orders, and created indexes.
- [`query-01-ticket.png`](../../Evidence/portfolio4/query-01-ticket.png), [`query-02-menu-sales.png`](../../Evidence/portfolio4/query-02-menu-sales.png), and [`query-03-collections-and-kitchen.png`](../../Evidence/portfolio4/query-03-collections-and-kitchen.png) record the four successful query outputs.
- [`compass-order-embedded-fields.png`](../../Evidence/portfolio4/compass-order-embedded-fields.png) shows the two documents and order `9301` with its embedded line items and payment attempts.

## Beginner setup on Windows

This lab uses a local MongoDB Community Server and MongoDB Compass. The Docker command-line client is present on the current computer, but its Docker engine is not running, so use the normal Windows service installation for this exercise.

1. Install MongoDB Community Server for Windows using the [official installation guide](https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-on-windows/). In the installer, choose the complete setup and install MongoDB as a Windows service.
2. Install [MongoDB Compass](https://www.mongodb.com/try/download/compass) if it was not offered during the server setup.
3. Install the standalone [MongoDB Shell (`mongosh`)](https://www.mongodb.com/docs/mongodb-shell/install/?operating-system=windows&windows-installation-method=msiexec). The Community Server installer does not include this separate command-line shell.
4. Open MongoDB Compass. In the connection box enter `mongodb://localhost:27017`, then click **Connect**. This connects Compass to the MongoDB service on this computer.
5. Open **PowerShell** and run `mongosh --version` to confirm the shell is installed.
6. In PowerShell, run the setup script with `--file`:

   ```powershell
   mongosh "mongodb://localhost:27017" --file "C:\Users\User\Documents\Miva\Courses\First Semester\MIT 8103 - Advanced Database Systems\Advanced DB CA\Portfolios\portfolio-4-nosql-and-advanced-data-models\setup.js"
   ```

   If you clone the repository into a different folder, replace the script path with that copy's full path. Compass's embedded shell reported that `load()` is not implemented in this environment, so use the standalone shell and `--file` to run the script.

7. In Compass, refresh the deployment list if needed. Open database `miva_bites_nosql_lab`, then collection `orders`. You should see two documents with order IDs `9301` and `9302`.
8. Run the read queries from PowerShell:

   ```powershell
   mongosh "mongodb://localhost:27017" --file "C:\Users\User\Documents\Miva\Courses\First Semester\MIT 8103 - Advanced Database Systems\Advanced DB CA\Portfolios\portfolio-4-nosql-and-advanced-data-models\queries.js"
   ```

9. Capture screenshots of the two documents in Compass, the query output, and the validator/index information. Save them in `Evidence/portfolio4`.

The setup script completed successfully: it inserted two demo orders, created three indexes, and reported an example order count of `2`. The output screenshot is saved in `Evidence/portfolio4`.

## Evidence checklist

- MongoDB Compass connected to the local server and showing `miva_bites_nosql_lab.orders`.
- The expanded order document with its embedded line items and payment history.
- Successful setup output showing two inserted example orders and three created indexes.
- The two example documents with their embedded line items and payment attempts.
- The order-ticket query result.
- The popular-menu-items aggregation output.
- The net-collections aggregation output.
- The active-kitchen query result, including the explanation for the empty Ikeja result.
- The collection validator and indexes, or output from the setup script showing their creation.

## References

- MongoDB, [Install MongoDB Community Edition on Windows](https://www.mongodb.com/docs/v8.0/tutorial/install-mongodb-on-windows/) and [install `mongosh` on Windows](https://www.mongodb.com/docs/mongodb-shell/install/?operating-system=windows&windows-installation-method=msiexec).
- MongoDB, [MongoDB Compass download](https://www.mongodb.com/try/download/compass) and [embedded MongoDB Shell](https://www.mongodb.com/docs/compass/embedded-shell/).
- MongoDB, [Run JavaScript files from `mongosh`](https://www.mongodb.com/docs/mongodb-shell/write-scripts/).
