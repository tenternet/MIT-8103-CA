// Run in the MongoDB Shell (mongosh). Safe to repeat for this portfolio lab:
// only the two example orders with IDs 9301 and 9302 are replaced.
(function () {
  const p4db = db.getSiblingDB("miva_bites_nosql_lab");

  const ordersValidator = {
    $jsonSchema: {
      bsonType: "object",
      required: [
        "orderId", "branchId", "branchName", "employeeId", "employeeName",
        "customer", "diningTable", "orderType", "status", "openedAt",
        "currency", "lineItems", "paymentAttempts"
      ],
      properties: {
        orderId: { bsonType: "long", minimum: 1 },
        branchId: { bsonType: "long", minimum: 1 },
        branchName: { bsonType: "string", minLength: 1 },
        employeeId: { bsonType: "long", minimum: 1 },
        employeeName: { bsonType: "string", minLength: 1 },
        customer: {
          bsonType: ["object", "null"],
          required: ["customerId", "name"],
          properties: {
            customerId: { bsonType: "long", minimum: 1 },
            name: { bsonType: "string", minLength: 1 }
          }
        },
        diningTable: {
          bsonType: ["object", "null"],
          required: ["tableId", "tableNumber"],
          properties: {
            tableId: { bsonType: "long", minimum: 1 },
            tableNumber: { bsonType: "string", minLength: 1 }
          }
        },
        orderType: { enum: ["DINE_IN", "TAKEAWAY"] },
        status: {
          enum: ["OPEN", "PLACED", "IN_PREPARATION", "COMPLETED", "CANCELLED"]
        },
        openedAt: { bsonType: "date" },
        closedAt: { bsonType: "date" },
        currency: { enum: ["NGN"] },
        lineItems: {
          bsonType: "array",
          minItems: 1,
          items: {
            bsonType: "object",
            required: [
              "lineId", "menuItemId", "name", "quantity",
              "saleUnitPrice", "kitchenStatus"
            ],
            properties: {
              lineId: { bsonType: "long", minimum: 1 },
              menuItemId: { bsonType: "long", minimum: 1 },
              name: { bsonType: "string", minLength: 1 },
              quantity: { bsonType: "int", minimum: 1 },
              saleUnitPrice: { bsonType: "decimal", minimum: 0 },
              kitchenStatus: {
                enum: ["QUEUED", "PREPARING", "READY", "SERVED", "CANCELLED"]
              }
            }
          }
        },
        paymentAttempts: {
          bsonType: "array",
          items: {
            bsonType: "object",
            required: [
              "paymentId", "attemptNo", "paymentType", "method",
              "amount", "status", "recordedAt"
            ],
            properties: {
              paymentId: { bsonType: "long", minimum: 1 },
              attemptNo: { bsonType: "int", minimum: 1 },
              paymentType: { enum: ["PAYMENT", "REFUND"] },
              method: {
                enum: ["CASH", "CARD", "MOBILE_MONEY", "BANK_TRANSFER", "OTHER"]
              },
              amount: { bsonType: "decimal", minimum: 0.01 },
              status: { enum: ["PENDING", "SUCCESSFUL", "FAILED", "CANCELLED"] },
              providerReference: { bsonType: "string" },
              refundOfPaymentId: { bsonType: "long", minimum: 1 },
              recordedAt: { bsonType: "date" }
            }
          }
        }
      }
    }
  };

  if (p4db.getCollectionInfos({ name: "orders" }).length === 0) {
    p4db.createCollection("orders", {
      validator: ordersValidator,
      validationLevel: "strict",
      validationAction: "error"
    });
  } else {
    p4db.runCommand({
      collMod: "orders",
      validator: ordersValidator,
      validationLevel: "strict",
      validationAction: "error"
    });
  }

  const demoOrderIds = [NumberLong("9301"), NumberLong("9302")];
  const removed = p4db.orders.deleteMany({ orderId: { $in: demoOrderIds } });
  print("Removed older copies of only the two Portfolio 4 demo orders:");
  printjson(removed);

  const inserted = p4db.orders.insertMany([
    {
      orderId: NumberLong("9301"),
      branchId: NumberLong("1"),
      branchName: "Miva Bites Ikeja",
      employeeId: NumberLong("1"),
      employeeName: "Tomi Example",
      customer: { customerId: NumberLong("1"), name: "Ada Example" },
      diningTable: { tableId: NumberLong("1"), tableNumber: "A1" },
      orderType: "DINE_IN",
      status: "COMPLETED",
      openedAt: ISODate("2026-11-10T11:00:00.000Z"),
      closedAt: ISODate("2026-11-10T11:20:00.000Z"),
      currency: "NGN",
      lineItems: [
        {
          lineId: NumberLong("1"),
          menuItemId: NumberLong("1"),
          name: "Grilled Chicken Bowl",
          quantity: NumberInt(2),
          saleUnitPrice: NumberDecimal("6800.00"),
          kitchenStatus: "SERVED"
        },
        {
          lineId: NumberLong("2"),
          menuItemId: NumberLong("2"),
          name: "Fresh Lemonade",
          quantity: NumberInt(1),
          saleUnitPrice: NumberDecimal("1200.00"),
          kitchenStatus: "SERVED"
        }
      ],
      paymentAttempts: [
        {
          paymentId: NumberLong("501"),
          attemptNo: NumberInt(1),
          paymentType: "PAYMENT",
          method: "CARD",
          amount: NumberDecimal("14800.00"),
          status: "SUCCESSFUL",
          providerReference: "SIM-PAY-09301",
          recordedAt: ISODate("2026-11-10T11:18:00.000Z")
        },
        {
          paymentId: NumberLong("502"),
          attemptNo: NumberInt(2),
          paymentType: "REFUND",
          method: "CARD",
          amount: NumberDecimal("500.00"),
          status: "SUCCESSFUL",
          providerReference: "SIM-REF-09301",
          refundOfPaymentId: NumberLong("501"),
          recordedAt: ISODate("2026-11-10T11:19:00.000Z")
        }
      ]
    },
    {
      orderId: NumberLong("9302"),
      branchId: NumberLong("2"),
      branchName: "Miva Bites Lekki",
      employeeId: NumberLong("4"),
      employeeName: "Seyi Example",
      customer: null,
      diningTable: null,
      orderType: "TAKEAWAY",
      status: "IN_PREPARATION",
      openedAt: ISODate("2026-11-10T12:00:00.000Z"),
      currency: "NGN",
      lineItems: [
        {
          lineId: NumberLong("1"),
          menuItemId: NumberLong("3"),
          name: "Jollof Rice",
          quantity: NumberInt(2),
          saleUnitPrice: NumberDecimal("2500.00"),
          kitchenStatus: "PREPARING"
        },
        {
          lineId: NumberLong("2"),
          menuItemId: NumberLong("2"),
          name: "Fresh Lemonade",
          quantity: NumberInt(1),
          saleUnitPrice: NumberDecimal("1200.00"),
          kitchenStatus: "QUEUED"
        }
      ],
      paymentAttempts: [
        {
          paymentId: NumberLong("503"),
          attemptNo: NumberInt(1),
          paymentType: "PAYMENT",
          method: "CASH",
          amount: NumberDecimal("6200.00"),
          status: "FAILED",
          providerReference: "SIM-PAY-09302-A",
          recordedAt: ISODate("2026-11-10T12:08:00.000Z")
        },
        {
          paymentId: NumberLong("504"),
          attemptNo: NumberInt(2),
          paymentType: "PAYMENT",
          method: "MOBILE_MONEY",
          amount: NumberDecimal("6200.00"),
          status: "SUCCESSFUL",
          providerReference: "SIM-PAY-09302-B",
          recordedAt: ISODate("2026-11-10T12:09:00.000Z")
        }
      ]
    }
  ]);
  print("Inserted Portfolio 4 demo orders:");
  printjson(inserted);

  print("Created indexes:");
  printjson(p4db.orders.createIndex({ orderId: 1 }, { unique: true, name: "uq_orderId" }));
  printjson(p4db.orders.createIndex({ branchId: 1, openedAt: -1 }, { name: "ix_branch_openedAt" }));
  printjson(p4db.orders.createIndex({ status: 1, openedAt: -1 }, { name: "ix_status_openedAt" }));

  print("Setup complete. Example order count:");
  printjson(p4db.orders.countDocuments({ orderId: { $in: demoOrderIds } }));
})();
