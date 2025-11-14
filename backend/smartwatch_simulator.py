"""
Realistic Smartwatch Health Data Simulator
Generates 24h health cycles with natural patterns and sends to Firestore
"""
import os
import time
import math
import random
from datetime import datetime, timedelta
from typing import Dict
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
cred = credentials.Certificate("serviceAccountKey.json")  # UPDATE THIS PATH
firebase_admin.initialize_app(cred)
db = firestore.client()

# User configuration
USER_ID = "V8Fj1w8CJhPJsUgu2mB4XDPzEJs2"  # UPDATE WITH REAL USER ID
INTERVAL_MINUTES = 1  # Send data every 1 minutes

class HealthSimulator:
    def __init__(self, user_id: str):
        self.user_id = user_id
        self.start_time = datetime.now()
        self.base_resting_hr = 60
        self.base_hrv = 50

    def get_time_of_day_factor(self, current_time: datetime) -> Dict[str, float]:
        """Calculate factors based on circadian rhythm"""
        hour = current_time.hour
        minute = current_time.minute
        time_decimal = hour + minute / 60.0

        # Sleep phase (23:00 - 7:00)
        if 23 <= hour or hour < 7:
            return {
                'hr_multiplier': 0.75,  # Lower HR during sleep
                'hrv_multiplier': 1.3,  # Higher HRV during deep sleep
                'activity': 0,
                'is_sleeping': True
            }

        # Morning wake-up (7:00 - 9:00)
        elif 7 <= hour < 9:
            wake_progress = (time_decimal - 7) / 2.0
            return {
                'hr_multiplier': 0.75 + (0.25 * wake_progress),
                'hrv_multiplier': 1.3 - (0.3 * wake_progress),
                'activity': wake_progress * 0.3,
                'is_sleeping': False
            }

        # Mid-morning activity (9:00 - 12:00)
        elif 9 <= hour < 12:
            return {
                'hr_multiplier': 1.1,
                'hrv_multiplier': 0.95,
                'activity': 0.6,
                'is_sleeping': False
            }

        # Lunch dip (12:00 - 14:00)
        elif 12 <= hour < 14:
            return {
                'hr_multiplier': 0.95,
                'hrv_multiplier': 1.05,
                'activity': 0.3,
                'is_sleeping': False
            }

        # Afternoon peak (14:00 - 18:00)
        elif 14 <= hour < 18:
            return {
                'hr_multiplier': 1.15,
                'hrv_multiplier': 0.85,
                'activity': 0.8,
                'is_sleeping': False
            }

        # Evening wind-down (18:00 - 21:00)
        elif 18 <= hour < 21:
            wind_down = (time_decimal - 18) / 3.0
            return {
                'hr_multiplier': 1.1 - (0.2 * wind_down),
                'hrv_multiplier': 0.9 + (0.2 * wind_down),
                'activity': 0.5 - (0.3 * wind_down),
                'is_sleeping': False
            }

        # Pre-sleep (21:00 - 23:00)
        else:
            return {
                'hr_multiplier': 0.85,
                'hrv_multiplier': 1.15,
                'activity': 0.1,
                'is_sleeping': False
            }

    def generate_metrics(self, current_time: datetime) -> Dict:
        """Generate realistic health metrics for current time"""
        factors = self.get_time_of_day_factor(current_time)

        # Heart rate with natural variation
        hr = self.base_resting_hr * factors['hr_multiplier']
        hr += random.gauss(0, 2)  # Small natural variation

        # Resting heart rate (slower change)
        resting_hr = self.base_resting_hr + random.gauss(0, 1)

        # HRV (inversely related to stress/activity)
        hrv = self.base_hrv * factors['hrv_multiplier']
        hrv += random.gauss(0, 3)

        # Steps (accumulated based on activity)
        steps_per_interval = int(factors['activity'] * random.uniform(100, 300))

        # Calories (based on activity + basal metabolic rate)
        basal_cal_per_min = 1.2
        active_cal_per_min = factors['activity'] * 5
        calories = (basal_cal_per_min + active_cal_per_min) * INTERVAL_MINUTES

        # Active minutes
        active_minutes = int(factors['activity'] * INTERVAL_MINUTES)

        # SpO2 (very stable, slight variation)
        spo2 = 97 + random.gauss(0, 0.5)
        spo2 = max(94, min(100, spo2))  # Clamp to realistic range

        return {
            'userId': self.user_id,
            'timestamp': current_time,
            'heartRate': round(max(45, min(120, hr)), 1),
            'restingHeartRate': round(max(50, min(75, resting_hr)), 1),
            'hrv': round(max(20, min(100, hrv)), 1),
            'steps': steps_per_interval,
            'calories': round(calories, 1),
            'activeMinutes': active_minutes,
            'spo2': round(spo2, 1),
            'is_sleeping': factors['is_sleeping']
        }

    def generate_sleep_data(self, date: datetime) -> Dict:
        """Generate sleep data for the night"""
        # Realistic sleep patterns
        duration = random.gauss(7.5, 0.5)  # 7-8 hours average
        duration = max(5.5, min(9.5, duration))

        # Quality based on duration and HRV
        quality = 70 + (duration - 6) * 5 + random.gauss(0, 5)
        quality = max(40, min(100, quality))

        # Sleep stages (proportions)
        total_minutes = int(duration * 60)
        deep_pct = 0.15 + random.uniform(-0.03, 0.03)
        rem_pct = 0.25 + random.uniform(-0.05, 0.05)
        light_pct = 1 - deep_pct - rem_pct

        sleep_date = datetime(date.year, date.month, date.day)

        return {
            'userId': self.user_id,
            'date': sleep_date,
            'durationHours': round(duration, 2),
            'qualityScore': round(quality, 1),
            'deepSleepMinutes': int(total_minutes * deep_pct),
            'remSleepMinutes': int(total_minutes * rem_pct),
            'lightSleepMinutes': int(total_minutes * light_pct)
        }

    def send_to_firestore(self, collection: str, data: Dict):
        """Send data to Firestore"""
        try:
            doc_id = f"{self.user_id}_{int(time.time() * 1000)}"
            data['id'] = doc_id

            # Convert string timestamps to datetime if needed
            if 'timestamp' in data and isinstance(data['timestamp'], str):
                data['timestamp'] = datetime.fromisoformat(data['timestamp'])
            if 'date' in data and isinstance(data['date'], str):
                data['date'] = datetime.fromisoformat(data['date'])

            # Send to user's subcollection: users/{userId}/{collection}
            db.collection('users').document(self.user_id).collection(collection).document(doc_id).set(data)

            log_value = data.get('timestamp', data.get('date'))
            if isinstance(log_value, datetime):
                log_value = log_value.isoformat()
            print(f"✓ Sent {collection}: {log_value}")
        except Exception as e:
            print(f"✗ Error sending to Firestore: {e}")

    def run_simulation(self):
        """Run continuous simulation"""
        print(f"🏃 Starting health data simulation for user: {self.user_id}")
        print(f"📊 Sending data every {INTERVAL_MINUTES} minutes")

        last_sleep_date = None

        while True:
            current_time = datetime.now()

            # Generate and send health metrics
            metrics = self.generate_metrics(current_time)
            self.send_to_firestore('health_metrics', metrics)

            # Send sleep data once per day (morning)
            if current_time.hour == 00 and current_time.date() != last_sleep_date:
                sleep_data = self.generate_sleep_data(current_time)
                self.send_to_firestore('sleep_data', sleep_data)
                last_sleep_date = current_time.date()

            # Wait for next interval
            time.sleep(INTERVAL_MINUTES * 60)

if __name__ == "__main__":
    simulator = HealthSimulator(USER_ID)
    simulator.run_simulation()