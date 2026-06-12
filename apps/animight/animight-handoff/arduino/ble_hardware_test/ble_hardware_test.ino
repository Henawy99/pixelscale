#include <Adafruit_NeoPixel.h>

#define LED_PIN     5
#define NUM_LEDS    180

Adafruit_NeoPixel strip = Adafruit_NeoPixel(NUM_LEDS, LED_PIN, NEO_GRB + NEO_KHZ800);

uint32_t pinkColor(uint8_t brightness) {
  return strip.Color(brightness, 0, brightness * 0.4);
}

uint32_t whiteColor(uint8_t brightness) {
  return strip.Color(brightness, brightness, brightness);
}

uint32_t whiteFlashColor = strip.Color(255, 255, 255);

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

int pinkLeds[] = {150,149,148,147,146,145,144,143,142,141,140,139,138,137,136,135,134,133,155,156,157,158,159,160,161,162,163,164,165,166,167,10,11,12,13,14,15,16,17,18,43,42,41,47,46};
int whiteLeds[] = {1,2,3,4,5,6,7,8,9,20,21,22,23,180,179,178,177,168,169,170,105,104,103,102,101,100,99,98,97,96,95,94,93,92,91,88,109,110,111,112,113,114,115,116,117,118,119,120,121,122,124,125,126,127,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,60,59,58,57,56,55,54,53,52,51,50,49,48,45,44};
int groupA[] = {86, 85, 84};
int groupB[] = {35, 34, 33, 32, 31, 30, 29, 28, 27, 26};
int groupC[] = {174, 173, 172, 171};
int shootingTailLeds[] = {87, 86, 85, 84, 35, 34, 33, 32, 31, 30, 29, 28, 27, 26, 174, 173, 172, 171};

int pinkCount = sizeof(pinkLeds) / sizeof(pinkLeds[0]);
int whiteCount = sizeof(whiteLeds) / sizeof(whiteLeds[0]);
int groupACount = sizeof(groupA) / sizeof(groupA[0]);
int groupBCount = sizeof(groupB) / sizeof(groupB[0]);
int groupCCount = sizeof(groupC) / sizeof(groupC[0]);
int shootingTailCount = sizeof(shootingTailLeds) / sizeof(shootingTailLeds[0]);

uint32_t savedColors[NUM_LEDS];

int linearRound = 0, linearStep = 0;
unsigned long lastLinearUpdate = 0;
unsigned long linearDelay = 0;
bool linearAnimDone = false;

int randomStep = 0;
unsigned long lastRandomUpdate = 0;
bool randomAnimDone = false;
int positions[5] = {0};

// Calm animations
bool calmAnimationsStarted = false;
unsigned long calmStartTime = 0;
float calmBreathingAngle = 0.0;
float calmWaveAngle = 0.0;
int calmMode = 0;
unsigned long calmModeStartTime = 0;
const unsigned long calmModeDuration = 8000;

// Fade for ABC groups
float groupFadeAngle = 0.0;
void setup() {
  strip.begin();
  strip.show();
  delay(500);

  int redLeds[] = {123, 90};
  for (int b = 0; b <= 255; b++) {
    for (int i = 0; i < 2; i++) {
      strip.setPixelColor(redLeds[i] - 1, strip.Color(b, 0, 0));
    }
    strip.show();
    delay(5);
  }

  for (int b = 0; b <= 255; b++) {
    uint32_t pink = pinkColor(b);
    uint32_t white = whiteColor(b);
    for (int i = 0; i < pinkCount; i++) strip.setPixelColor(pinkLeds[i] - 1, pink);
    for (int i = 0; i < whiteCount; i++) strip.setPixelColor(whiteLeds[i] - 1, white);
    strip.show();
    delay(3);
  }

  int delayPerLED = 30;
  auto lightGroup = [&](int* group, int count) {
    for (int i = 0; i < count; i++) {
      strip.setPixelColor(group[i] - 1, whiteFlashColor);
      strip.show();
      delay(delayPerLED);
    }
  };
  lightGroup(groupA, groupACount);
  delay(delayPerLED);
  lightGroup(groupB, groupBCount);
  delay(delayPerLED);
  lightGroup(groupC, groupCCount);

  startTime = millis();
}
void breathingEffect() {
  calmBreathingAngle += 0.03;
  float brightness = (sin(calmBreathingAngle) + 1.0) * 0.5;

  for (int i = 0; i < NUM_LEDS; i++) {
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
  for (int i = 0; i < NUM_LEDS; i++) {
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
  for (int i = 0; i < NUM_LEDS; i++) {
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

  fadeGroupsABC(); // يشتغل دايمًا مع الأنيميشنات
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
        if (currentFadeBrightness >= 255) {
          currentFadeBrightness = 255;
          fadingIn = false;
        }
      } else {
        currentFadeBrightness -= brightnessStep;
        if (currentFadeBrightness <= 0) {
          currentFadeBrightness = 0;
          fadingIn = true;
          fadeRound++;
        }
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
        for (int i = 0; i < NUM_LEDS; i++) {
          savedColors[i] = strip.getPixelColor(i);
        }
        for (int i = 0; i < NUM_LEDS; i++) {
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
  for (int i = 0; i < NUM_LEDS; i++) {
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

  if (randomStep >= 20 * (shootingTailCount + 3)) {
    for (int i = 0; i < 5; i++) {
      strip.setPixelColor(positions[i], savedColors[positions[i]]);
    }
    strip.show();
    randomAnimDone = true;
    return;
  }

  for (int i = 0; i < 5; i++) {
    strip.setPixelColor(positions[i], savedColors[positions[i]]);
    positions[i] = random(0, NUM_LEDS);
    strip.setPixelColor(positions[i], strip.Color(255, 255, 255));
  }

  strip.show();
  randomStep++;
}

void updateLinearShootingStar() {
  if (linearAnimDone) return;

  unsigned long now = millis();
  if (now - lastLinearUpdate < linearDelay) return;

  lastLinearUpdate = now;

  if (linearRound >= 20) {
    linearAnimDone = true;
    return;
  }

  uint32_t color;
  if (linearRound < 5) color = strip.Color(255, 255, 255);
  else if (linearRound < 10) color = strip.Color(255, 105, 180);
  else color = strip.Color(255, 0, 0);

  linearDelay = max(1, 40 - linearRound * 7);

  for (int t = 0; t < 3; t++) {
    int tailIndex = linearStep - t;
    if (tailIndex >= 0 && tailIndex < shootingTailCount) {
      int ledIndex = shootingTailLeds[tailIndex] - 1;
      float brightnessFactor = 1.0 - (t * 0.33);
      uint8_t r = ((color >> 16) & 0xFF) * brightnessFactor;
      uint8_t g = ((color >> 8) & 0xFF) * brightnessFactor;
      uint8_t b = (color & 0xFF) * brightnessFactor;
      strip.setPixelColor(ledIndex, strip.Color(r, g, b));
    }
  }

  strip.show();
  linearStep++;

  if (linearStep >= shootingTailCount + 3) {
    linearStep = 0;
    linearRound++;
    for (int i = 0; i < shootingTailCount; i++) {
      int ledIndex = shootingTailLeds[i] - 1;
      strip.setPixelColor(ledIndex, savedColors[ledIndex]);
    }
    strip.show();
  }
}
void loop() {
  unsigned long now = millis();

  if (!fadeStarted && now - startTime >= 3000) {
    fadeStarted = true;
    lastFadeTime = millis();
  }

  if (fadeRound < 15) {
    updateMovingWave();
    updateFadeGroups();
  } else {
    if (ledsOffExceptRed && !ledsHalfBrightOn && now - ledsOffTime >= 2000) {
      turnOnHalfBrightnessSaved();
    }

    if (ledsHalfBrightOn && !shootingStarsStarted) {
      shootingStarsStarted = true;
      lastLinearUpdate = lastRandomUpdate = millis();
      linearRound = linearStep = 0;
      randomStep = 0;
      linearAnimDone = false;
      randomAnimDone = false;
    }

    if (shootingStarsStarted) {
      updateRandomShootingStars();
      updateLinearShootingStar();

      if (randomAnimDone && linearAnimDone && !calmAnimationsStarted) {
        calmStartTime = millis();
        calmAnimationsStarted = true;
        calmModeStartTime = millis();
      }
    }

    if (calmAnimationsStarted && millis() - calmStartTime >= 2000) {
      updateCalmAnimations();
    }
  }

  delay(20);
  if (millis() - startTime >= 106000) {
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

  strip.clear();
  strip.show();

  delay(100);  // تأخير بسيط قبل البدء من جديد
  startTime = millis();  // إعادة تعيين وقت البدء
}
}