"""
Limite simple du nombre d'appels par clé (ex. par joueur) sur une fenêtre glissante.

Filet de sécurité : si le jeu a un bug qui appelle l'API en boucle, un joueur
ne peut pas recevoir des centaines de cartes. Stockage en mémoire (remis à zéro au redémarrage).
"""
import threading
import time
from collections import deque
from typing import Deque, Dict, Tuple


class RateLimiter:
    def __init__(self, max_calls: int, period: float):
        self.max_calls = max_calls
        self.period = period
        self._calls: Dict[str, Deque[float]] = {}
        self._lock = threading.Lock()

    def allow(self, key: str) -> Tuple[bool, float]:
        """(autorisé, secondes à attendre si refusé). Un appel autorisé est compté."""
        now = time.monotonic()
        with self._lock:
            calls = self._calls.setdefault(key, deque())
            while calls and now - calls[0] >= self.period:
                calls.popleft()
            if len(calls) >= self.max_calls:
                return False, self.period - (now - calls[0])
            calls.append(now)
            return True, 0.0
