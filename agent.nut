report <- array(32, null);

http.onrequest(function(request, response) {
  if ("payload" in request.query) {
    device.send("payload", request.query.payload);
  }

  // adds new pins to the report group
  if ("report" in request.query) {
    device.send("report", request.query.report);
  }

  // All "non-connect" requests receive the current
  // reporting state as a response.
  if (device.isconnected()) {
    response.send(200, serialize(report));
  } else {
    response.send(500, "Internal Server Error: Device not connected");
  }
});

device.on("update", function(data) {
  local bytes = toBytes(data);
  local index = null;
  local flag = 0;

  foreach (byte in bytes) {
    if (flag == 0) {
      index = byte;
    } else {
      report[index] = byte;
    }
    flag = flag ^ 1;
  }
});

function toBytes(data) {
  return split(data, ",").map(function(value) {
    return value.tointeger();
  });
}

function serialize(array) {
  local accum = "";
  foreach (index, val in array) {
    if (val != null) {
      accum = accum + index + "," + val + ",";
    }
  }
  return accum;
}
