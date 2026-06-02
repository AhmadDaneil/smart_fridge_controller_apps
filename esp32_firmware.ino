/*
 * CHILL CODERS – ESP32 IoT Firmware (ITT569)
 * Reads DHT22 (temp/humidity) + HX711 (weight)
 * Sends data to Supabase every 30 seconds via HTTPS
 *
 * Libraries required (install via Arduino Library Manager):
 *   - DHT sensor library by Adafruit
 *   - HX711 Arduino Library by bogde
 *   - ArduinoJson by Benoit Blanchon
 *   - HTTPClient (built into ESP32 board package)
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <HX711.h>

// ─── Configuration ─────────────────────────────────────────────────────────
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

const char* SUPABASE_URL  = "https://YOUR_PROJECT.supabase.co/rest/v1/sensor_readings";
const char* SUPABASE_KEY  = "YOUR_ANON_KEY";

// ─── Pin Definitions ───────────────────────────────────────────────────────
#define DHT_PIN       4     // GPIO4 → DHT22 data pin
#define DHT_TYPE      DHT22

#define HX711_DOUT    16    // GPIO16 → HX711 DT
#define HX711_SCK     17    // GPIO17 → HX711 SCK

#define BUZZER_PIN    18    // GPIO18 → Buzzer
#define LED_GREEN     19    // GPIO19 → Green LED (normal)
#define LED_RED       21    // GPIO21 → Red LED (alert)

// LCD (I2C) – connect SDA→GPIO21, SCL→GPIO22
// Uncomment if using LCD:
// #include <LiquidCrystal_I2C.h>
// LiquidCrystal_I2C lcd(0x27, 16, 2);

// ─── Temperature thresholds ───────────────────────────────────────────────
const float TEMP_MIN = 1.0;   // °C
const float TEMP_MAX = 8.0;   // °C

// ─── Objects ──────────────────────────────────────────────────────────────
DHT    dht(DHT_PIN, DHT_TYPE);
HX711  scale;

// ─── Calibration ──────────────────────────────────────────────────────────
// Run calibration sketch first to find your scale factor
float SCALE_FACTOR = 420.0;   // Adjust after calibration

// ─── Globals ──────────────────────────────────────────────────────────────
unsigned long lastSendTime = 0;
const unsigned long SEND_INTERVAL = 30000; // 30 seconds

// ──────────────────────────────────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  delay(500);

  // GPIO setup
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_GREEN, OUTPUT);
  pinMode(LED_RED, OUTPUT);

  // Init sensors
  dht.begin();
  scale.begin(HX711_DOUT, HX711_SCK);
  scale.set_scale(SCALE_FACTOR);
  scale.tare(); // Reset scale to zero

  // Init LCD
  // lcd.init(); lcd.backlight();
  // lcd.print("Chill Coders");

  Serial.println("Chill Coders IoT – Smart Fridge System");
  Serial.println("Connecting to WiFi...");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi connected! IP: " + WiFi.localIP().toString());
    blinkLED(LED_GREEN, 3);
  } else {
    Serial.println("\nWiFi failed! Running offline.");
    blinkLED(LED_RED, 5);
  }
}

// ──────────────────────────────────────────────────────────────────────────
void loop() {
  unsigned long now = millis();

  // Read sensors
  float temperature = dht.readTemperature();
  float humidity    = dht.readHumidity();
  float weight      = scale.get_units(5); // Average 5 readings
  if (weight < 0) weight = 0;

  // Validate readings
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("DHT22 read error!");
    delay(2000);
    return;
  }

  Serial.printf("Temp: %.1f°C  Humidity: %.1f%%  Weight: %.0fg\n",
    temperature, humidity, weight);

  // Handle alerts
  bool tempAlert = (temperature < TEMP_MIN || temperature > TEMP_MAX);
  updateIndicators(tempAlert);

  // Update LCD
  // updateLCD(temperature, humidity, weight);

  // Send to Supabase every interval
  if (now - lastSendTime >= SEND_INTERVAL) {
    if (WiFi.status() == WL_CONNECTED) {
      bool sent = sendToSupabase(temperature, humidity, weight);
      if (sent) {
        Serial.println("Data sent to Supabase ✓");
        lastSendTime = now;
      }
    } else {
      Serial.println("WiFi disconnected, attempting reconnect...");
      WiFi.reconnect();
    }
  }

  delay(2000);
}

// ──────────────────────────────────────────────────────────────────────────
bool sendToSupabase(float temp, float hum, float weight) {
  HTTPClient http;
  http.begin(SUPABASE_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Prefer", "return=minimal");

  // Build JSON
  StaticJsonDocument<256> doc;
  doc["temperature"]         = round(temp * 10.0) / 10.0;
  doc["humidity"]            = round(hum * 10.0) / 10.0;
  doc["total_weight_grams"]  = round(weight);

  String payload;
  serializeJson(doc, payload);

  int httpCode = http.POST(payload);
  bool success = (httpCode == 201);

  if (!success) {
    Serial.printf("HTTP error: %d – %s\n", httpCode, http.getString().c_str());
  }

  http.end();
  return success;
}

// ──────────────────────────────────────────────────────────────────────────
void updateIndicators(bool alert) {
  if (alert) {
    digitalWrite(LED_GREEN, LOW);
    digitalWrite(LED_RED, HIGH);
    // Sound buzzer briefly
    tone(BUZZER_PIN, 1000, 200);
    delay(300);
    tone(BUZZER_PIN, 800, 200);
  } else {
    digitalWrite(LED_GREEN, HIGH);
    digitalWrite(LED_RED, LOW);
    noTone(BUZZER_PIN);
  }
}

// ──────────────────────────────────────────────────────────────────────────
void blinkLED(int pin, int times) {
  for (int i = 0; i < times; i++) {
    digitalWrite(pin, HIGH);
    delay(200);
    digitalWrite(pin, LOW);
    delay(200);
  }
}

/*
void updateLCD(float temp, float hum, float weight) {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.printf("T:%.1fC H:%.0f%%", temp, hum);
  lcd.setCursor(0, 1);
  lcd.printf("Wt:%.0fg", weight);
}
*/
