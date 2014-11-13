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

pins <- array(32, null);
states <- array(32, null);

commands <- array(256, null);
commands[0xF4] = "PIN_MODE";
commands[0xE0] = "ANALOG_WRITE";
commands[0xE1] = "SERVO_WRITE";
commands[0x90] = "DIGITAL_WRITE";
commands[0xC0] = "REPORT_ANALOG";
commands[0xD0] = "REPORT_DIGITAL";
commands[0xFF] = "SYSTEM_RESET";
commands[0xFF] = "SYSTEM_RESET";

periods <- [
  { period = 0.0025, duty = 0.0 },
  { period = 0.0200, duty = 0.0 }
];

function from7BitBytes(lsb, msb) {
  return lsb | (msb << 0x07);
}

agent.on("data", function(data) {
  local bytes = split(data, ",").map(function(value) {
    return value.tointeger();
  });

  local command = bytes[0];
  local pin = bytes.len() >= 2 ? bytes[1] : null;

  if (command in commands) {
    server.log(hardware.millis() + " " + commands[command]);
  }

  switch (command) {
    case PIN_MODE:
      local mode = bytes[2];
      local period = null;

      pinMode(pin, MODES[mode]);

      if (mode == 3 || mode == 4) {
        setupPwm(pin, mode);
      }

      break;

    case ANALOG_WRITE:
      analogWrite(pin, from7BitBytes(bytes[2], bytes[3]));
      break;

    case SERVO_WRITE:
      servoWrite(pin, from7BitBytes(bytes[2], bytes[3]));
      break;

    case DIGITAL_WRITE:
      digitalWrite(pin, from7BitBytes(bytes[2], bytes[3]));
      break;

    case SYSTEM_RESET:
      systemReset();
      break;

    default:
      // server.log("hit default, likely an invalid command");
      server.log("-----------------------------------------");
  }
});

// Handlers

function pinMode(pin, mode) {
  local name = "pin" + pin;

  if (pins[pin] != null) {
    if (states[pin].mode != mode) {
      pins[pin] = null;
      states[pin] = null;
      pinMode(pin, mode);
      return;
    }

    return;
  } else {
    if (name in hardware) {
      pins[pin] = hardware[name];
      states[pin] = {mode = null, value = 0};
    }

    if (pins[pin] != null) {
      states[pin].mode = mode;

      if (mode != PWM_OUT) {
        pins[pin].configure(mode);
      }
    }
  }

  // server.log(hardware.millis() + " PIN_MODE COMPLETE");
}

function digitalWrite(pin, value) {
  if (pins[pin] == null) {
    pinMode(pin, DIGITAL_OUT);
  }

  value = value > 0 ? 1 : 0;

  pins[pin].write(value);
  states[pin].value = value;

  // server.log(hardware.millis() + " DIGITAL_WRITE COMPLETE");
}

function analogWrite(pin, value) {
  if (pins[pin] == null) {
    pinMode(pin, MODES[3]);
    setupPwm(pin, 3);
  }

  pins[pin].write(scale(value, 0.0, 255.0, 0.0, 1.0));

  server.log(hardware.millis() + " ANALOG_WRITE COMPLETE");
}

function servoWrite(pin, value) {
  if (pins[pin] == null) {
    pinMode(pin, MODES[4]);
    setupPwm(pin, 4);
  }
  // - check pin is configured
  //    - mode: pwm, servo (3, 4)
  //    - If Servo
  //      - Must have servo instance allocated.
  // - write to pin

  pins[pin].write(scale(value, 0.0, 180.0, 0.03, 1.0));

  // server.log(hardware.millis() + " SERVO_WRITE COMPLETE");
}

function scale(value, fromLow, fromHigh, toLow, toHigh) {
  return (value - fromLow) * (toHigh - toLow) /
    (fromHigh - fromLow) + toLow;
}

function setupPwm(pin, mode) {
  local index = pwmIndex(mode);
  pins[pin].configure(
    MODES[mode], periods[index].period, periods[index].duty
  );
}

function pwmIndex(mode) {
  return mode - 3;
}

function systemReset() {
  foreach(index, pin in pins) {
    if (pin != null) {
      pin.configure(DIGITAL_OUT);
      pin.write(0);

      pins[index] = null;
      states[index] = null;
    }
  }
  // server.log(hardware.millis() + " SYSTEM_RESET COMPLETE");
}

systemReset();


// led <- hardware.pin1;
// led.configure(PWM_OUT, 1.0/400.0, 0.0);
// led.write(0.75);


// Examples:

// PIN_MODE (pin: 1, mode: output (1))
// https://agent.electricimp.com/xXnZ4GXIWNEw/?payload=244,1,1

// DIGITAL_WRITE (pin: 1, value: 1)
// https://agent.electricimp.com/xXnZ4GXIWNEw/?payload=144,1,1,0

// ANALOG_WRITE (pin: 1, value: 127)
// https://agent.electricimp.com/xXnZ4GXIWNEw/?payload=224,1,127,0



// Notes: use digital_in callback arg for reading.


// isBlinking <- true;
// led <- hardware.pin1;
// led.configure(DIGITAL_OUT);
// state <- 0;

// function blink() {
//   if (isBlinking) {
//     led.write(state = state ^ 1);
//     imp.wakeup(0.5, blink);
//   }
// }

// blink();
