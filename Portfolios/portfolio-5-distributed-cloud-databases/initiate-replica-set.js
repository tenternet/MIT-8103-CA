const replicaSetConfig = {
  _id: "mivaBitesRS",
  members: [
    { _id: 0, host: "localhost:27117" },
    { _id: 1, host: "localhost:27118" },
    { _id: 2, host: "localhost:27119" }
  ]
};

const currentStatus = db.adminCommand({ replSetGetStatus: 1 });
if (currentStatus.ok === 1) {
  print("This replica set is already initialized. Current members:");
  printjson(currentStatus.members.map(member => ({
    name: member.name,
    state: member.stateStr,
    health: member.health
  })));
} else {
  print("Initializing the three-member Miva Bites replica set:");
  printjson(rs.initiate(replicaSetConfig));
  print("Wait about 10 seconds, then run replica-status.js.");
}
