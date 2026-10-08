# Dolibarr ERP Integration - WikiCards

## 📋 Overview

WikiCards API automatically stores cards as products in Dolibarr ERP, creating a unified inventory system.

---

## 🏗️ Architecture

```
API → Dolibarr ERP
  ↓
[Card Generation] → [Product Creation] → [Inventory Management]
```

**Business Model:**
- **One Wikipedia page** = **One unique product** in Dolibarr
- **Reference format:** `WIKI_{page_id}` (ex: `WIKI_6678` for "Cat")
- **No duplicates:** Each card created only once
- **Rarity & metadata:** Stored as custom fields

---

## 🔗 API Endpoints (Dolibarr)

### **Test Connection**
```http
GET /api/dolibarr/test-connection
```
**Response:**
```json
{
  "success": true,
  "details": {
    "status_code": 200,
    "message": "Connexion API Dolibarr réussie"
  }
}
```

---

### **Check if Card Exists**
```http
GET /api/dolibarr/check-card/{page_id}
```
**Example:** `GET /api/dolibarr/check-card/6678` (for Cat)

**Response if exists:**
```json
{
  "exists": true,
  "match_type": "exact_ref",
  "page_id": 6678,
  "product_ref": "WIKI_6678",
  "product": {
    "id": "14",
    "ref": "WIKI_6678",
    "label": "Cat - Carte Wikipédia",
    "price": "887.41"
  },
  "message": "Carte trouvée (ID: 14)"
}
```

**Response if not exists:**
```json
{
  "exists": false,
  "match_type": "none",
  "page_id": 6678,
  "product_ref": "WIKI_6678",
  "message": "Carte non trouvée dans Dolibarr"
}
```

---

### **Register Card Manually**
```http
POST /api/dolibarr/register-card
```
**Request Body:** Complete card data (from `/api/cards/title/{title}` or `/api/cards/random`)

**Response (new card):**
```json
{
  "success": true,
  "action": "created",
  "product_id": 17,
  "product_ref": "WIKI_2876475",
  "card_title": "Leaburu",
  "rarity": "common",
  "price": 2.32,
  "details": {
    "message": "Nouveau produit créé dans Dolibarr"
  }
}
```

**Response (duplicate):**
```json
{
  "success": true,
  "action": "already_exists",
  "product_id": 14,
  "product_ref": "WIKI_6678",
  "message": "Produit déjà existant dans Dolibarr"
}
```

---

### **Auto-Generate & Register**
```http
GET /api/dolibarr/auto-random
```
**Combined endpoint:** Generates random card + registers in Dolibarr

**Response:**
```json
{
  "success": true,
  "card": { /* Full card data */ },
  "dolibarr_integration": { /* Registration result */ },
  "message": "Carte générée et enregistrée dans Dolibarr"
}
```

---

### **Get Card Metadata**
```http
GET /api/dolibarr/card/{page_id}/metadata
```
**Example:** `GET /api/dolibarr/card/6678/metadata` (for Cat)

**Response:**
```json
{
  "success": true,
  "page_id": 6678,
  "product_id": 14,
  "product_ref": "WIKI_6678",
  "metadata": {
    "wikicards_version": "1.0",
    "wikipedia": {
      "page_id": 6678,
      "title": "Cat",
      "short_description": "Small domesticated carnivorous mammal",
      "full_description": "The cat, also called domestic cat..."
    },
    "statistics": {
      "monthly_views": {
        "2024-07": 355184,
        "2024-08": 339923,
        "2024-09": 436428
      },
      "total_views": 1131535,
      "rarity": "legendary",
      "rarity_text": "legendary"
    }
  }
}
```

---

### **Get Dolibarr Statistics**
```http
GET /api/dolibarr/products/stats
```
**Response:**
```json
{
  "success": true,
  "stats": {
    "total_products": 500,
    "total_wikicards": openTokenType,
    "percentage_wikicards": 10.5,
    "total_value": 25432.50,
    "average_price": 45.20,
    "rarity_distribution": {
      "legendary": 3,
      "epic": 12,
      "rare":106,
      "uncommon": 245,
      "common": 534
    }
  }
}
```

---

### **Get Dolibarr Configuration**
```http
GET /api/dolibarr/config
```
**Response:**
```json
{
  "dolibarr_url": "http://localhost:8080",
  "product_category": "WikiCards",
  "default_vat_rate": "20.0",
  "api_key_configured": true,
  "notes": [
    "La clé API est masquée pour des raisons de sécurité",
    "La catégorie 'WikiCards' doit être créée manuellement dans Dolibarr"
  ]
}
```

---

## 🗃️ Data Storage in Dolibarr

### **Product Structure**
```json
{
  "ref": "WIKI_6678",
  "label": "Cat - Carte Wikipédia",
  "description": "Small domesticated carnivorous mammal\n\nFull description...",
  "type": 0,
  "status": 1,
  "price": 887.41,
  "url": "https://en.wikipedia.org/wiki/Cat",
  
  // Custom fields (structured data)
  "array_options": {
    "options_wikipedia_page_id": 6678,
    "options_wikipedia_title": "Cat",
    "options_wikicards_rarity": "legendary",
    "options_wikicards_total_views": 1131535,
    "options_wikicards_average_views": 377178.33,
    "options_wikicards_reference_months": "2024-07,2024-08,2024-09"
  },
  
  // Full metadata (JSON)
  "note_private": "{\"wikicards_version\":\"1.0\",\"wikipedia\":{\"page_id\":6678,\"title\":\"Cat\"...}}"
}
```

---

## ⚙️ Configuration

### **Environment Variables**
```env
# Dolibarr ERP Configuration
DOLIBARR_URL=http://localhost:8080
DOLIBARR_API_KEY=your_dolibarr_api_key_here
DOLIBARR_PRODUCT_CATEGORY=WikiCards
DOLIBARR_DEFAULT_VAT_RATE=20.0

# Wikipedia API Configuration
WIKIPEDIA_USER_AGENT="WikiCards-IAMSI (your.email@domain.com)"
WIKIPEDIA_RATE_LIMIT=1

# API Server Configuration
API_PORT=8000
API_HOST=0.0.0.0
RELOAD=true
```

### **Dolibarr Setup Requirements**
1. **Enable modules:** Produits/Services, Stocks, Tiers
2. **Create API user:** With `GET`, `POST`, `PUT` permissions
3. **Generate API key:** From Dolibarr settings
4. **Create category:** "WikiCards" manually in Dolibarr UI

---

## 🔄 Workflow Examples

### **1. Manual Registration**
```bash
# Generate card
curl http://localhost:8000/api/cards/title/Cat > cat.json

# Extract card data
card_data=$(cat cat.json | jq '.card')

# Register in Dolibarr
curl -X POST http://localhost:8000/api/dolibarr/register-card \
  -H "Content-Type: application/json" \
  -d "$card_data"
```

### **2. Auto Workflow**
```bash
# Single command: generate + register
curl http://localhost:8000/api/dolibarr/auto-random

# Check if card exists
curl http://localhost:8000/api/dolibarr/check-card/6678

# Get metadata
curl http://localhost:8000/api/dolibarr/card/6678/metadata
```

---

## 🛠️ Integration Tips

### **Duplicate Prevention**
- Cards are identified by `page_id`
- Reference: `WIKI_{page_id}` (no month suffix)
- If duplicate detected → returns existing product data

### **Price Calculation**
Based on rarity:
- **Common:** 1-5€
- **Uncommon:** 5-15€  
- **Rare:** 15-50€
- **Epic:** 50-200€
- **Legendary:** 200-1000€

### **Data Recovery**
All metadata can be reconstructed from:
1. **JSON in `note_private`** (preferred)
2. **Custom fields in `array_options`** (fallback)
3. **Parsing `label` and `description`** (last resort)

---

## 🔍 Testing

### **Connection Test**
```bash
curl http://localhost:8000/api/dolibarr/test-connection
```

### **Create Test Card**
```bash
# Test with Cat (should be Legendary)
curl http://localhost:8000/api/dolibarr/auto-random | jq '.card.title, .card.rarity'
```

### **Verify in Dolibarr UI**
1. Open Dolibarr at `http://localhost:8080`
2. Navigate to `Produits/Services` → `Liste des produits`
3. Search for "WIKI_" prefix
4. Verify `Cat - Carte Wikipédia` exists with correct price

---

## 📊 Field Mapping

| Wikipedia Field | Dolibarr Field | Type | Example |
|----------------|----------------|------|---------|
| `page_id` | `array_options.options_wikipedia_page_id` | Integer | `6678` |
| `title` | `array_options.options_wikipedia_title` | String (64 chars) | `"Cat"` |
| `rarity` | `array_options.options_wikicards_rarity` | String | `"legendary"` |
| `total_views` | `array_options.options_wikicards_total_views` | Integer | `1131535` |
| Full metadata | `note_private` | JSON | Complete card data |
| Display name | `label` | String | `"Cat - Carte Wikipédia"` |
| Short description | `description` | Text | First 200 chars |

---

## ⚠️ Known Issues & Solutions

### **1. UTF-8 Encoding (Emoji Error)**
**Problem:** `Incorrect string value: '\xF0\x9F\x9F\xA1'`
**Cause:** Dolibarr MariaDB uses UTF8, not UTF8MB4
**Solution:** No emojis in stored data (converted to text)

### **2. Category Permissions**
**Problem:** `401 Unauthorized` when creating category
**Cause:** API user lacks category permissions
**Solution:** Create "WikiCards" category manually in UI

### **3. Duplicate Detection**
**Works:** Based on `WIKI_{page_id}` reference
**Note:** Previous cards with month suffix won't be detected

---

## 🚀 Next Steps

### **Phase 3 Planned Features**
1. **Stock management:** Track copies per player
2. **Player accounts:** Create tiers (clients) in Dolibarr
3. **Transaction history:** Track card trades
4. **Reporting:** Generate inventory reports

---

**Last Updated:** October 8, 2026  
**Integration Version:** 1.0.0