const replicaSetConfig = {
  _id: "mivaBitesRS",
  members: [
    { _id: 0, host: "localhost:27117" },
    { _id: 1, host: "localhost:27118" },
    { _id: 2, host: "localhost:27119" }
  ]
};

print("Initializing the three-member Miva Bites replica set:");
const initializationResult = rs.initiate(replicaSetConfig);
printjson(initializationResult);

if (initializationResult.ok !== 1) {
  throw new Error("MongoDB did not accept the replica-set configuration. Send me the result above.");
}

print("Wait about 10 seconds, then check the member states.");
