var request = require("request");
var remote = "https://agent.electricimp.com/" + process.env.IMP_DEVICE;
var payloads = [
  // SYSTEM_RESET (command: 208)
  [255],

  // PIN_MODE (pin: 1, mode: output (1))
  [244, 2, 1],

  // DIGITAL_WRITE (pin: 1, value: 1)
  [144, 2, 1, 0],

  // PIN_MODE (pin: 1, mode: pwm (3))
  [244, 2, 3],

  // ANALOG_WRITE (pin: 1, value: 50)
  [224, 2, 10, 0],

  // PIN_MODE (pin: 9, mode: input)
  [244, 9, 0],

  // PIN_MODE (pin: 8, mode: analog)
  [244, 8, 2],

  // NOTHING
  [1024],
];

var reports = [
  // REPORT_DIGITAL (pin: 9)
  [208, 9],

  // // REPORT_ANALOG (pin: 9)
  [192, 8],

];

var sent = {
  read: [],
  write: [],
};

function read() {
  if (!reports.length) {
    return;
  }
  var report = reports.shift();
  var url = remote + "?report=" + report;
  sent.read.push(url);
  request(url, function(err, response, body) {
    console.log("-- Reporting State: ");
    // console.log("  SENT: ", sent.read.indexOf(url));
    console.log("    REQUEST:  ", url);
    console.log("    RESPONSE: ", body);
    read();
  });
}

read();

function write() {
  if (!payloads.length) {
    return;
  }
  var payload = payloads.shift();
  var url = remote + "?payload=" + payload;
  sent.write.push(url);
  request(url, function(err, response, body) {
    console.log("-- Reporting State: ");
    // console.log("  SENT: ", sent.write.indexOf(url));
    console.log("    REQUEST:  ", url);
    console.log("    RESPONSE: ", body);
    write();
  });
}

write();


// system reset
setTimeout(function() {
  request(remote + "?payload=255");
}, 3000);
