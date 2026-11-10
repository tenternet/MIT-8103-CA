const p5db = db.getSiblingDB("miva_bites_replica_lab");
const demoOrder = {
  _id: "P5-ORDER-9501",
  orderId: NumberLong("9501"),
  branchName: "Miva Bites Ikeja",
  menuItem: "Grilled Chicken Bowl",
  quantity: 2,
  total: NumberDecimal("13600.00"),
  status: "COMPLETED",
  createdAt: ISODate("2026-11-10T13:00:00Z")
};

print("Writing one order with majority acknowledgment:");
printjson(p5db.orders.replaceOne(
  { _id: demoOrder._id },
  demoOrder,
  {
    upsert: true,
    writeConcern: { w: "majority", wtimeout: 10000 }
  }
));
