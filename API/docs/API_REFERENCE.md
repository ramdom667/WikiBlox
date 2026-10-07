# WikiCards API Reference

## Base URL
`http://localhost:8000`

## OpenAPI Documentation
`http://localhost:8000/docs`

---

## Endpoints

### Health & Info

#### GET `/`
**Description:** Root endpoint with API information

**Response:**
```json
{
  "message": "WikiCards API Structurée",
  "version": "6.0.0",
  "architecture": "modulaire avec dossiers",
  "data_period": "3 derniers mois complets",
  "docs": "/docs",
  "health": "/health"
}
```

#### GET `/health`
**Description:** Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "service": "wikicards-structured",
  "version": "6.0.0"
}
```

#### GET `/config`
**Description:** API configuration (no sensitive data)

**Response:**
```json
{
  "api": {
    "port": 8000,
    "host": "0.0.0.0"
  },
  "wikipedia": {
    "rate_limit": 1,
    "user_agent_configured": true,
    "data_period": "3 mois complets",
    "reference_months": ["2024-07", "2024-08", "2024-09"]
  },
  "rarity_system": {
    "basis": "Total vues sur 3 mois",
    "thresholds": {
      "common": "< 1,000 vues/3 mois",
      "uncommon": "1,000 - 10,000 vues/3 mois",
      "rare": "10,000 - 100,000 vues/3 mois",
      "epic": "100,000 - 1,000,000 vues/3 mois",
      "legendary": "> 1,000,000 vues/3 mois"
    }
  }
}
```

---

## Cards Endpoints

### GET `/api/cards/random`
**Description:** Generate a random Wikipedia card with rarity system

**Response Time:** 2-3 seconds (3 API calls)

**Response Example:**
```json
{
  "success": true,
  "card": {
    "page_id": 6678,
    "title": "Cat",
    "short_description": "Small domesticated carnivorous mammal",
    "description": "The cat, also called domestic cat and house cat, is a small domesticated carnivorous mammal...",
    "image_url": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Siam_lilacpoint.jpg/330px-Siam_lilacpoint.jpg",
    "page_url": "https://en.wikipedia.org/wiki/Cat",
    "monthly_views": {
      "2024-07": 355184,
      "2024-08": 339923,
      "2024-09":288
    },
    "total_views": 1131535,
    "average_views": 377178.33,
    "reference_months": ["2024-07", "2024-08", "2024-09"],
    "rarity": "legendary",
    "rarity_emoji": "🟡"
  },
  "game_ready": {
    "card_id": "WIKI_6678_2024-09",
    "name": "Cat",
    "description": "Small domesticated carnivorous mammal",
    "image": "https://upload.wikimedia.org/wikipedia/commons/2/25/Siam_lilacpoint.jpg",
    "rarity": "legendary",
    "rarity_display": "🟡 LEGENDARY",
    "total_views": 1131535,
    "monthly_breakdown": {
      "2024-07": 355184,
      "2024-08": 339923,
      "2024-09": 436428
    }
  },
  "message": "Carte aléatoire générée avec succès",
  "metadata": {
    "response_time_ms": Cellpadding: "2085.64",
    "data_source": "Wikipedia REST API + Pageviews API",
    "rarity_basis": "Total sur 3 derniers mois complets",
    "reference_months": ["2024-07", "2024-08", "2024-09"]
  }
}
```

---

### GET `/api/cards/title/{title}`
**Description:** Search card by exact Wikipedia title

**Parameters:**
- `title` (string, required): Exact Wikipedia title (spaces → underscores)

**URL Encoding:** Required for special characters
- ✅ `Cat`
- ✅ `Albert_Einstein`
- ✅ `Quantum_mechanics`
- ❌ `Albert Einstein` (use `Albert_Einstein`)

**Response Example:** Same structure as `/api/cards/random`

---

### GET `/api/cards/examples`
**Description:** Get title examples for testing

**Response:**
```json
{
  "popular_articles": [
    "Cat",
    "Dog",
    "Paris",
    "Albert_Einstein",
    "Quantum_mechanics",
    "Python_(programming_language)",
    "French_Revolution",
    "Leonardo_da_Vinci",
    "Moon",
    "Internet"
  ],
  "how_to_use": [
    "GET /api/cards/random → Carte aléatoire",
    "GET /api/cards/title/Cat → Article sur les chats",
    "GET /api/cards/title/Paris → Article sur Paris"
  ],
  "notes": [
    "Utilisez des underscores (_) pour les espaces",
    "Les titres sont sensibles à la casse",
    "Les caractères spéciaux doivent être correctement encodés"
  ]
}
```

---

## Simple Endpoints (Fast)

### GET `/api/wikipedia/random`
**Description:** Very fast random card (no rarity)

**Response Time:** < 500ms

**Response Example:**
```json
{
  "success": true,
  "card": {
    "page_id": 6678,
    "title": "Cat",
    "description": "The cat, also called domestic cat...",
    "image": "https://upload.wikimedia.org/wikipedia/commons/thumb/2/25/Siam_lilacpoint.jpg/330px-Siam_lilacpoint.jpg",
    "url": "https://en.wikipedia.org/wiki/Cat"
  },
  "performance": {
    "response_time_ms": 342.15,
    "status": "very_fast"
  },
  "message": "Carte simple générée"
}
```

---

### GET `/api/wikipedia/title/{title}`
**Description:** Fast search by title (no rarity)

**Parameters:** Same as `/api/cards/title/{title}`

---

## Error Responses

### 404 - Article Not Found
```json
{
  "detail": "Article Wikipédia non trouvé: 'Titre'. Vérifiez le titre."
}
```

### 429 - Rate Limit Exceeded
```json
{
  "detail": "Rate limit Wikipédia"
}
```

### 503 - Wikipedia Service Unavailable
```json
{
  "detail": "Service Wikipédia indisponible"
}
```

### 500 - Internal Server Error
```json
{
  "detail": "Erreur interne: [error message]"
}
```

---

## Rarity System

### Calculation Basis
- **Period:** Last 3 complete months (July-September 2024)
- **Data:** Total views over 3 months
- **Source:** Wikipedia Pageviews API

### Thresholds
| Rarity | Emoji | Total Views (3 months) | Description |
|--------|-------|-------------------------|-------------|
| Common | ⚪ | < 1,000 | Obscure articles |
| Uncommon | 🟢 | 1,000 - 10,000 | Niche articles |
| Rare | 🔵 | 10,000 - 100,000 | Popular articles |
| Epic | 🟣 | 100,000 - 1,000,000 | Very popular articles |
| Legendary | 🟡 | > 1,000,000 | Viral articles |

### Examples
- **Cat:** 1,131,535 views → Legendary 🟡
- **Paris:** ~500,000 views → Epic 🟣
- **Ireland_during_World_War_I:** ~5,000 views → Uncommon 🟢
- **Obscure_Topic:** ~500 views → Common ⚪

---

## Configuration

### Environment Variables (`.env`)
```env
# REQUIRED: Wikipedia API User-Agent
WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (your.email@domain.com)"

# Rate limiting (requests per second)
WIKIPEDIA_RATE_LIMIT=1

# API settings
API_PORT=8000
API_HOST=0.0.0.0
RELOAD=true
```

**Critical:** User-Agent MUST contain a valid email address.

---

## Data Sources

### Wikipedia REST API
- **URL:** `https://en.wikipedia.org/api/rest_v1/page/random/summary`
- **Data:** Article title, description, image, page_id
- **Rate Limit:** ~100 requests/minute

### Pageviews API
- **URL:** `https://wikimedia.org/api/rest_v1/metrics/pageviews/`
- **Data:** Monthly view statistics (July, August, September 2024)
- **Rate Limit:** Strict (1-2 requests/second)

---

## Performance

### Cards with Rarity (`/api/cards/*`)
- **Time:** 2-3 seconds
- **API Calls:** 4 total
  - 1 × Wikipedia REST API
  - 3 × Pageviews API (1 per month)

### Simple Cards (`/api/wikipedia/*`)
- **Time:** < 500ms
- **API Calls:** 1 total
  - 1 × Wikipedia REST API

---

## Architecture

```
API/
├── main.py                # Entry point
├── requirements.txt      # Dependencies
├── .env                  # Configuration
│
├── models/              # Data models
│   └── card.py          # Pydantic schemas
│
├── services/            # Business logic
│   └── wikipedia_service.py  # External API calls
│
└── routes/              # API endpoints
    ├── cards.py        # Cards with rarity
    └── simple.py       # Fast endpoints
```

---

## Quick Start

```bash
# 1. Setup
cd API
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# 2. Configure (REQUIRED)
echo 'WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (your.email@domain.com)"' > .env

# 3. Start
./start.sh

# 4. Test
curl http://localhost:8000/api/cards/title/Cat
```

---

## Examples

### Test Cat (should be Legendary)
```bash
curl http://localhost:8000/api/cards/title/Cat | jq '.card.rarity, .card.total_views'
```

### Generate Random Card
```bash
curl http://localhost:8000/api/cards/random
```

### Fast Random Card
```bash
curl http://localhost:8000/api/wikipedia/random
```

---

**Last Updated:** October 7, 2026  
**API Version:** 6.0.0