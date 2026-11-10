# Portfolio 3: Transactions and Concurrency

**Status:** Lab setup, COMMIT, ROLLBACK, READ COMMITTED, and REPEATABLE READ demonstrated with screenshots; the concurrency exercise is next.

## Goal

Show how PostgreSQL transactions protect Miva Bites operations. The practical examples demonstrate `COMMIT`, `ROLLBACK`, the difference between `READ COMMITTED` and `REPEATABLE READ`, and safe stock consumption when two orders compete for the same ingredient.

The CA brief expects transaction examples for commit, rollback, isolation, and a concurrency issue or control mechanism, supported by screenshots or output evidence. This lab covers each item in the separate `miva_bites_transaction_lab` database.

## Lab files

- [`commit-example.sql`](commit-example.sql): add a rice receipt and commit the inventory and stock-ledger changes together.
- [`rollback-example.sql`](rollback-example.sql): preview an uncommitted receipt, roll it back, and verify that neither the stock balance nor ledger retains it.
- [`isolation-demo.sql`](isolation-demo.sql): run paired statements in two pgAdmin Query Tool sessions to observe `READ COMMITTED` and `REPEATABLE READ`.
- [`concurrency-setup.sql`](concurrency-setup.sql): reset the lab rows and create two open lemonade orders that each need 60 lemons.
- [`concurrency-session-a.sql`](concurrency-session-a.sql), [`concurrency-session-b.sql`](concurrency-session-b.sql), and [`concurrency-session-a-finish.sql`](concurrency-session-a-finish.sql): coordinate the two-session stock-consumption demonstration.
- [`concurrency-verify.sql`](concurrency-verify.sql): check the remaining stock, order statuses, and movement ledger after the competing transactions.

## Prepare the isolated database in pgAdmin 4

1. In pgAdmin, right-click **Databases** under your PostgreSQL server and choose **Create → Database**. Name it `miva_bites_transaction_lab`.
2. Select the new database, open **Query Tool**, and run Portfolio 1's `schema.sql` followed by `seed.sql`. Use **Open File** in the Query Tool to load each SQL file. These files are designed for a fresh database and should be run once.
3. Open and run `concurrency-setup.sql` from this folder. It resets only the transaction-lab scenario, restoring seeded rice and lemon balances and recreating demo orders 9001 and 9002.
4. Check the connection label at the top of Query Tool says `miva_bites_transaction_lab` before running any lab script. Keep the existing practice and query-lab databases unchanged.

## 1. COMMIT: save both related changes

Run [`commit-example.sql`](commit-example.sql) once after the lab setup. It increases the Ikeja rice balance by 100 g, inserts a matching `RECEIPT` row in `stock_movement`, and commits both changes. The final result should show a rice balance of **9,800 g** and one receipt movement for this demonstration. To repeat it from the beginning, run `concurrency-setup.sql` again first.

The two writes belong in one transaction. If either write fails before `COMMIT`, run `ROLLBACK` so the balance and audit ledger cannot disagree.

## 2. ROLLBACK: discard an uncommitted change

In [`rollback-example.sql`](rollback-example.sql), first run the block from `BEGIN` through the query labeled **inside the transaction**, stopping before `ROLLBACK`. It should show the temporary rice balance of **10,300 g** and two receipt rows while that transaction is open. Then run the `ROLLBACK` and final verification query. The durable balance should return to **9,800 g**, with only the committed receipt left in the ledger.

## 3. Isolation: compare two isolation levels

Open two Query Tool tabs connected to `miva_bites_transaction_lab`. Call them **Session A** and **Session B**. In `isolation-demo.sql`, select the exact line ranges below and click **Execute** (▶). Run each range separately:

1. Open `concurrency-setup.sql` and run lines **3–61**. This resets the isolated transaction lab to its starting values: rice **9,700 g**, lemons **99.5**, two open demo orders, and demo value **100**.
2. Session A: run lines **5–8**. The result should be **100**. Leave this Query Tool tab open.
3. Session B: run lines **11–15**. It should return **125**. Then run line **16** by itself to commit the update.
4. Session A: run lines **19–21**. It should now return **125**. Then run line **22** by itself to end this transaction.
5. Session A: run lines **25–28**. The result should be **125**. Leave the transaction open.
6. Session B: run lines **31–35**. It should return **150**. Then run line **36** by itself to commit the update.
7. Session A: run lines **39–41**. It should still return **125**. Then run line **42** by itself to end this transaction.
8. Session A: run lines **45–47**. It should now return **150**.

Do not run the whole isolation file at once: pause between the labeled blocks so the other session can commit between reads.

## 4. Concurrency control: two orders compete for lemons

The setup creates two open takeaway orders. Each order contains 120 lemonades; the recipe requires 0.5 lemon per drink, so each order needs **60 lemons**. The seeded Ikeja inventory has **99.5 lemons** available. Only one order can be prepared with this stock.

Use two Query Tool tabs, both connected to `miva_bites_transaction_lab`:

1. In **Session A**, run `concurrency-session-a.sql`. The conditional update consumes 60 lemons for order 9001, returns a balance of **39.5**, and keeps its transaction open.
2. In **Session B**, run `concurrency-session-b.sql`. Its update will wait for Session A's row lock. Do not cancel the query.
3. In **Session A**, run `concurrency-session-a-finish.sql`. This records the matching sale-consumption movement, advances order 9001 to `IN_PREPARATION`, and commits.
4. Session B's update should now finish with **zero rows** because only 39.5 lemons remain. In Session B, run `ROLLBACK;` to close its transaction; do not add a movement for order 9002.
5. Run each query in `concurrency-verify.sql` separately. The first should show 39.5 lemons remaining, order 9001 in preparation with a -60 movement, and order 9002 still open with no consumption movement. The second should show that the inventory balance and movement ledger both equal 39.5.

If Session A does not return 39.5 or Session B returns an updated row, stop before running the finish script. Run `ROLLBACK;` in any still-open transactions, recheck that both sessions use the transaction lab database, then rerun `concurrency-setup.sql` and restart the demonstration.

The `UPDATE ... WHERE quantity_on_hand >= 60` takes a row lock and rechecks the condition after waiting for another transaction. This prevents both orders from spending the same stock. The balance update, movement insert, and order-status update are committed together, so a failure can be rolled back without leaving partial records.

## Evidence to capture

Save pgAdmin screenshots or query outputs in [`Evidence/portfolio3`](../../Evidence/portfolio3/):

- [Lab setup result](../../Evidence/portfolio3/lab-setup-success.png) confirms the fresh starting balances and two open demo orders.
- [COMMIT example result](../../Evidence/portfolio3/commit-example-success.png) shows the 9,800 g rice balance and one committed receipt.
- [ROLLBACK preview](../../Evidence/portfolio3/rollback-preview.png) shows the uncommitted 10,300 g balance and two visible receipts.
- [ROLLBACK confirmation](../../Evidence/portfolio3/rollback-confirmed.png) shows the restored 9,800 g balance and one committed receipt.
- [REPEATABLE READ first read](../../Evidence/portfolio3/isolation-repeatable-read-first-100.png) shows Session A reading 100.
- [REPEATABLE READ keeps the earlier value](../../Evidence/portfolio3/isolation-repeatable-read-still-100.png) shows Session A still reading 100 after Session B commits its increase.
- [REPEATABLE READ after commit](../../Evidence/portfolio3/isolation-repeatable-read-after-commit-125.png) shows a new query reading 125 after Session A commits.
- [READ COMMITTED update](../../Evidence/portfolio3/isolation-read-committed-update-125.png) shows Session B changing the demo value to 125.
- [READ COMMITTED next read](../../Evidence/portfolio3/isolation-read-committed-session-a-125.png) shows Session A reading 125 after Session B commits.
- [REPEATABLE READ first read at 125](../../Evidence/portfolio3/isolation-repeatable-read-first-125.png) and [new read after commit at 150](../../Evidence/portfolio3/isolation-repeatable-read-after-commit-150.png) show the completed second run.
- The blocked competing update, its zero-row result after Session A commits, and the final concurrency verification.

Use the exact results from your own PostgreSQL run. These are expected values for the fresh seeded lab, not evidence until you have run the scripts and captured your own output.
