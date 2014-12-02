const PIN_MODE = 0xF4;
const ANALOG_WRITE = 0xE0;
const SERVO_WRITE = 0xE1;
const DIGITAL_WRITE = 0x90;
const REPORT_ANALOG = 0xC0;
const REPORT_DIGITAL = 0xD0;
const SYSTEM_RESET = 0xFF;

// Reference:
// https://electricimp.com/docs/api/hardware/pin/configure/
MODES <- [
  DIGITAL_IN,
  DIGITAL_OUT,
  ANALOG_IN,
  PWM_OUT,
  PWM_OUT
];

commands <- array(256, null);
commands[0xF4] = "PIN_MODE";
commands[0xE0] = "ANALOG_WRITE";
commands[0xE1] = "SERVO_WRITE";
commands[0x90] = "DIGITAL_WRITE";
commands[0xC0] = "REPORT_ANALOG";
commands[0xD0] = "REPORT_DIGITAL";
commands[0xFF] = "SYSTEM_RESET";

Command <- {
  toMode = function(command) {
    local mode = null;

    if (Write.commands.find(command) != null) {
      mode = 1;
    }

    if (Pwm.commands.find(command) != null) {
      mode = 3;
    }

    if (command == REPORT_DIGITAL) {
      mode = 0;
    }

    if (command == REPORT_ANALOG) {
      mode = 2;
    }

    return mode;
  }
}

Pwm <- {
  commands = [ANALOG_WRITE, SERVO_WRITE]

  config = [
    { period = 0.0025, duty = 0.0 },
    { period = 0.0200, duty = 0.0 }
  ]

  index = function(mode) {
    return mode - 3;
  }
}

Write <- {
  commands = [ANALOG_WRITE, DIGITAL_WRITE, SERVO_WRITE]

  // TODO: Refactor scaling to happen inside the
  //        pin object's write method
  //
  //
  ANALOG_WRITE = function(pin, value) {
    local duty = scale(value, 0.0, 255.0, 0.0, 1.0);

    if (pins[pin] == null) {
      pinMode(pin, MODES[3]);
    }

    pins[pin].write(duty);
    pins[pin].value = value;
    pins[pin].duty = duty;
    // server.log(hardware.millis() + " ANALOG_WRITE COMPLETE");
  }

  DIGITAL_WRITE = function(pin, value) {
    if (pins[pin] == null) {
      pinMode(pin, DIGITAL_OUT);
    }

    value = value > 0 ? 1 : 0;

    pins[pin].write(value);
    pins[pin].value = value;
    // server.log(hardware.millis() + " DIGITAL_WRITE COMPLETE");
  }

  SERVO_WRITE = function(pin, value) {
    local duty = scale(value, 0.0, 180.0, 0.03, 1.0);

    if (pins[pin] == null) {
      pinMode(pin, MODES[4]);
    }

    pins[pin].write(duty);
    pins[pin].value = value;
    pins[pin].duty = duty;
    // server.log(hardware.millis() + " SERVO_WRITE COMPLETE");
  }
}

Reporting <- {
  pins = []
  interval = 0.02

  isActive = function() {
    return this.pins.len() > 0;
  }

  update = function() {
    local data = [];
    local string = "";
    if (this.isActive()) {
      foreach (index, pin in pins) {
        local value = pin.read();

        if (pin.mode == 2) {
          value = value >> 6;
        }

        data.append(pin.number);
        data.append(value);
      }

      string = join(data, ",");
      agent.send("update", string);

      imp.wakeup(this.interval, this.update.bindenv(this));
    }
  }
}

class Pin {
  hardware = null;
  number = null;
  mode = null;
  value = null;
  period = null;
  duty = null;

  constructor(h, n = 0, m = 0, ) {
    hardware = h;
    number = n;
    mode = m;
  }

  function read() {
    return hardware.read();
  }

  function write(output) {
    value = output;

    // TODO: move PWM scaling into
    //      this method definition.
    //
    hardware.write(value);
  }

  function configure(m, p = null, d = null) {
    if (m == PWM_OUT) {
      period = p;
      duty = d;
      hardware.configure(m, p, d);
    } else {
      hardware.configure(m);
    }
  }
}

function pinMode(pin, mode) {
  local name = "pin" + pin;
  local impMode = MODES[mode];
  local config;

  if (pins[pin] != null) {
    if (pins[pin].mode != mode) {
      pins[pin] = null;
      pinMode(pin, mode);
      return;
    }
  } else {
    if (name in hardware) {
      pins[pin] = Pin(hardware[name], pin, mode);
    }

    if (pins[pin] != null) {
      if (impMode == PWM_OUT) {
        config = Pwm.config[Pwm.index(mode)];

        pins[pin].configure(impMode, config.period, config.duty);
      } else {
        pins[pin].configure(impMode);
      }
    }
  }
}

pins <- array(32, null);


agent.on("report", function(rawdata) {
  local dataArray = toArray(rawdata);

  foreach (idx, data in dataArray) {
    local bytes = toBytes(data);
    local command;
    local pin;

    if (bytes.len() != 2) {
      return;
    }

    command = bytes[0];
    pin = bytes[1];

    // server.log("report: " + command + " " + pin);

    // If this pin hasn't been configured yet...
    if (pins[pin] == null) {
      pinMode(pin, Command.toMode(command));
    }

    Reporting.pins.append(pins[pin]);

  }

  if (Reporting.isActive()) {
    Reporting.update();
  }
});

agent.on("payload", function(rawdata) {
  local dataArray = toArray(rawdata);

  foreach (idx, data in dataArray) {
    local bytes = toBytes(data);
    local command = bytes[0];
    local pin = bytes.len() >= 2 ? bytes[1] : null;

    if (command in commands) {
      server.log(hardware.millis() + " " + commands[command]);
    }

    switch (command) {
      case PIN_MODE:
        pinMode(pin, bytes[2]);
        break;

      case ANALOG_WRITE:
      case SERVO_WRITE:
      case DIGITAL_WRITE:
        Write[commands[command]](pin, from7BitBytes(bytes[2], bytes[3]));
        break;

      case SYSTEM_RESET:
        systemReset();
        break;

      default:
        // server.log("hit default, likely an invalid command");
        server.log("-----------------------------------------");
    }
  }
});

function systemReset() {
  // Enable blinkup while resetting.
  imp.enableblinkup(true);

  foreach (index, pin in pins) {
    if (pin != null) {
      // Set pin to output and low
      pin.configure(DIGITAL_OUT);
      pin.write(0);
      // Clear pin from cache
      pins[index] = null;
    }
  }

  Reporting.pins.clear();

  // Disable blink up after 1s.
  imp.wakeup(1, function() {
    imp.enableblinkup(false);
  });
}

function scale(value, fromLow, fromHigh, toLow, toHigh) {
  return (value - fromLow) * (toHigh - toLow) / (fromHigh - fromLow) + toLow;
}

function from7BitBytes(lsb, msb) {
  return lsb | (msb << 0x07);
}

function toBytes(data) {
  return split(data, ",").map(function(value) {
    return value.tointeger();
  });
}

function toArray(data) {
  return split(data, "|");
}

function join(array, separator) {
  local accum = "";
  foreach (id, val in array) {
    if (val != null) {
      if (id == 0) {
        accum = val;
      } else {
        accum = accum + separator + val;
      }
    }
  }
  return accum;
}

systemReset();



// isBlinking <- true;
// led <- hardware.pin2;
// led.configure(DIGITAL_OUT);
// state <- 0;

// function blink() {
//   if (isBlinking) {
//     led.write(state = state ^ 1);
//     imp.wakeup(0.5, blink);
//   }
// }

// blink();
