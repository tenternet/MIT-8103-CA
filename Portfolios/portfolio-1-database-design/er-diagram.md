# Miva Bites POS - Draft ER Diagram

This diagram is the starting conceptual model for the case study. It will be checked against the business rules before we write the PostgreSQL schema.

Rendered versions: [PNG preview](er-diagram.png) · [scalable SVG](er-diagram.svg).

```mermaid
erDiagram
    BRANCH ||--o{ EMPLOYEE : employs
    BRANCH ||--o{ DINING_TABLE : contains
    BRANCH ||--o{ POS_ORDER : receives
    EMPLOYEE ||--o{ POS_ORDER : opens
    CUSTOMER o|--o{ POS_ORDER : places
    DINING_TABLE o|--o{ POS_ORDER : assigned_to

    MENU_CATEGORY ||--o{ MENU_ITEM : classifies
    MENU_ITEM ||--o{ ORDER_ITEM : appears_as
    POS_ORDER ||--|{ ORDER_ITEM : contains
    POS_ORDER ||--o{ PAYMENT : has_attempts
    PAYMENT ||--o{ PAYMENT : refunded_by

    MENU_ITEM ||--o{ RECIPE : uses
    INGREDIENT ||--o{ RECIPE : required_by
    BRANCH ||--o{ INVENTORY : tracks
    INGREDIENT ||--o{ INVENTORY : stocked_as
    BRANCH ||--o{ STOCK_MOVEMENT : records
    INGREDIENT ||--o{ STOCK_MOVEMENT : affected_by
    EMPLOYEE ||--o{ STOCK_MOVEMENT : records
    POS_ORDER o|--o{ STOCK_MOVEMENT : may_trigger

    BRANCH {
        int branch_id PK
        string name
        string address
    }
    EMPLOYEE {
        int employee_id PK
        int branch_id FK
        string full_name
        string role
        boolean active
    }
    DINING_TABLE {
        int table_id PK
        int branch_id FK
        string table_number
        int seats
        string status
    }
    CUSTOMER {
        int customer_id PK
        string full_name
        string phone
    }
    MENU_CATEGORY {
        int category_id PK
        string name
    }
    MENU_ITEM {
        int menu_item_id PK
        int category_id FK
        string name
        decimal current_price
        boolean active
    }
    INGREDIENT {
        int ingredient_id PK
        string name
        string unit
    }
    RECIPE {
        int menu_item_id PK, FK
        int ingredient_id PK, FK
        decimal quantity_per_item
    }
    INVENTORY {
        int branch_id PK, FK
        int ingredient_id PK, FK
        decimal quantity_on_hand
        decimal reorder_level
    }
    POS_ORDER {
        int order_id PK
        int branch_id FK
        int employee_id FK
        int customer_id FK
        int table_id FK
        string order_type
        string status
        datetime opened_at
        datetime closed_at
    }
    ORDER_ITEM {
        int order_item_id PK
        int order_id FK
        int menu_item_id FK
        int quantity
        decimal sale_unit_price
        string kitchen_status
    }
    PAYMENT {
        int payment_id PK
        int order_id FK
        int refund_of_payment_id FK
        string payment_type
        string method
        decimal amount
        string status
        string provider_reference
        datetime recorded_at
    }
    STOCK_MOVEMENT {
        int movement_id PK
        int branch_id FK
        int ingredient_id FK
        int employee_id FK
        int order_id FK
        string movement_type
        decimal quantity_change
        datetime recorded_at
    }
```

## Relationship and constraint notes

- A customer and dining table are optional for an order. A dine-in order must have a table; a takeaway order must not.
- The relational design uses composite foreign keys to enforce that an order's employee and table belong to the same branch as the order, and that a stock movement's employee, order, and inventory belong to its branch.
- Each order item refers to one menu item and one order. Each placed order must have at least one item.
- A menu item can use multiple ingredients; each recipe row records the quantity of one ingredient used for one menu item.
- `INVENTORY` is the current branch-level balance. `STOCK_MOVEMENT` records each increase or decrease; both are updated in the same transaction.
- Payment rows represent attempts or refunds. A refund references the original charge for the same order; payment/order statuses, positive amounts, and movement signs are constrained in the relational schema.
- The current menu and prices are shared across both branches; inventory and sales are branch-specific in this first version.
- Order totals and successful payment/refund totals are derived and reconciled in transaction logic; they are not duplicated as stored totals.

See [schema-design.md](schema-design.md) for the relationship review, normalization notes, and cross-row rules. See [schema.sql](schema.sql) for the PostgreSQL DDL draft.
