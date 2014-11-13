http.onrequest(function(request, response) {
  device.send("data", request.query.payload);
  response.send(200, request.query.payload);
});
