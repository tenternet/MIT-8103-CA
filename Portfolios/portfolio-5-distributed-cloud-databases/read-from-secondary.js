const p5db = db.getSiblingDB("miva_bites_replica_lab");
const replicatedOrder = p5db.orders.findOne({ _id: "P5-ORDER-9501" });

if (!replicatedOrder) {
  throw new Error("The order is not visible on this secondary yet. Wait a few seconds and run this command again.");
}

print("Order visible through the secondary-only connection:");
printjson(replicatedOrder);
