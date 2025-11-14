# 🚀 Script de démarrage du serveur CSTAM Backend FastAPI

Write-Host "🚀 Démarrage du serveur CSTAM Backend..." -ForegroundColor Green

# 1️⃣ Vérifier si l'environnement virtuel existe
if (-Not (Test-Path "venv")) {
    Write-Host "❌ Environnement virtuel non trouvé. Création..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "✅ Environnement virtuel créé" -ForegroundColor Green
}

# 2️⃣ Activer l'environnement virtuel
Write-Host "🔧 Activation de l'environnement virtuel..." -ForegroundColor Cyan
.\venv\Scripts\Activate.ps1

# 3️⃣ Installer ou mettre à jour les dépendances
Write-Host "📦 Installation des dépendances..." -ForegroundColor Cyan
pip install --upgrade pip
pip install -r requirements.txt --quiet

# 4️⃣ Lancer le serveur FastAPI avec uvicorn
Write-Host "✅ Lancement du serveur sur http://0.0.0.0:8000" -ForegroundColor Green
Write-Host "📡 Documentation API: http://0.0.0.0:8000/docs" -ForegroundColor Cyan
Write-Host "⚡ Appuyez sur Ctrl+C pour arrêter" -ForegroundColor Yellow
Write-Host ""

uvicorn main:app --host 0.0.0.0 --port 8000
