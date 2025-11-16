<p align="center"> <img src="assets/images/logo.png" width="200" alt="App Logo"> </p>
**Your Intelligent Companion for Stress Management, Nutrition, and Daily Well-Being**


---

![Python](https://img.shields.io/badge/python-3.13-blue)
![Flutter](https://img.shields.io/badge/flutter-3.13-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

---

**StressOFF** is a smart mobile application designed to enhance well-being and stress management by combining:

AI-powered meal analysis (Qwen Vision + text models)

Real-time physiological monitoring via smartwatch

Calendar integration for context-aware recommendations

Its purpose is to help users balance their diet, improve recovery, and prevent stress or fatigue peaks through proactive and intelligent assistance.

**🚀 Key Features**
**1. Smart Meal Analysis**

Users capture a photo of their meal and select the type: breakfast, lunch, dinner, or snack.

The AI detects ingredients, estimates nutritional values, and provides personalized recommendations.

Two analysis modes:

Meal Analysis – saves the meal to Firebase for daily tracking

Try Analysis – instant estimation without saving

**2. Daily Summary & Recommendations**

End-of-day analysis summarizing nutritional balance, total calorie intake, and tailored guidance for the following day.

**3. Continuous Physiological Monitoring**

Tracks heart rate (HR), heart rate variability (HRV), SpO₂, calories burned, active minutes, and sleep duration/quality.

Sends immediate alerts when anomalies are detected, along with actionable advice.

**4. Calendar Integration**

Syncs with the device’s calendar to adapt recommendations based on daily workload:

Busy day → energizing meals, recovery breaks

Light day → lighter meals, hydration reminders

**5. AI Coach Chatbot**

Natural conversational assistant providing:

Health guidance

Anti-stress exercises

Personalized motivation

Uses nutritional, physiological, and calendar data to deliver fully context-aware coaching.

**🛠 Tech Stack**

Backend: FastAPI, Python 3.13

Frontend: Flutter

Database: Firebase Firestore

AI Models: Qwen Vision, Qwen / Meta-Llama (text), OpenRouter API

**⚙️ Installation & Run**
Backend
git clone https://github.com/username/stressoff.git
cd stressoff/backend
pip install -r requirements.txt
export OPENROUTER_API_KEY="your_api_key"
uvicorn main:app --reload
