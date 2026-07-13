"""
TouchSpeak AI - Phrase Prediction Engine
=========================================
Combines three signals to recommend the next-most-likely icon/phrase
for a given user:

1. Frequency analysis   - how often the user has picked each icon overall
2. Recency weighting     - recently used icons score higher
3. Sequence model (Naive Bayes over TF-IDF of icon n-grams) - predicts the
   next icon given the last icon selected, learned from the user's own
   communication_history collection.

The model is intentionally lightweight (per-user, retrained on demand)
since a non-verbal user's communication patterns are personal and small
(tens-to-hundreds of events), not a global big-data problem.
"""
from collections import Counter
from datetime import datetime, timezone
import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.naive_bayes import MultinomialNB


class PhrasePredictor:
    def __init__(self, history: list[dict]):
        """
        history: list of communication_history documents, sorted oldest -> newest.
        Each doc looks like: {"icon_id": "food", "timestamp": datetime, ...}
        """
        self.history = history or []

    # ---------- Signal 1: frequency ----------
    def frequency_scores(self) -> dict:
        counts = Counter(h["icon_id"] for h in self.history)
        total = sum(counts.values()) or 1
        return {icon: c / total for icon, c in counts.items()}

    # ---------- Signal 2: recency ----------
    def recency_scores(self, half_life_events: int = 20) -> dict:
        """Exponential decay: most recent events weighted highest."""
        n = len(self.history)
        scores: dict[str, float] = {}
        for i, h in enumerate(self.history):
            age = n - i  # 1 = most recent
            weight = 0.5 ** (age / half_life_events)
            scores[h["icon_id"]] = scores.get(h["icon_id"], 0.0) + weight
        if scores:
            max_v = max(scores.values())
            scores = {k: v / max_v for k, v in scores.items()}
        return scores

    # ---------- Signal 3: sequence model (Naive Bayes) ----------
    def train_sequence_model(self):
        """
        Builds bigram sequences (previous_icon -> next_icon) and trains a
        Multinomial Naive Bayes classifier using TF-IDF features of the
        previous icon as a pseudo-document. Falls back gracefully when
        there isn't enough data.
        """
        icons = [h["icon_id"] for h in self.history]
        if len(icons) < 4:
            return None, None  # not enough data to train

        X_text = icons[:-1]  # previous icon as "document"
        y = icons[1:]        # next icon as label

        if len(set(y)) < 2:
            return None, None  # NB needs at least 2 classes

        vectorizer = TfidfVectorizer()
        X = vectorizer.fit_transform(X_text)
        model = MultinomialNB()
        model.fit(X, y)
        return model, vectorizer

    def sequence_scores(self) -> dict:
        model, vectorizer = self.train_sequence_model()
        if model is None or not self.history:
            return {}
        last_icon = self.history[-1]["icon_id"]
        try:
            X_last = vectorizer.transform([last_icon])
            proba = model.predict_proba(X_last)[0]
            classes = model.classes_
            return {str(cls): float(p) for cls, p in zip(classes, proba)}
        except Exception:
            return {}

    # ---------- Combine all signals ----------
    def predict_top_n(self, n: int = 3, weights=(0.4, 0.3, 0.3)) -> list[dict]:
        """
        weights = (frequency_weight, recency_weight, sequence_weight)
        Returns top-n icons with combined confidence score, e.g.:
        [{"icon_id": "water", "score": 0.82}, ...]
        """
        freq = self.frequency_scores()
        rec = self.recency_scores()
        seq = self.sequence_scores()

        all_icons = set(freq) | set(rec) | set(seq)
        if not all_icons:
            return []

        w_f, w_r, w_s = weights
        combined = {}
        for icon in all_icons:
            combined[icon] = (
                w_f * freq.get(icon, 0)
                + w_r * rec.get(icon, 0)
                + w_s * seq.get(icon, 0)
            )

        ranked = sorted(combined.items(), key=lambda x: x[1], reverse=True)[:n]
        return [{"icon_id": icon, "score": round(score, 4)} for icon, score in ranked]


def cold_start_suggestions() -> list[dict]:
    """Default suggestions for a brand-new user with no history yet."""
    defaults = ["food", "water", "help"]
    return [{"icon_id": icon, "score": 0.0} for icon in defaults]
