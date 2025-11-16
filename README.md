![Python](https://img.shields.io/badge/python-3.13-blue)
![Flutter](https://img.shields.io/badge/flutter-3.13-blueviolet)
![Firebase](https://img.shields.io/badge/Firebase-Backend-yellow)
![Azure](https://img.shields.io/badge/Microsoft_Azure-Cloud-blue)
![Docker](https://img.shields.io/badge/Docker-Containerization-2496ED)
![License](https://img.shields.io/badge/license-MIT-green)

<p align="left">
  <img src="assets/images/logo.png" width="100" alt="App Logo">
</p>

**StressOFF** is an AI-powered wellness application designed to improve stress management, nutrition habits, and physiological balance.  
By combining smart meal analysis, real-time biometric monitoring, and calendar-aware insights, StressOFF delivers a personalized and proactive well-being experience.

The app helps users:

- Maintain healthier eating patterns  
- Improve recovery and energy levels  
- Prevent stress and fatigue peaks  
- Receive actionable, context-aware guidance powered by an AI coach  

---

## 🚀 Key Features

### **1. Smart Meal Analysis (AI-Powered)**  
- Snap a photo of any meal and select its type: breakfast, lunch, dinner, or snack.  
- The AI identifies ingredients, estimates nutritional values, and generates personalized dietary suggestions.  
- Two usage modes:  
  - **Meal Analysis** — saves the evaluation to Firebase  
  - **Try Analysis** — instant analysis without saving  


### **2. Daily Summary & Personalized Recommendations**  
Every evening, StressOFF generates a detailed review including:  
- Total calorie intake  
- Nutritional balance  
- Detected excesses or deficiencies  
- Recommendations to improve the next day's meals  


### **3. Real-Time Physiological Monitoring**  
Connected to a smartwatch, StressOFF tracks:  
- Heart Rate (HR)  
- Heart Rate Variability (HRV)  
- Blood Oxygen Level (SpO₂)  
- Active minutes and calories burned  
- Sleep duration and quality  

Instant alerts are sent when anomalies are detected, along with helpful suggestions.


### **4. Calendar Integration**  
StressOFF syncs with your device calendar to personalize recommendations based on daily workload:  
- **Busy days** → energizing meals, hydration and relaxation reminders  
- **Light days** → lighter meals, sleep and recovery optimization  

This ensures that guidance always adapts to the user's schedule.


### **5. AI Coach Chatbot**  
A smart conversational assistant offering:  
- Personalized health advice  
- Stress-relief exercises  
- Motivational guidance  
- Contextual recommendations based on meals, health metrics, and planned activities  

---

## 🛠 Tech Stack  

| Layer | Technology |
|-------|------------|
| **Backend** | FastAPI, Python 3.13 |
| **Frontend** | Flutter |
| **Database** | Firebase Firestore |
| **AI Models** | Qwen Vision (image), Qwen / Meta-Llama (text) via OpenRouter API |
| **Cloud & Deployment** | Microsoft Azure (App Service, Storage, Monitoring) |
| **Containerization** | Docker (backend containerization & deployment) |


---

## ⚙️ Installation & Run (Backend)

```bash
git clone https://github.com/username/stressoff.git
cd stressoff/backend
pip install -r requirements.txt

# Add your OpenRouter API key
export OPENROUTER_API_KEY="your_api_key"

# Start the backend server
uvicorn main:app --reload
