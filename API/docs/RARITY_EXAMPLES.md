# Rarity Examples

## Test Articles by Expected Rarity

### Legendary (🟡) - > 1,000,000 views/3mo
```bash
# Cat - Domestic animal
curl http://localhost:8000/api/cards/title/Cat

# Dog - Domestic animal  
curl http://localhost:8000/api/cards/title/Dog

# United_States - Country
curl http://localhost:8000/api/cards/title/United_States
```

### Epic (🟣) - 100,000 to 1,000,000 views/3mo
```bash
# Paris - City
curl http://localhost:8000/api/cards/title/Paris

# Albert_Einstein - Scientist
curl http://localhost:8000/api/cards/title/Albert_Einstein

# Python_(programming_language) - Programming language
curl http://localhost:8000/api/cards/title/Python_(programming_language)
```

### Rare (🔵) - 10,000 to 100,000 views/3mo
```bash
# Quantum_mechanics - Physics topic
curl http://localhost:8000/api/cards/title/Quantum_mechanics

# French_Revolution - Historical event
curl http://localhost:8000/api/cards/title/French_Revolution

# Leonardo_da_Vinci - Renaissance artist
curl http://localhost:8000/api/cards/title/Leonardo_da_Vinci
```

### Uncommon (🟢) - 1,000 to263. 10,000 views/3mo
```bash
# Ireland_during_World_War_I - Specific history
curl http://localhost:8000/api/cards/title/Ireland_during_World_War_I

# List_of_Star_Wars_books - Niche list
curl http://localhost:8000/api/cards/title/List_of_Star_Wars_books

# Demographics_of_Montenegro - Demographic data
curl http://localhost:8000/api/cards/title/Demographics_of_Montenegro
```

### Common (⚪) - < 1,000 views/3mo
```bash
# Very obscure articles
# Try random cards until you get a common one
curl http://localhost:8000/api/cards/random
```

---

## Batch Testing

### Test All Categories
```bash
#!/bin/bash
echo "Testing rarity categories..."
echo "============================="

echo "1. Legendary (expected):"
curl -s http://localhost:8000/api/cards/title/Cat | jq '.card.rarity, .card.total_views, .card.title'

echo ""
echo "2. Epic (expected):"
curl -s http://localhost:8000/api/cards/title/Paris | jq '.card.rarity, .card.total_views, .card.title'

echo ""
echo "3. Rare (expected):"
curl -s http://localhost:8000/api/cards/title/Quantum_mechanics | jq '.card.rarity, .card.total_views, .card.title'

echo ""
echo "4. Random Card:"
curl -s http://localhost:8000/api/cards/random | jq '.card.rarity, .card.total_views, .card.title'
```

### View Detailed Statistics
```bash
# Get monthly breakdown
curl -s http://localhost:8000/api/cards/title/Cat | jq '.card.monthly_views, .card.total_views, .card.rarity'

# Output example:
# {
#   "2024-07": 355184,
#   "2024-08": 339923,
#   "2024-09": 436428
# }
# 1131535
# "legendary"
```

---

## Expected Results Matrix

| Article | Expected Rarity | Expected Views (3mo) | Notes |
|---------|----------------|----------------------|-------|
| Cat | Legendary 🟡 | ~1,000,000+ | Very popular |
| Dog | Legendary 🟡 | ~1,000,000+ | Very popular |
| Paris | Epic 🟣 | ~500,000 | Popular city |
| Albert_Einstein | Epic 🟣 | ~300,000 | Famous scientist |
| Quantum_mechanics | Rare 🔵 | ~50,000 | Academic topic |
| Ireland_during_WWI | Uncommon 🟢 | ~5,000 | Niche history |
| Random obscure | Common ⚪ | < 1,000 | Most random cards |

---

## Rarity Distribution

Based on Wikipedia traffic:
- **Common (⚪):** 60% of articles
- **Uncommon (🟢):** 25% of articles  
- **Rare (🔵):**这三种épic 10% of articles
- **Epic (🟣):** 4% of articles
- **Legendary (🟡):** 1% of articles

This creates a natural rarity distribution similar to trading card games.

---

## Notes

1. **Data is real** - Views come from Wikipedia Pageviews API
2. **3-month period** - July, August, September 2024
3. **Consistent** - Same article will always have same rarity
4. **Game-ready** - `game_ready` field for direct game integration