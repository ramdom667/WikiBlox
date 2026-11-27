"""Tests de POST /api/players/{roblox_user_id}/cards (cartes pêchées...)"""
from conftest import ADMIN_KEY, GAME_KEY

UID = 11801902852
URL = f"/api/players/{UID}/cards"
JEU = {"X-API-Key": GAME_KEY}


def corps(rarity="common", request_id="peche-0001", **extra):
    return {"rarity": rarity, "source": "peche", "request_id": request_id, "roblox_username": "Testeur", **extra}


def test_donne_une_carte_de_la_rarete_demandee(client, fake_dolibarr):
    r = client.post(URL, json=corps("rare"), headers=JEU)
    assert r.status_code == 200, r.text
    data = r.json()
    assert data["success"] is True and data["replayed"] is False
    assert data["source"] == "peche"
    assert data["card"]["rarity"] == "rare"
    assert data["card"]["title"] == "Paris"
    assert data["card"]["is_new"] is True and data["card"]["copies_owned"] == 1
    assert data["player"]["roblox_user_id"] == str(UID)
    assert data["player"]["new_player"] is True

    # Une seule carte ajoutée, avec un libellé reconnaissable dans Dolibarr
    assert len(fake_dolibarr.movements) == 1
    product_id, _, qty, label = fake_dolibarr.movements[0]
    assert product_id == 3 and qty == 1
    assert label.startswith("Peche #") and label.endswith(f"Roblox {UID}")


def test_deuxieme_exemplaire(client, fake_dolibarr):
    client.post(URL, json=corps("common", "peche-0001"), headers=JEU)
    r = client.post(URL, json=corps("common", "peche-0002"), headers=JEU)
    card = r.json()["card"]
    assert card["is_new"] is False and card["copies_owned"] == 2
    assert r.json()["player"]["new_player"] is False


def test_meme_request_id_ne_donne_pas_deux_cartes(client, fake_dolibarr):
    premier = client.post(URL, json=corps("epic", "peche-rejouee"), headers=JEU).json()
    second = client.post(URL, json=corps("epic", "peche-rejouee"), headers=JEU)
    assert second.status_code == 200
    assert second.json()["replayed"] is True
    assert second.json()["card"] == premier["card"]
    assert len(fake_dolibarr.movements) == 1


def test_meme_request_id_pour_un_autre_joueur_est_independant(client, fake_dolibarr):
    client.post(URL, json=corps("common", "peche-commune"), headers=JEU)
    r = client.post("/api/players/42/cards", json=corps("common", "peche-commune"), headers=JEU)
    assert r.json()["replayed"] is False
    assert len(fake_dolibarr.movements) == 2


def test_donnees_invalides(client, fake_dolibarr):
    assert client.post(URL, json=corps("mythique"), headers=JEU).status_code == 422
    assert client.post(URL, json={**corps(), "source": "triche"}, headers=JEU).status_code == 422
    sans_id = corps()
    del sans_id["request_id"]
    assert client.post(URL, json=sans_id, headers=JEU).status_code == 422
    assert client.post(URL, json=corps(request_id="court"), headers=JEU).status_code == 422
    assert client.post("/api/players/-1/cards", json=corps(), headers=JEU).status_code == 422
    assert fake_dolibarr.movements == []


def test_catalogue_vide_pour_la_rarete(client, fake_dolibarr):
    r = client.post(URL, json=corps("legendary"), headers=JEU)
    assert r.status_code == 503
    assert "legendary" in r.json()["detail"]
    # Rien n'est créé : ni compte joueur, ni mouvement de stock
    assert fake_dolibarr.thirdparties == {} and fake_dolibarr.movements == []


def test_erreur_dolibarr_puis_nouvel_essai(client, fake_dolibarr):
    fake_dolibarr.fail_movements = True
    r = client.post(URL, json=corps("common", "peche-reessai"), headers=JEU)
    assert r.status_code == 502
    # L'échec n'est pas mémorisé : le même request_id peut être retenté
    fake_dolibarr.fail_movements = False
    r = client.post(URL, json=corps("common", "peche-reessai"), headers=JEU)
    assert r.status_code == 200 and r.json()["replayed"] is False
    assert len(fake_dolibarr.movements) == 1


def test_limite_par_joueur(client, fake_dolibarr, monkeypatch):
    from routes import rewards
    from services.rate_limit import RateLimiter

    monkeypatch.setattr(rewards, "_limiter", RateLimiter(3, 60))
    for i in range(3):
        assert client.post(URL, json=corps(request_id=f"peche-limite-{i}"), headers=JEU).status_code == 200
    r = client.post(URL, json=corps(request_id="peche-limite-3"), headers=JEU)
    assert r.status_code == 429
    assert int(r.headers["Retry-After"]) > 0
    # Rejouer une prise déjà donnée reste possible (ne compte pas dans la limite)
    r = client.post(URL, json=corps(request_id="peche-limite-0"), headers=JEU)
    assert r.status_code == 200 and r.json()["replayed"] is True
    # Les autres joueurs ne sont pas concernés
    assert client.post("/api/players/42/cards", json=corps(request_id="peche-autre"), headers=JEU).status_code == 200


def test_authentification(client, fake_dolibarr):
    assert client.post(URL, json=corps()).status_code == 401
    assert client.post(URL, json=corps(), headers={"X-API-Key": "mauvaise"}).status_code == 403
    assert client.post(URL, json=corps(request_id="peche-admin"), headers={"X-API-Key": ADMIN_KEY}).status_code == 200


def test_rate_limiter_fenetre_glissante(monkeypatch):
    from services import rate_limit

    temps = [1000.0]
    monkeypatch.setattr(rate_limit.time, "monotonic", lambda: temps[0])
    limiter = rate_limit.RateLimiter(2, 60)
    assert limiter.allow("a")[0] and limiter.allow("a")[0]
    ok, attente = limiter.allow("a")
    assert not ok and attente == 60
    temps[0] += 30
    assert limiter.allow("a") == (False, 30)
    temps[0] += 30  # le premier appel sort de la fenêtre
    assert limiter.allow("a")[0]
