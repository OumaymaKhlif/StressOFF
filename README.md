<p align="center">
  <img src="assets/images/logo.png" width="200" alt="App Logo">
</p>

![Python](https://img.shields.io/badge/python-3.13-blue)
![Flutter](https://img.shields.io/badge/flutter-3.13-blueviolet)
![License](https://img.shields.io/badge/license-MIT-green)

---

**StressOFF** est une application mobile intelligente dédiée au **bien-être et à la gestion du stress**, combinant :

- Analyse des repas via IA (Qwen Vision + modèle textuel)
- Suivi physiologique en temps réel via smartwatch
- Calendrier personnel pour recommandations contextuelles

L’objectif : **aider l’utilisateur à équilibrer son alimentation, mieux récupérer et prévenir les pics de stress ou de fatigue** grâce à une IA proactive.

---

## Fonctionnalités principales 🍽️💪🧘‍♂️

### 1. Analyse intelligente des repas
- L’utilisateur photographie son repas et sélectionne le type : petit-déjeuner, déjeuner, dîner ou collation.
- L’IA identifie les ingrédients, estime les valeurs nutritionnelles et fournit des recommandations personnalisées.
- Deux modes :
    - **Meal Analyse** : enregistrement des repas dans Firebase pour suivi quotidien
    - **Try Analyse** : analyse instantanée sans enregistrement

### 2. Synthèse et recommandations journalières
- Analyse complète en fin de journée : équilibre alimentaire global, apports caloriques, suggestions pour le lendemain.

### 3. Surveillance physiologique continue
- Fréquence cardiaque (HR), variabilité du rythme cardiaque (HRV), SpO₂, calories brûlées, minutes actives, durée et qualité du sommeil.
- Alertes immédiates si anomalie détectée avec recommandations adaptées.

### 4. Intégration du calendrier
- Connexion au calendrier du téléphone pour adapter les recommandations selon la charge de la journée :
    - Journée chargée → repas énergétiques, pauses relaxantes
    - Journée calme → repas légers, hydratation optimisée

### 5. Chatbot Coach IA
- Dialogue naturel avec l’utilisateur : conseils santé, exercices antistress, encouragements personnalisés.
- Basé sur les données nutritionnelles, physiologiques et du calendrier pour fournir un coaching contextuel et intelligent.

---

## Tech Stack 🛠️

- **Backend** : FastAPI, Python 3.13
- **Frontend** : Flutter
- **Database** : Firebase Firestore
- **IA** : Qwen Vision (images), Qwen / Meta-Llama (texte), OpenRouter API

---

## Installation & Exécution

### Backend
```bash
git clone https://github.com/username/stressoff.git
cd stressoff/backend
pip install -r requirements.txt
export OPENROUTER_API_KEY="votre_cle"
uvicorn main:app --reload
