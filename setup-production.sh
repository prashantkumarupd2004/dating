#!/bin/bash

# 🚀 PRODUCTION CONFIGURATION SCRIPT
# Run this script to generate production-ready secrets

echo "================================================"
echo "🚀 Milan Dating App - Production Setup"
echo "================================================"
echo ""

# Generate JWT secrets
echo "📝 Generating JWT secrets..."
JWT_ACCESS_SECRET=$(openssl rand -base64 32)
JWT_REFRESH_SECRET=$(openssl rand -base64 32)

echo ""
echo "✅ Generated JWT Secrets:"
echo "------------------------"
echo "JWT_ACCESS_SECRET=$JWT_ACCESS_SECRET"
echo "JWT_REFRESH_SECRET=$JWT_REFRESH_SECRET"
echo ""

# Show current configuration
echo "📋 Current Configuration Status:"
echo "------------------------"
echo "✅ Database: Configured (AWS RDS)"
echo "✅ Firebase: Configured"
echo "✅ Agora: Configured"
echo "⚠️  Redis: localhost (needs production URL)"
echo "⚠️  Razorpay: Test keys (needs production keys)"
echo "⚠️  CORS: localhost (needs production domains)"
echo ""

# Instructions
echo "📝 Next Steps:"
echo "------------------------"
echo "1. Update backend/.env with generated secrets above"
echo "2. Get production Razorpay keys from https://dashboard.razorpay.com/"
echo "3. Deploy Redis instance (AWS ElastiCache recommended)"
echo "4. Update ALLOWED_ORIGINS with production domains"
echo "5. Set NODE_ENV=production"
echo ""

# Create production .env template
cat > backend/.env.production.template << 'EOF'
# Server
NODE_ENV=production
PORT=5000

# Database (already configured)
DATABASE_URL="postgresql://milan_admin:rXU11]J0ZfTlV-KVo<dd4H*yomm_@milan-postgres.c7k444i8s7q2.ap-south-1.rds.amazonaws.com:5432/milan_db"

# Redis (UPDATE THIS)
REDIS_URL="redis://your-production-redis:6379"

# JWT (GENERATED - COPY FROM ABOVE)
JWT_ACCESS_SECRET=<paste_generated_access_secret>
JWT_REFRESH_SECRET=<paste_generated_refresh_secret>
JWT_ACCESS_EXPIRES_IN=15m
JWT_REFRESH_EXPIRES_IN=30d

# Firebase (already configured)
FIREBASE_PROJECT_ID=milan-46325
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-fbsvc@milan-46325.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCsu2sgAKstrY7n\neVlN7JaSEKVQZRKwNQKbLTpPryTUWNshvhSakgv1GZlsIf+Ujy9YzK+zgXlT/0Xv\nLhG21/tlw/J0BlYpRgiwtKqFk4mZI1e6dr+R2RJ0OKOxtbX+DTWL0kHVfKlAYOwu\nLC1zs5d4dwQeZ/h/XJjCyZugV7m1XgBShMCFwVcgRR1wn5YzVpbnYx6g0hejcomq\nJrWRS9QqTN1GzYAzCPwWw0Rsad/ro6nKO/84sZyw6lSbSDcmOMUEAi38H31eoFt4\nGjM2lb4qu6v0JDw0XvEsDXetl13L4GVX0MISo7d4P7UkEl8VjFAwyaKpqxTwt0lf\nuTHyvf2/AgMBAAECggEAGG5bzQd7LrdFJqVJxdVISLmVAEWDeqvMxhEEFeAyZ9x3\nhhLCDEjK6yxnQF2gri0AZ+FvmoaeGAzboeRUuhVbZ/3qjZGV3zmaIhAzrDf9ds0C\nbAu+tczLqOeX85s9dgT9RV0EVcNPlxz+WtuBxEMrEe1XhktzYORCcQ6d9fRifm3l\nEo1EaQq4jq2i9gdu48CaXQMMb8x3GT4+exFRLtSMBKLIR6fmw0zuG1TrCA//ZK3O\nKG1yknTTeU6C0mPbPsK8NDCBNyzEwpckb2OR0Dluu3fVTkesLafTbHZVUXz+KObh\nbtVjquUk4mPEhI5b7usaoEvmngaKl/NULln9xJ/36QKBgQDkX0dwvF7UvtqsbNv1\njUJYeXD0f3SV7yEEDo0o4VpHi+C4+hQNds1DBGX3NzO+p8v/QqZSH9sPBWKhOoKu\npcTfZxidvuYufT0BYdlaFP0kgjXL1CBHpLzQzJ4SLjVMDjBwmQjvms+sS4YnElgM\nmrwlDmS+QTEIq2l/yaXsiAF45wKBgQDBoPUtCQ2f0tJOjq7R7U4AqOzrLjlRGw9K\nADArEb6SWCtMX9SnU8BKDl+APtXXyK1KqbsR+PFYIUOCeGEuc6qYIl4xz2PCCQkf\n/iSlKS8hX4rBl0EhDrqNSb+TdT0njEA/fGgrRyhhMDbYFsHx5NJc49N2CXfj9pik\nE6WneDGBaQKBgCe4ps1mBjyMwa4x9QQ9wKdw4AO204lsoVp6SXUt1S0SmFC0Np6s\n5kDc1/tq35Yuy12nsxQftFNlhWUzrx0/egG9hduSI6k8YUsHQO3ZLrqV51N/num3\nLpxGqsvQu7Zx1V0QUSyTycFXFYtgNm5iz4zGdyFcZ3HxlpUCdtiwQ0lLAoGBAICC\nOzawk4JHgZzxxcU+Ik79zoAoJZJWy0bp6Q4ssLagHdyKnbCQPUbpUyjiizqzzY+I\nJsg+2K8NJKkrDBSwX8CozqtwYV0echfxrJCRTN5xcr4ZjPhLtjSfha5wWS4uP1Xj\nU5+lkn8uaLfyIrZQj+1mp6nnjtKVj6kWAROtCe5BAoGAemm3X2ADv83hKTt+QF4r\nl/X7bvA1UAXnsxhSEOAKNJ1G5iEnA1wqPzL4q8co/ofr5/o6wC4IuLwMpheo2dwE\nOfy8y7MeozdeesE9bSE44Nnob7eUNiNBeGR9Ebce+ePfVijc3HQI8lbZLzFtQ4ZS\nZEwR1U3AC/KHFb3CrAd1rXU=\n-----END PRIVATE KEY-----\n"

# Agora RTC (already configured)
AGORA_APP_ID=95627cb50d52477e9c4d0d10c609faff
AGORA_APP_CERTIFICATE=702785c6f84e4384ba524ddb842fa6a8

# Razorpay (GET PRODUCTION KEYS)
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxxx
RAZORPAY_KEY_SECRET=your_production_razorpay_secret

# Coin to INR conversion rate
COIN_TO_INR_RATE=0.10

# CORS (UPDATE WITH PRODUCTION DOMAINS)
ALLOWED_ORIGINS=https://admin.yourdomain.com,https://api.yourdomain.com

# Upload (UPDATE WITH CDN URL)
UPLOAD_BASE_URL=https://cdn.yourdomain.com/uploads
EOF

echo "✅ Created: backend/.env.production.template"
echo ""
echo "================================================"
echo "✅ Configuration script completed!"
echo "================================================"
