"""
Chargement du catalogue de cartes dans Dolibarr, par rareté et en quantité choisie.

Sources de candidats selon la rareté visée :
  - legendary / epic : tops mensuels Wikimedia (top 1000 des pages les plus vues)
  - rare / uncommon  : liens sortants d'articles populaires (~35 % rare, ~40 % uncommon)
  - common           : articles aléatoires (~97 % common)

Pour chaque candidat (du moins cher au plus cher) :
  1. déjà en base / déjà vu ?               -> ignoré sans appel
  2. tri : vues des 60 derniers jours        -> obtenues en masse avec la source (50-500 par appel)
  3. vues exactes juil.-sept. 2024 (1 appel) -> rareté définitive
  4. résumé de l'article (1 appel)           -> image, description
  5. enregistrement Dolibarr                 -> re-vérifie WIKI_<page_id> juste avant création
"""
import logging
import random
import threading
import time
import uuid
from collections import deque
from dataclasses import dataclass, field
from datetime import datetime
from typing import Deque, Dict, Iterator, List, Optional, Set

from models.card import CardData
from services.card_registry import register_card
from services.dolibarr_service import DolibarrService
from services.wikipedia_service import CardService, RARITIES, WikipediaService, rarity_bounds

logger = logging.getLogger("catalog")

# Les vues "récentes" (60 jours) servent uniquement à trier : on les ramène à 92 jours
# et on garde une marge, la rareté définitive vient des vues exactes de la période de référence.
RECENT_DAYS = 60
REFERENCE_DAYS = 92
SCREEN_MARGIN = 1.5

MAX_COUNT_PER_RARITY = 500
NON_ARTICLE_PREFIXES = (
    "Special:", "Wikipedia:", "File:", "Portal:", "Category:", "Template:", "Help:",
    "User:", "Talk:", "Draft:", "Module:", "MediaWiki:",
)

SOURCE_BY_RARITY = {
    "legendary": "top",
    "epic": "top",
    "rare": "links",
    "uncommon": "links",
    "common": "random",
}

# Titres des tops mensuels : données figées (2024), mises en cache pour toute la durée du process
_top_titles_cache: Optional[List[str]] = None


@dataclass
class RarityProgress:
    requested: int
    created: int = 0
    examined: int = 0          # candidats dont les vues exactes ont été vérifiées pour cette rareté
    exhausted: bool = False    # source épuisée / budget atteint avant d'avoir le compte

    def to_dict(self) -> Dict:
        return {
            "requested": self.requested,
            "created": self.created,
            "remaining": max(0, self.requested - self.created),
            "examined": self.examined,
            "exhausted": self.exhausted,
        }


@dataclass
class LoadJob:
    targets: Dict[str, int]
    id: str = field(default_factory=lambda: uuid.uuid4().hex[:12])
    status: str = "pending"    # pending | running | done | partial | cancelled | failed
    created_at: str = field(default_factory=lambda: datetime.now().isoformat())
    started_at: Optional[str] = None
    finished_at: Optional[str] = None
    progress: Dict[str, RarityProgress] = field(default_factory=dict)
    skipped_existing: int = 0  # candidats ignorés car déjà en base
    cards: List[Dict] = field(default_factory=list)
    errors: List[str] = field(default_factory=list)
    message: str = ""
    cancel_requested: bool = False

    def __post_init__(self):
        self.progress = {r: RarityProgress(requested=n) for r, n in self.targets.items()}

    def remaining(self, rarity: str) -> int:
        p = self.progress.get(rarity)
        return max(0, p.requested - p.created) if p else 0

    def add_error(self, msg: str):
        logger.warning(msg)
        if len(self.errors) < 50:
            self.errors.append(msg)

    def to_dict(self, include_cards: bool = True) -> Dict:
        requested = sum(p.requested for p in self.progress.values())
        created = sum(p.created for p in self.progress.values())
        data = {
            "job_id": self.id,
            "status": self.status,
            "targets": self.targets,
            "summary": {"requested": requested, "created": created, "skipped_existing": self.skipped_existing},
            "progress": {r: p.to_dict() for r, p in self.progress.items()},
            "created_at": self.created_at,
            "started_at": self.started_at,
            "finished_at": self.finished_at,
            "message": self.message,
            "errors": self.errors,
        }
        if include_cards:
            data["cards"] = self.cards
        return data


class CatalogLoader:
    """Exécute un LoadJob (bloquant, à lancer dans un thread)"""

    def __init__(self, job: LoadJob, wikipedia: Optional[WikipediaService] = None,
                 dolibarr: Optional[DolibarrService] = None):
        self.job = job
        self.wiki = wikipedia or WikipediaService()
        self.dolibarr = dolibarr or DolibarrService()
        self.cards = CardService(self.wiki)
        self.seen: Set[int] = set()
        self.existing: Set[int] = set()
        self.seeds: Deque[str] = deque()
        self.seed_set: Set[str] = set()

    # ------------------------------------------------------------------
    # Sources de candidats
    # ------------------------------------------------------------------

    def _top_titles(self) -> List[str]:
        global _top_titles_cache
        if _top_titles_cache is None:
            titles: Dict[str, int] = {}
            for year, month in self.wiki._get_last_three_complete_months():
                for title, views in self.wiki.get_top_articles(year, month):
                    if title == "Main_Page" or title.startswith(NON_ARTICLE_PREFIXES):
                        continue
                    titles[title] = titles.get(title, 0) + views
            # du plus vu au moins vu
            _top_titles_cache = [t for t, _ in sorted(titles.items(), key=lambda kv: -kv[1])]
        return list(_top_titles_cache)

    def _source_top(self) -> Iterator[Dict]:
        titles = self._top_titles()
        random.shuffle(titles)
        for i in range(0, len(titles), 50):
            batch = self.wiki.screen_titles(titles[i:i + 50])
            random.shuffle(batch)
            yield from batch

    def _add_seed(self, title: str):
        if title not in self.seed_set:
            self.seed_set.add(title)
            self.seeds.append(title)

    def _source_links(self) -> Iterator[Dict]:
        if not self.seeds:
            seeds = self._top_titles()
            random.shuffle(seeds)
            for t in seeds:
                self._add_seed(t)
        while self.seeds:
            seed = self.seeds.popleft()
            batch = self.wiki.screen_links(seed)
            random.shuffle(batch)
            yield from batch

    def _source_random(self) -> Iterator[Dict]:
        empty_batches = 0
        while empty_batches < 5:
            batch = self.wiki.screen_random(50)
            empty_batches = 0 if batch else empty_batches + 1
            yield from batch

    def _candidates(self, rarity: str) -> Iterator[Dict]:
        source = SOURCE_BY_RARITY[rarity]
        if source == "top":
            return self._source_top()
        if source == "links":
            return self._source_links()
        return self._source_random()

    # ------------------------------------------------------------------
    # Tri
    # ------------------------------------------------------------------

    @staticmethod
    def _passes_screen(candidate: Dict, rarity: str) -> bool:
        lo, hi = rarity_bounds(rarity)
        estimated = candidate["recent_views"] * REFERENCE_DAYS / RECENT_DAYS
        return lo / SCREEN_MARGIN <= estimated < hi * SCREEN_MARGIN

    # ------------------------------------------------------------------
    # Exécution
    # ------------------------------------------------------------------

    def run(self):
        job = self.job
        job.status = "running"
        job.started_at = datetime.now().isoformat()
        try:
            self.existing = self.dolibarr.list_wikicard_page_ids()
            self.seen = set(self.existing)
            logger.info("Job %s : %d cartes déjà en base", job.id, len(self.existing))

            # Des plus rares aux plus communes : les prises "bonus" d'une source servent aux suivantes
            for rarity in reversed(RARITIES):
                if job.cancel_requested:
                    break
                if job.remaining(rarity) > 0:
                    self._fill(rarity)

            if job.cancel_requested:
                job.status = "cancelled"
                job.message = "Chargement annulé"
            elif all(job.remaining(r) == 0 for r in job.progress):
                job.status = "done"
                job.message = "Toutes les cartes demandées ont été chargées"
            else:
                job.status = "partial"
                missing = {r: job.remaining(r) for r in job.progress if job.remaining(r)}
                job.message = f"Chargement incomplet, cartes manquantes : {missing}"
        except Exception as e:
            job.status = "failed"
            job.message = f"Erreur : {e}"
            logger.exception("Job %s en échec", job.id)
        finally:
            job.finished_at = datetime.now().isoformat()
            # Les nouvelles cartes deviennent tirables dans les boosters
            from services.booster_service import invalidate_catalog_cache
            invalidate_catalog_cache()

    def _fill(self, rarity: str):
        job = self.job
        progress = job.progress[rarity]
        budget = progress.requested * 15 + 30  # vérifications exactes max pour cette rareté
        consecutive_errors = 0

        for candidate in self._candidates(rarity):
            if job.cancel_requested or job.remaining(rarity) == 0:
                return
            if progress.examined >= budget:
                break

            page_id = candidate["page_id"]
            if candidate["disambiguation"] or page_id in self.seen:
                if page_id in self.existing:
                    job.skipped_existing += 1
                continue
            if not self._passes_screen(candidate, rarity):
                continue
            self.seen.add(page_id)

            try:
                self._process(candidate, rarity)
                consecutive_errors = 0
            except Exception as e:
                consecutive_errors += 1
                job.add_error(f"{candidate['title']} : {e}")
                if consecutive_errors >= 5:
                    raise Exception(f"5 erreurs consécutives, arrêt du chargement ({e})")

        if job.remaining(rarity) > 0:
            progress.exhausted = True

    def _process(self, candidate: Dict, searched: str):
        job = self.job
        title = candidate["title"]

        views = self.wiki.fetch_reference_views(title)
        actual, _ = self.wiki.calculate_rarity(views[1])
        job.progress[searched].examined += 1

        # Les articles populaires trouvés alimentent la source "liens"
        if actual in ("rare", "epic", "legendary"):
            self._add_seed(title)

        # Rareté demandée ? (la rareté cherchée ou une autre encore incomplète)
        if job.remaining(actual) == 0:
            return

        article = self.wiki.get_article_by_title(title)
        if not article or article.type == "disambiguation":
            return
        if article.pageid != candidate["page_id"]:
            if article.pageid in self.seen:
                return
            self.seen.add(article.pageid)

        card_dict = self.cards._build_card_from_article(article, views=views)
        card = CardData(**card_dict["card"])
        result = register_card(card, self.dolibarr)

        if result["action"] == "created":
            job.progress[actual].created += 1
            job.cards.append({
                "product_id": result["product_id"],
                "product_ref": result["product_ref"],
                "title": card.title,
                "rarity": actual,
                "total_views": card.total_views,
                "price": result["price"],
            })
            logger.info("Job %s : %s créée (%s, %d vues)", job.id, result["product_ref"], actual, card.total_views)
        else:
            job.skipped_existing += 1


# ----------------------------------------------------------------------
# Gestion des jobs (en mémoire, un seul chargement à la fois)
# ----------------------------------------------------------------------

_jobs: Dict[str, LoadJob] = {}
_jobs_lock = threading.Lock()


class JobAlreadyRunning(Exception):
    def __init__(self, job: LoadJob):
        super().__init__(f"Un chargement est déjà en cours ({job.id})")
        self.job = job


def get_running_job() -> Optional[LoadJob]:
    return next((j for j in _jobs.values() if j.status in ("pending", "running")), None)


def start_load_job(targets: Dict[str, int]) -> LoadJob:
    """Crée et lance un chargement en arrière-plan"""
    with _jobs_lock:
        running = get_running_job()
        if running:
            raise JobAlreadyRunning(running)
        job = LoadJob(targets=targets)
        loader = CatalogLoader(job)  # lève ValueError si Dolibarr n'est pas configuré
        _jobs[job.id] = job

    threading.Thread(target=loader.run, name=f"catalog-{job.id}", daemon=True).start()
    return job


def get_job(job_id: str) -> Optional[LoadJob]:
    return _jobs.get(job_id)


def list_jobs() -> List[LoadJob]:
    return sorted(_jobs.values(), key=lambda j: j.created_at, reverse=True)
