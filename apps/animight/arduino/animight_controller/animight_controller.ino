#include <Adafruit_NeoPixel.h>
#include <WiFi.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEServer.h>

// =================================================
// ===== HARDWARE & NETWORK CONFIGURATION =====
// =================================================

// --- WiFi Access Point ---
const char* ssid = "Animight_ESP32";
const char* password = "password123";
WiFiServer wifiServer(80);
WiFiClient client;

// --- Bluetooth Low Energy ---
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b"
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8"
BLEAdvertising *pAdvertising; // Pointer for BLE Advertising

// --- NeoPixel LEDs ---
#define LED_PIN     5
#define LED_COUNT   180
Adafruit_NeoPixel strip(LED_COUNT, LED_PIN, NEO_GRB + NEO_KHZ800);

// --- Sound Sensor ---
#define MIC_PIN     34

// =================================================
// ===== GLOBAL STATE & ANIMATION MANAGEMENT =====
// =================================================

enum AnimationMode {
  MODE_OFF,
  MODE_LOOP_ANIMATION,
  MODE_SOUND_REACTIVE
};
AnimationMode activeAnimation = MODE_OFF;

// =================================================
// ===== LED DEFINITIONS & ANIMATION VARIABLES =====
// =================================================

// --- Looping Animation Variables ---
unsigned long startTime;
bool fadeStarted = false;
int fadeRound = 0;
bool fadingIn = true;
int currentFadeBrightness = 0;
unsigned long lastFadeTime = 0;
float waveAngle = 0.0;
bool ledsOffExceptRed = false;
unsigned long ledsOffTime = 0;
bool ledsHalfBrightOn = false;
bool shootingStarsStarted = false;
int linearRound = 0, linearStep = 0;
unsigned long lastLinearUpdate = 0;
unsigned long linearDelay = 0;
bool linearAnimDone = false;
int randomStep = 0;
unsigned long lastRandomUpdate = 0;
bool randomAnimDone = false;
bool calmAnimationsStarted = false;
unsigned long calmStartTime = 0;
float calmBreathingAngle = 0.0;
float calmWaveAngle = 0.0;
int calmMode = 0;
unsigned long calmModeStartTime = 0;
const unsigned long calmModeDuration = 8000;
float groupFadeAngle = 0.0;
uint32_t savedColors[LED_COUNT];

// --- Sound Reactive Variables ---
const float smoothingFactor = 0.05;
float smoothedMic = 0;
const uint16_t ledOrder[LED_COUNT] = { 154,155,156,157,158,159,160,161,162,163,164,165,166,167,168,169,170,171,172,173,174,175,176,177,178,179,180,150,149,148,147,146,145,144,143,142,141,140,139,138,137,136,134,133,132,131,130,129,128,127,126,125,124,123,122,121,120,119,118,117,116,115,114,113,112,111,110,109,108,107,106,105,104,103,102,101,100,99, 98, 97, 96, 95, 94, 93, 92, 91, 90,89, 88, 87, 86, 85, 84, 82, 81, 80, 79,78, 77, 76, 75, 74, 73, 72, 71, 70, 69,68, 67, 66, 65, 64, 63, 62, 61, 60, 59,58, 57, 56, 55, 54, 53, 52, 51, 50, 49,48, 47, 46, 45, 44, 43, 42, 41, 40, 39,38, 37, 36, 35, 34, 33, 32, 31, 30, 29,28, 27, 26, 25, 24, 23, 22, 21, 20, 19,18, 17, 16, 15, 14, 13, 12, 11, 10, 9,8, 7, 6, 5, 4, 3, 2, 1 };
const uint8_t volumeBarLeds[] = { 87, 86, 85, 84, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 174, 173, 172, 171 };
const int volumeBarCount = sizeof(volumeBarLeds) / sizeof(volumeBarLeds[0]);
const uint8_t fixedRedLeds[] = {90, 123};

// --- Shared LED Groups ---
int pinkLeds[] = {150,149,148,147,146,145,144,143,142,141,140,139,138,137,136,135,134,133,155,156,157,158,159,160,161,162,163,164,165,166,167,10,11,12,13,14,15,16,17,18,43,42,41,47,46};
int whiteLeds[] = {1,2,3,4,5,6,7,8,9,20,21,22,23,180,179,178,177,168,169,170,105,104,103,102,101,100,99,98,97,96,95,94,93,92,91,88,109,110,111,112,113,114,115,116,117,118,119,120,121,122,124,125,126,127,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,60,59,58,57,56,55,54,53,52,51,50,49,48,45,44};
int groupA[] = {86, 85, 84};
int groupB[] = {35, 34, 33, 32, 31, 30, 29, 28, 27, 26};
int groupC[] = {174, 173, 172, 171};
int pinkCount = sizeof(pinkLeds) / sizeof(pinkLeds[0]);
int whiteCount = sizeof(whiteLeds) / sizeof(whiteLeds[0]);
int groupACount = sizeof(groupA) / sizeof(groupA[0]);
int groupBCount = sizeof(groupB) / sizeof(groupB[0]);
int groupCCount = sizeof(groupC) / sizeof(groupC[0]);

// =================================================
// ===== HELPER & UTILITY FUNCTIONS =====
// =================================================

void turnAllOff() {
  strip.clear();
  strip.show();
}

void resetLoopAnimation() {
  fadeStarted = false;
  fadeRound = 0;
  fadingIn = true;
  currentFadeBrightness = 0;
  lastFadeTime = 0;
  waveAngle = 0.0;
  ledsOffExceptRed = false;
  ledsHalfBrightOn = false;
  shootingStarsStarted = false;
  linearRound = linearStep = 0;
  lastLinearUpdate = 0;
  linearDelay = 0;
  linearAnimDone = false;
  randomStep = 0;
  lastRandomUpdate = 0;
  randomAnimDone = false;
  calmAnimationsStarted = false;
  calmBreathingAngle = 0.0;
  calmWaveAngle = 0.0;
  calmMode = 0;
  calmModeStartTime = 0;
  groupFadeAngle = 0.0;
  startTime = millis();
}

uint32_t pinkColor(uint8_t brightness) { return strip.Color(brightness, 0, brightness * 0.4); }
uint32_t whiteColor(uint8_t brightness) { return strip.Color(brightness, brightness, brightness); }

int findLedIndex(uint16_t target) {
  for (int i = 0; i < LED_COUNT; i++) {
    if (ledOrder[i] == target) return i;
  }
  return LED_COUNT / 2;
}

// =================================================
// ===== LOOPING ANIMATION FUNCTIONS =====
// =================================================
void breathingEffect() {
  calmBreathingAngle += 0.03;
  float brightness = (sin(calmBreathingAngle) + 1.0) * 0.5;
  for (int i = 0; i < LED_COUNT; i++) {
    if (i != 122 && i != 89) {
      uint32_t c = savedColors[i];
      uint8_t r = ((c >> 16) & 0xFF) * brightness;
      uint8_t g = ((c >> 8) & 0xFF) * brightness;
      uint8_t b = (c & 0xFF) * brightness;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
  }
}

void waveEffect() {
  calmWaveAngle += 0.15;
  for (int i = 0; i < LED_COUNT; i++) {
    if (i != 122 && i != 89) {
      float offset = i * 0.25;
      float brightness = (sin(calmWaveAngle + offset) + 1.0) * 0.5;
      uint32_t c = savedColors[i];
      uint8_t r = ((c >> 16) & 0xFF) * brightness;
      uint8_t g = ((c >> 8) & 0xFF) * brightness;
      uint8_t b = (c & 0xFF) * brightness;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
  }
}

void pulsingEffect() {
  float pulse = abs(sin(millis() / 1000.0));
  for (int i = 0; i < LED_COUNT; i++) {
    if (i != 122 && i != 89) {
      uint32_t c = savedColors[i];
      uint8_t r = ((c >> 16) & 0xFF) * pulse;
      uint8_t g = ((c >> 8) & 0xFF) * pulse;
      uint8_t b = (c & 0xFF) * pulse;
      strip.setPixelColor(i, strip.Color(r, g, b));
    }
  }
}

void fadeGroupsABC() {
  groupFadeAngle += 0.05;
  float brightness = (sin(groupFadeAngle) + 1.0) * 0.5;
  uint8_t value = brightness * 255;
  uint32_t color = strip.Color(value, value, value);
  for (int i = 0; i < groupACount; i++) strip.setPixelColor(groupA[i] - 1, color);
  for (int i = 0; i < groupBCount; i++) strip.setPixelColor(groupB[i] - 1, color);
  for (int i = 0; i < groupCCount; i++) strip.setPixelColor(groupC[i] - 1, color);
}

void updateCalmAnimations() {
  if (millis() - calmModeStartTime >= calmModeDuration) {
    calmMode = (calmMode + 1) % 3;
    calmModeStartTime = millis();
  }
  switch (calmMode) {
    case 0: breathingEffect(); break;
    case 1: waveEffect(); break;
    case 2: pulsingEffect(); break;
  }
  fadeGroupsABC();
  strip.show();
}

void updateMovingWave() {
  for (int i = 0; i < pinkCount; i++) {
    float offset = i * 0.3;
    float brightness = (sin(waveAngle + offset) + 1.0) * 127.5;
    strip.setPixelColor(pinkLeds[i] - 1, strip.Color((int)brightness, 0, (int)(brightness * 0.4)));
  }
  for (int i = 0; i < whiteCount; i++) {
    float offset = i * 0.3;
    float brightness = (sin(waveAngle + offset) + 1.0) * 127.5;
    strip.setPixelColor(whiteLeds[i] - 1, strip.Color((int)brightness, (int)brightness, (int)brightness));
  }
  waveAngle += 0.15;
}

void updateFadeGroups() {
  if (fadeStarted && fadeRound < 15) {
    unsigned long currentTime = millis();
    int fadeDelay = (fadeRound == 0) ? 12 : (fadeRound == 1) ? 8 : (fadeRound == 2) ? 5 : (fadeRound == 3) ? 3 : (fadeRound == 4) ? 2 : 1;
    if (currentTime - lastFadeTime >= fadeDelay) {
      lastFadeTime = currentTime;
      int brightnessStep = (fadeRound < 3) ? 8 : (fadeRound < 6) ? 12 : 20;
      if (fadingIn) {
        currentFadeBrightness += brightnessStep;
        if (currentFadeBrightness >= 255) { currentFadeBrightness = 255; fadingIn = false; }
      } else {
        currentFadeBrightness -= brightnessStep;
        if (currentFadeBrightness <= 0) { currentFadeBrightness = 0; fadingIn = true; fadeRound++; }
      }
      uint32_t fadeColor;
      if (fadeRound >= 8 && fadeRound <= 12) {
        float redTransition = (float)(fadeRound - 8) / 4.0;
        int red = currentFadeBrightness;
        int green = currentFadeBrightness * (1.0 - redTransition);
        int blue = currentFadeBrightness * (1.0 - redTransition);
        fadeColor = strip.Color(red, green, blue);
      } else if (fadeRound >= 13 && fadeRound <= 15) {
        fadeColor = strip.Color(currentFadeBrightness, 0, 0);
      } else {
        fadeColor = strip.Color(currentFadeBrightness, currentFadeBrightness, currentFadeBrightness);
      }
      for (int i = 0; i < groupACount; i++) strip.setPixelColor(groupA[i] - 1, fadeColor);
      for (int i = 0; i < groupBCount; i++) strip.setPixelColor(groupB[i] - 1, fadeColor);
      for (int i = 0; i < groupCCount; i++) strip.setPixelColor(groupC[i] - 1, fadeColor);
      strip.show();
      if (fadeRound == 15 && !ledsOffExceptRed) {
        for (int i = 0; i < LED_COUNT; i++) { savedColors[i] = strip.getPixelColor(i); }
        for (int i = 0; i < LED_COUNT; i++) {
          if (i != 122 && i != 89) strip.setPixelColor(i, 0);
        }
        strip.show();
        ledsOffExceptRed = true;
        ledsOffTime = millis();
      }
    }
  }
}

void turnOnHalfBrightnessSaved() {
  for (int i = 0; i < LED_COUNT; i++) {
    if (i != 122 && i != 89) {
      uint32_t c = savedColors[i];
      uint8_t r = (c >> 16) & 0xFF;
      uint8_t g = (c >> 8) & 0xFF;
      uint8_t b = c & 0xFF;
      strip.setPixelColor(i, strip.Color(r / 2, g / 2, b / 2));
    }
  }
  strip.show();
  ledsHalfBrightOn = true;
}

void updateRandomShootingStars() {
  if (randomAnimDone) return;
  unsigned long now = millis();
  if (now - lastRandomUpdate < 50) return;
  lastRandomUpdate = now;
  if (randomStep >= 20 * (18 + 3)) { randomAnimDone = true; return; }
  strip.setPixelColor(random(0, LED_COUNT), strip.Color(255, 255, 255));
  randomStep++;
}

void updateLinearShootingStar() {
  if (linearAnimDone) return;
  linearAnimDone = true; 
}

void runLoopAnimation() {
  unsigned long now = millis();
  if (!fadeStarted && now - startTime >= 3000) { fadeStarted = true; lastFadeTime = millis(); }
  if (fadeRound < 15) { updateMovingWave(); updateFadeGroups(); }
  else {
    if (ledsOffExceptRed && !ledsHalfBrightOn && now - ledsOffTime >= 2000) { turnOnHalfBrightnessSaved(); }
    if (ledsHalfBrightOn && !shootingStarsStarted) { shootingStarsStarted = true; lastLinearUpdate = lastRandomUpdate = millis(); linearRound = linearStep = 0; randomStep = 0; linearAnimDone = false; randomAnimDone = false; }
    if (shootingStarsStarted) {
      updateRandomShootingStars();
      updateLinearShootingStar();
      if (randomAnimDone && linearAnimDone && !calmAnimationsStarted) { calmStartTime = millis(); calmAnimationsStarted = true; calmModeStartTime = millis(); }
    }
    if (calmAnimationsStarted && millis() - calmStartTime >= 2000) { updateCalmAnimations(); }
  }
}

// =================================================
// ===== SOUND REACTIVE ANIMATION =====
// =================================================
void runSoundReactive() {
  int rawMic = analogRead(MIC_PIN);
  smoothedMic = (smoothingFactor * rawMic) + ((1.0 - smoothingFactor) * smoothedMic);
  int amplitude = abs(rawMic - smoothedMic);
  int centerIndex = findLedIndex(117);
  int waveRange = map(amplitude, 0, 400, 0, 80);
  int brightness = map(amplitude, 0, 400, 10, 255);
  for (int i = 0; i < pinkCount; i++) {
    int indexInOrder = findLedIndex(pinkLeds[i]);
    int dist = abs(indexInOrder - centerIndex);
    if (dist < waveRange) {
      float fade = 1.0 - ((float)dist / waveRange);
      strip.setPixelColor(pinkLeds[i] - 1, (uint8_t)(255 * fade), (uint8_t)(105 * fade), (uint8_t)(180 * fade));
    } else {
      strip.setPixelColor(pinkLeds[i] - 1, 0, 0, 0);
    }
  }
  for (int i = 0; i < whiteCount; i++) {
    int indexInOrder = findLedIndex(whiteLeds[i]);
    int dist = abs(indexInOrder - centerIndex);
    if (dist < waveRange) {
      float fade = 1.0 - ((float)dist / waveRange);
      uint8_t level = brightness * fade;
      strip.setPixelColor(whiteLeds[i] - 1, level, level, level);
    } else {
      strip.setPixelColor(whiteLeds[i] - 1, 0, 0, 0);
    }
  }
  int activeLeds = map(amplitude, 0, 400, 0, volumeBarCount);
  for (int i = 0; i < volumeBarCount; i++) {
    if (i < activeLeds) {
      int redIntensity = map(amplitude, 0, 400, 100, 255);
      int whiteFade = map(amplitude, 0, 400, 180, 0);
      uint8_t g = constrain(whiteFade, 0, 255);
      uint8_t b = constrain(whiteFade / 2, 0, 255);
      strip.setPixelColor(volumeBarLeds[i] - 1, redIntensity, g, b);
    } else {
      strip.setPixelColor(volumeBarLeds[i] - 1, 0, 0, 0);
    }
  }
  for (int i = 0; i < sizeof(fixedRedLeds)/sizeof(fixedRedLeds[0]); i++) {
    strip.setPixelColor(fixedRedLeds[i] - 1, 255, 0, 0);
  }
  strip.show();
}

// =================================================
// ===== COMMAND & COMMUNICATION HANDLING =====
// =================================================

void handleCommand(String cmd) {
  Serial.print("Received Command: ");
  Serial.println(cmd);
  if (cmd == "CMD:LOOP_ANIM") {
    Serial.println("Switching to Loop Animation Mode");
    activeAnimation = MODE_LOOP_ANIMATION;
    resetLoopAnimation();
  } else if (cmd == "CMD:SOUND_MODE") {
    Serial.println("Switching to Sound Reactive Mode");
    activeAnimation = MODE_SOUND_REACTIVE;
  } else if (cmd == "CMD:OFF") {
    Serial.println("Switching to Off Mode");
    activeAnimation = MODE_OFF;
    turnAllOff();
  }
}

class MyServerCallbacks: public BLEServerCallbacks {
    void onDisconnect(BLEServer* pServer) {
      Serial.println("BLE Client Disconnected. Restarting advertising.");
      delay(500); // Give a moment before restarting
      pAdvertising->start();
    }
};

class MyCharacteristicCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* characteristic) {
    String value = characteristic->getValue();
    if (value.length() > 0) {
      handleCommand(value);
    }
  }
};

void checkWifiClient() {
  client = wifiServer.available();
  if (client) {
    Serial.println("WiFi Client Connected!");
    String currentLine = "";
    while (client.connected()) {
      if (client.available()) {
        char c = client.read();
        if (c == '\n') {
          if (currentLine.length() > 0) {
            handleCommand(currentLine);
          }
          currentLine = "";
        } else if (c != '\r') {
          currentLine += c;
        }
      }
    }
    client.stop();
    Serial.println("WiFi Client Disconnected.");
  }
}

// =================================================
// ===== MAIN SETUP & LOOP =====
// =================================================

void setup() {
  Serial.begin(115200);
  
  strip.begin();
  strip.show();
  analogReadResolution(10);

  WiFi.softAP(ssid, password);
  wifiServer.begin();
  Serial.println("WiFi Access Point Started");
  Serial.print("SSID: "); Serial.println(ssid);
  Serial.print("IP: "); Serial.println(WiFi.softAPIP());

  BLEDevice::init("Animight_ESP32");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());
  BLEService *pService = pServer->createService(SERVICE_UUID);
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
                                         CHARACTERISTIC_UUID,
                                         BLECharacteristic::PROPERTY_WRITE
                                       );
  pCharacteristic->setCallbacks(new MyCharacteristicCallbacks());
  pService->start();
  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();
  Serial.println("BLE Advertising Started");

  turnAllOff();
}

void loop() {
  checkWifiClient();

  switch(activeAnimation) {
    case MODE_OFF:
      break;
    case MODE_LOOP_ANIMATION:
      runLoopAnimation();
      break;
    case MODE_SOUND_REACTIVE:
      runSoundReactive();
      break;
  }
  // Add a small delay to the main loop to keep things stable
  delay(20);
}