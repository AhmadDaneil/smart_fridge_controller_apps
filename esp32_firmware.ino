#include <Wire.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "DHTesp.h"
#include <Ticker.h>

// ==========================
// WIFI SETTINGS
// ==========================
const char* ssid     = "realme C2";
const char* password = "030507080191";

// ==========================
// SUPABASE SETTINGS
// ==========================
const char* supabaseUrl = "https://zthfjixdcbdqqncfnoql.supabase.co/rest/v1/sensor_readings";
const char* supabaseKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inp0aGZqaXhkY2JkcXFuY2Zub3FsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNzYyNzgsImV4cCI6MjA5Njc1MjI3OH0.nJV_08O7KqMm3U0UZYW3y-2tN_Y7RPk3_hPG9bh6Tds";

// ==========================
// OLED SETTINGS
// ==========================
#define SCREEN_WIDTH   128
#define SCREEN_HEIGHT  64
#define OLED_RESET     -1
#define SCREEN_ADDRESS 0x3C
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);

// ==========================
// DHT22 SETTINGS
// ==========================
DHTesp dht;
const int dhtPin = 17;

// ==========================
// REED SWITCH SETTINGS
// ==========================
const int reedPin = 4;

// ==========================
// LED SETTINGS
// ==========================
const int   ledPin        = 23;
const float tempThreshold = 30.0;
const int   doorOpenLimit = 10000;

// ==========================
// TASK SETTINGS
// ==========================
TaskHandle_t tempTaskHandle = NULL;
Ticker tempTicker;
bool tasksEnabled = false;

// ==========================
// VARIABLES
// ==========================
float temperature  = 0;
float humidity     = 0;
bool  doorOpen     = false;
unsigned long doorOpenTime = 0;
bool  doorAlerted  = false;
bool  tempAlerted  = false;
bool  ledTempAlert = false;
bool  ledDoorAlert = false;

// ==========================
// FUNCTION DECLARATIONS
// ==========================
void tempTask(void *pvParameters);
bool getTemperature();
void triggerGetTemp();
void ledBlink(int times);
void sendToSupabase();
void updateOLED();
void showWifiConnecting();
void showWifiConnected();

// ============================================================
// SETUP
// ============================================================
void setup() {
  Serial.begin(115200);

  if (!display.begin(SSD1306_SWITCHCAPVCC, SCREEN_ADDRESS)) {
    Serial.println("SSD1306 failed!");
    while (true);
  }

  display.clearDisplay();
  display.setTextSize(2);
  display.setTextColor(WHITE);
  display.setCursor(10, 20);
  display.println("STARTING");
  display.display();
  delay(1500);

  pinMode(ledPin, OUTPUT);
  digitalWrite(ledPin, LOW);
  pinMode(reedPin, INPUT_PULLUP);   // FIX — use INPUT_PULLUP for reed switch

  ledBlink(2);

  showWifiConnecting();
  WiFi.begin(ssid, password);
  int retry = 0;
  while (WiFi.status() != WL_CONNECTED && retry < 20) {
    delay(500);
    Serial.print(".");
    retry++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    showWifiConnected();
    delay(1500);
  } else {
    Serial.println("\nWiFi FAILED");
    display.clearDisplay();
    display.setTextSize(1);
    display.setCursor(0, 20);
    display.println("WiFi FAILED");
    display.println("Running offline..");
    display.display();
    delay(2000);
  }

  dht.setup(dhtPin, DHTesp::DHT22);
  xTaskCreatePinnedToCore(tempTask, "tempTask", 4000, NULL, 5, &tempTaskHandle, 1);
  if (tempTaskHandle != NULL) {
    tempTicker.attach(5, triggerGetTemp);
  }

  tasksEnabled = true;
  if (tempTaskHandle != NULL) {
    vTaskResume(tempTaskHandle);
  }
}

// ============================================================
// LOOP
// ============================================================
void loop() {

  // FIX — LOW means magnet present (door CLOSED), HIGH means door OPEN
  bool currentDoorState = (digitalRead(reedPin) == LOW);

  if (currentDoorState != doorOpen) {
    delay(50);   // FIX — shorter debounce (was 500ms, too slow)
    bool confirmState = (digitalRead(reedPin) == LOW);   // FIX — match same logic

    if (confirmState == currentDoorState) {
      doorOpen = currentDoorState;

      if (doorOpen) {
        doorOpenTime = millis();
        doorAlerted  = false;
        ledDoorAlert = false;
        Serial.println("Pintu DIBUKA");
      } else {
        Serial.println("Pintu DITUTUP");
        doorAlerted  = false;
        ledDoorAlert = false;
        doorOpenTime = 0;
        digitalWrite(ledPin, LOW);
      }
    }
  }

  // Check pintu buka lama
  if (doorOpen && !doorAlerted) {
    if (millis() - doorOpenTime >= doorOpenLimit) {
      Serial.println("ALERT: Pintu terbuka terlalu lama!");
      doorAlerted  = true;
      ledDoorAlert = true;
    }
  }

  // LED door alert
  if (ledDoorAlert && doorOpen) {
    ledBlink(3);
    ledDoorAlert = false;
  } else if (!doorOpen) {
    digitalWrite(ledPin, LOW);
  }

  // LED temp alert
  if (ledTempAlert) {
    ledBlink(2);
    ledTempAlert = false;
  }

  updateOLED();
  delay(300);
}

// ============================================================
// TASK: Baca DHT22
// ============================================================
void tempTask(void *pvParameters) {
  while (1) {
    if (tasksEnabled) { getTemperature(); }
    vTaskSuspend(NULL);
  }
}

void triggerGetTemp() {
  if (tempTaskHandle != NULL) { xTaskResumeFromISR(tempTaskHandle); }
}

// ============================================================
// BACA DHT22 + HANTAR KE SUPABASE
// ============================================================
bool getTemperature() {
  TempAndHumidity data = dht.getTempAndHumidity();
  if (dht.getStatus() != 0) {
    Serial.println("DHT22 Error: " + String(dht.getStatusString()));
    return false;
  }

  temperature = data.temperature;
  humidity    = data.humidity;

  Serial.println("Temp: "     + String(temperature) + " C");
  Serial.println("Humidity: " + String(humidity)    + " %");
  Serial.println("Door: "     + String(doorOpen ? "OPEN" : "CLOSED"));
  Serial.println("------------------------");

  if (temperature > tempThreshold && !tempAlerted) {
    Serial.println("WARNING: SUHU TINGGI!");
    ledTempAlert = true;
    tempAlerted  = true;
  } else if (temperature <= tempThreshold) {
    tempAlerted = false;
  }

  if (WiFi.status() == WL_CONNECTED) { sendToSupabase(); }   // FIX — no parameters
  return true;
}

// ============================================================
// HANTAR DATA KE SUPABASE — FIXED
// ============================================================
void sendToSupabase() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  http.begin(supabaseUrl);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", supabaseKey);
  http.addHeader("Authorization", String("Bearer ") + supabaseKey);
  http.addHeader("Prefer", "return=minimal");

  String payload = "{";
  payload += "\"temperature\":"  + String(temperature, 1) + ",";
  payload += "\"humidity\":"     + String(humidity, 1)    + ",";
  payload += "\"door_open\":"    + String(doorOpen ? "true" : "false");
  payload += "}";

  Serial.println("Sending: " + payload);

  int httpCode = http.POST(payload);

  if (httpCode == 201) {
    Serial.println("Supabase OK ✓");
  } else {
    Serial.println("Supabase ERROR: " + String(httpCode));
    Serial.println(http.getString());
  }

  http.end();
}

// ============================================================
// UPDATE OLED
// ============================================================
void updateOLED() {
  display.clearDisplay();
  display.setTextColor(WHITE);

  display.setTextSize(1);
  display.setCursor(10, 0);
  display.println("SMART FRIDGE");
  display.drawLine(0, 10, 128, 10, WHITE);

  display.setCursor(0, 14);
  display.print("Temp:");
  display.setTextSize(2);
  display.setCursor(0, 23);
  display.print(temperature, 1);
  display.print("C");

  display.setTextSize(1);
  display.setCursor(80, 14);
  display.print("Hum:");
  display.setCursor(80, 24);
  display.print(humidity, 1);
  display.print("%");

  display.drawLine(0, 43, 128, 43, WHITE);
  display.setTextSize(1);
  display.setCursor(0, 46);
  display.print("Door: ");
  display.print(doorOpen ? "OPEN" : "CLOSED");

  if (temperature > tempThreshold) {
    display.setCursor(70, 46);
    display.print("!TEMP!");
  }

  if (doorOpen && doorAlerted) {
    display.setCursor(0, 56);
    display.print("DOOR OPEN TOO LONG!");
  }

  display.display();
}

// ============================================================
// LED BLINK
// ============================================================
void ledBlink(int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(ledPin, HIGH);
    delay(300);
    digitalWrite(ledPin, LOW);
    delay(300);
  }
}

// ============================================================
// WIFI STATUS OLED
// ============================================================
void showWifiConnecting() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(10, 20);
  display.println("Connecting WiFi..");
  display.display();
}

void showWifiConnected() {
  display.clearDisplay();
  display.setTextSize(1);
  display.setTextColor(WHITE);
  display.setCursor(15, 15);
  display.println("WiFi Connected!");
  display.setCursor(5, 30);
  display.println(WiFi.localIP().toString());
  display.display();
}