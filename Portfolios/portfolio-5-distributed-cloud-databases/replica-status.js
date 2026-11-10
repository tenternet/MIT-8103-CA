const status = rs.status();

print(`Replica set: ${status.set}`);
printjson(status.members.map(member => ({
  name: member.name,
  state: member.stateStr,
  health: member.health
})));
