#define outPin        0
#define inPin         1
#define inGround      2
#define laserPin      13
#define laserGround   14

#define LASEROFF      0
#define LASERSTANDBY  1
#define LASERON       2

char cCOM;
bool enableLaser = false;
int inputState;
int laserState = LASEROFF;
unsigned long inputTime;
unsigned long latency = 0;
const unsigned long laserDuration = 1000; // 1 ms



void setup() {
    Serial.begin(2000000);

    pinMode(outPin, OUTPUT);
    pinMode(laserPin, OUTPUT);
    pinMode(laserGround, OUTPUT);
    
    pinMode(inPin, INPUT_PULLUP);
    pinMode(inGround, OUTPUT);
    

    digitalWriteFast(outPin, LOW);
    digitalWriteFast(laserPin, LOW);
    digitalWriteFast(laserGround, LOW);
    digitalWriteFast(inGround, LOW);
    inputState = digitalReadFast(inPin);
}


void loop() {
    checkSerial();
    checkSensor();
    if (enableLaser) {
        checkLaser();
    }
}


void checkSerial() { // takes 11.7 ns (7 clocks) if no message
    if (Serial.available() > 0) {
        cCOM = Serial.read();

        if (cCOM == '1') {
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
        else if (cCOM == 'e') {
            enableLaser = true;
        }
        else if (cCOM == 'd') {
            enableLaser = false;
        }
    }
}


void checkSensor() {
    if (digitalReadFast(inPin) != inputState) {
        if (inputState == 0) {
            inputTime = micros();
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
