#!/bin/bash
set -e

echo "🚀 Setting up Homepage development environment..."

# Check prerequisites
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed. Aborting." >&2; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed. Aborting." >&2; exit 1; }

echo "✅ Prerequisites check passed"

# Check for pnpm
if ! command -v pnpm >/dev/null 2>&1; then
  echo "⚠️  pnpm not found. Installing pnpm globally..."
  npm install -g pnpm
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
  echo "📝 Creating .env file from template..."
  cp .env.example .env
  echo "✅ .env file created. You may want to customize it."
else
  echo "✅ .env file already exists"
fi

# Build frontend dependencies (for faster first startup)
if [ ! -d "frontend/node_modules" ]; then
  echo "📦 Installing frontend dependencies..."
  cd frontend
  pnpm install
  cd ..
  echo "✅ Frontend dependencies installed"
else
  echo "✅ Frontend dependencies already installed"
fi

# Start services
echo "🐳 Starting Docker Compose services..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

echo ""
echo "⏳ Waiting for services to be healthy..."
sleep 10

# Check service health
echo "🏥 Checking service health..."
docker-compose -f docker-compose.yml -f docker-compose.dev.yml ps

echo ""
echo "================================================"
echo "✨ Development environment is ready!"
echo "================================================"
echo ""
echo "📍 Access points:"
echo "  Frontend:    http://localhost:5173 (HMR enabled)"
echo "  Backend API: http://localhost:8000"
echo "  Vault UI:    http://localhost:8200 (token: dev-root-token)"
echo "  PostgreSQL:  localhost:5432 (user: postgres, pass: postgres)"
echo "  ValKey:      localhost:6379"
echo "  MinIO:       http://localhost:9001 (user: minioadmin, pass: minioadmin)"
echo ""
echo "📊 Logs:"
echo "  View all:    docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f"
echo "  Backend:     docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f backend"
echo "  Frontend:    docker-compose -f docker-compose.yml -f docker-compose.dev.yml logs -f frontend"
echo ""
echo "🛑 Stop:"
echo "  docker-compose -f docker-compose.yml -f docker-compose.dev.yml down"
echo ""
echo "Happy coding! 🎉"
