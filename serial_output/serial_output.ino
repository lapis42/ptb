#define outPin        0 // output that notifies that the visual stimuli is on
#define inPin         1 // input from FPGA bmi
#define inGround      2 // ground for inPin
#define statePin     13 // to show whether the teensy is enabled
#define laserPin      14 // output to laser

#define LASEROFF      0
#define LASERSTANDBY  1
#define LASERON       2

char cCOM;
bool enableLaser = false;
int inputState;
int laserState = LASEROFF;
unsigned long inputTime;
unsigned long latency = 0;
unsigned long laserDuration = 20000;



void setup() {
    Serial.begin(2000000);

    pinMode(outPin, OUTPUT);
    pinMode(laserPin, OUTPUT);
    pinMode(statePin, OUTPUT);
    
    pinMode(inPin, INPUT_PULLUP);
    pinMode(inGround, OUTPUT);
    

    digitalWriteFast(outPin, LOW);
    digitalWriteFast(laserPin, LOW);
    digitalWriteFast(statePin, LOW);
    digitalWriteFast(inGround, LOW);
    inputState = digitalReadFast(inPin);
}


void loop() {
    checkSerial();
    if (enableLaser) {
        checkSensor();
        checkLaser();
    }
}


void checkSerial() { // takes 11.7 ns (7 clocks) if no message
    if (Serial.available() > 0) {
        cCOM = Serial.read();

        if (cCOM == '1') { // visual cue
            digitalWriteFast(outPin, HIGH);
        }
        else if (cCOM == '0') {
            digitalWriteFast(outPin, LOW);
        }
        else if (cCOM == 'l') { // latency
            while (Serial.available() == 0) {}
            latency = Serial.read() * 1000;
            Serial.println(latency);
        }
        else if (cCOM == 'D') { // duration
            while (Serial.available() == 0) {}
            laserDuration = Serial.read() * 1000;
            Serial.println(laserDuration);
        }
        else if (cCOM == 'e') { // enable
            digitalWriteFast(statePin, HIGH);
            enableLaser = true;
        }
        else if (cCOM == 'd') { // disable
            digitalWriteFast(statePin, LOW);
            digitalWriteFast(laserPin, LOW);
            laserState = LASEROFF;
            enableLaser = false;
        }
    }
}


void checkSensor() {
    if (digitalReadFast(inPin) != inputState) { // if the signal is changed
        if (inputState == 0) { // if it is rising-edge
            inputTime = micros(); // input time will be updated even when the laser if on
            inputState = 1;
            if (laserState == LASEROFF) laserState = LASERSTANDBY;
        }
        else inputState = 0;
    }
}


void checkLaser() {
    if (laserState == LASERSTANDBY) {
        if (micros() - inputTime >= latency) { // immune to rollover
            digitalWriteFast(laserPin, HIGH);
            laserState = LASERON;
        }
    }
    else if (laserState == LASERON) {
        if (micros() - inputTime >= latency + laserDuration) {
            digitalWriteFast(laserPin, LOW);
            laserState = LASEROFF;
        }
    }  
}
