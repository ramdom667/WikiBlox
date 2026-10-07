# Quick Start Guide

## 1. Prerequisites

- Python 3.8+
- Git (optional)

## 2. Installation

```bash
# Clone repository
git clone <your-repo-url>
cd WikiBlox/API

# Create virtual environment
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## 3. Configuration (CRITICAL)

**Create `.env` file:**

```bash
echo 'WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (your.real.email@domain.com)"' > .env
echo 'WIKIPEDIA_RATE_LIMIT=1' >> .env
echo 'API_PORT=8000' >> .env
```

**⚠️ IMPORTANT:** Use a REAL email address, not `example.com`!

## 4. Start the API

```bash
./start.sh
# or
python main.py
```

API will start at: `http://localhost:8000`

## 5. Verify Installation

```bash
# Check health
curl http://localhost:8000/health

# Test Cat (should return data)
curl http://localhost:8000/api/cards/title/Cat
```

## 6. Open Documentation

Open in browser: `http://localhost:8000/docs`

---

## Common Issues

### "429 Rate limit" error
- Check `.env` file has valid email
- Increase `WIKIPEDIA_RATE_LIMIT=2`
- Wait 1 minute

### "No such file or directory"
- Ensure you're in `WikiBlox/API` directory
- Run `pwd` to check

### Python not found
- Use `python3` instead of `python`
- Install Python 3.8+ if missing

---

## Next Steps

1. **Test Swagger UI** → `http://localhost:8000/docs`
2. **Generate random card** → `/api/cards/random`
3. **Search by title** → `/api/cards/title/Cat`
4. **Check configuration** → `/config`

---

**Need help?** Check the full documentation in `API_REFERENCE.md`