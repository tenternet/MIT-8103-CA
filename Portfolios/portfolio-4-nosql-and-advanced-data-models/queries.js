// Load in mongosh after setup.js.
(function () {
  const p4db = db.getSiblingDB("miva_bites_nosql_lab");

  print("Query 1: one complete ticket, including embedded lines and payment history");
  printjson(p4db.orders.findOne({ orderId: NumberLong("9301") }));

  print("Query 2: popular menu items and sale-time line value across orders");
  printjson(p4db.orders.aggregate([
    { $unwind: "$lineItems" },
    {
      $group: {
        _id: {
          menuItemId: "$lineItems.menuItemId",
          name: "$lineItems.name"
        },
        unitsSold: { $sum: "$lineItems.quantity" },
        lineSalesValue: {
          $sum: {
            $multiply: ["$lineItems.quantity", "$lineItems.saleUnitPrice"]
          }
        }
      }
    },
    { $sort: { unitsSold: -1, lineSalesValue: -1 } }
  ]).toArray());

  print("Query 3: net collected per order; successful refunds subtract from successful payments");
  printjson(p4db.orders.aggregate([
    { $unwind: "$paymentAttempts" },
    { $match: { "paymentAttempts.status": "SUCCESSFUL" } },
    {
      $group: {
        _id: {
          orderId: "$orderId",
          branch: "$branchName"
        },
        netCollected: {
          $sum: {
            $cond: [
              { $eq: ["$paymentAttempts.paymentType", "PAYMENT"] },
              "$paymentAttempts.amount",
              { $multiply: ["$paymentAttempts.amount", -1] }
            ]
          }
        }
      }
    },
    { $sort: { "_id.orderId": 1 } }
  ]).toArray());

  print("Query 4: active kitchen work at the Ikeja branch");
  printjson(p4db.orders.find(
    {
      branchId: NumberLong("1"),
      status: { $in: ["PLACED", "IN_PREPARATION"] }
    },
    { _id: 0, orderId: 1, status: 1, lineItems: 1 }
  ).toArray());
})();
