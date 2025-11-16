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


# 🚀 Key Features


## 1. Authentication & Profile

### 🔐 Authentication (Signup / Login)



<table>
<tr>
<td width="45%">

Users can easily create an account and securely log in using Firebase Authentication.  
This step initializes user preferences and prepares personalized tracking.

</td>
<td width="55%">

<img src="assets/images/Login_SignUp.png"  width="350" height="700" alt="Signup Page">


</td>
</tr>
</table>

---

## 2. Calendar Integration

<table>
<tr>
<td width="55%">

### 📅 Calendar-Aware Insights  
StressOFF syncs with the device calendar to adjust recommendations based on daily workload:  
- **Busy days** → energizing meals, hydration, stress-relief breaks  
- **Light days** → lighter meals, sleep optimization, recovery tips  

Guidance always adapts to the user's lifestyle and schedule.

</td>
<td width="45%">

<img src="assets/screenshots/calendar.png" width="260" alt="Calendar Integration">

</td>
</tr>
</table>

---

## 3. Real-Time Physiological Monitoring

<table>
<tr>
<td width="55%">

### ❤️ Real-Time Health Monitoring  
When paired with a smartwatch, StressOFF tracks key physiological metrics:  
- Heart Rate (HR)  
- Heart Rate Variability (HRV)  
- Blood Oxygen Level (SpO₂)  
- Active minutes & burned calories  
- Sleep duration and quality  

The system sends **instant alerts** when anomalies appear, along with actionable advice.

</td>
<td width="45%">

<img src="assets/screenshots/dashboard.png" width="260" alt="Dashboard">

</td>
</tr>
</table>

---

## 4. Daily Summary & Personalized Recommendations

<table>
<tr>
<td width="55%">

### 📊 Daily Summary  
Each evening, the app generates a personalized recap including:  
- Total calorie intake  
- Nutritional balance  
- Excesses and deficiencies  
- Tailored recommendations for the next day  

This helps users maintain healthy and consistent eating habits.

</td>
<td width="45%">

<img src="assets/screenshots/history.png" width="260" alt="History Page">

</td>
</tr>
</table>

---

## 5. AI Coach Chatbot

<table>
<tr>
<td width="55%">

### 🤖 AI Wellness Coach  
A smart conversational assistant offering:  
- Personalized health and nutrition advice  
- Stress-relief exercises  
- Motivation and gentle reminders  
- Context-aware suggestions based on meals, health metrics, and daily plan  

</td>
<td width="45%">

<img src="assets/screenshots/coach.png" width="260" alt="AI Coach Page">

</td>
</tr>
</table>

---

## 6. Smart Meal Analysis (AI-Powered)

<table>
<tr>
<td width="55%">
### 🍽️ Smart Meal Analysis  
StressOFF allows users to take a photo of their meal and instantly receive:  
- Ingredient detection  
- Nutritional estimation  
- Personalized dietary advice  

**Two analysis modes:**  
- **Meal Analysis** — saves the evaluation to Firebase  
- **Quick Analysis** — instant analysis without saving  

</td>
<td width="45%">

<img src="assets/screenshots/meals.png" width="260" alt="Meals Page">

</td>
</tr>
</table>


---

### 👤 User Profile

<table>
<tr>
<td width="55%">

The Profile page displays personal information, health preferences, and allows users to adjust their stress or nutrition goals.

</td>
<td width="45%">

<img src="assets/screenshots/profile.png" width="260" alt="Profile Page">

</td>
</tr>
</table>


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
