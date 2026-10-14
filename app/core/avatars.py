"""
Avatar Catalog & Assignment Engine for Go-On.
Provides 16 unique illustrated minimalist avatars extracted from the design reference,
with deterministic assignment, category filtering, and validation.
"""

import hashlib
from typing import List, Dict, Optional, Any

AVATAR_CATALOG: List[Dict[str, Any]] = [
    {
        "id": "avatar_m1",
        "name": "Curly Cream Hoodie",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": True,
        "tags": ["hoodie", "curly", "casual"],
        "asset": "avatar_m1.png",
        "url": "/static/avatars/avatar_m1.png",
    },
    {
        "id": "avatar_f1",
        "name": "Wavy Blue Polo",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": True,
        "tags": ["polo", "bob", "wavy"],
        "asset": "avatar_f1.png",
        "url": "/static/avatars/avatar_f1.png",
    },
    {
        "id": "avatar_m2",
        "name": "Sharp Black Jacket",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": False,
        "tags": ["jacket", "parted", "smart"],
        "asset": "avatar_m2.png",
        "url": "/static/avatars/avatar_m2.png",
    },
    {
        "id": "avatar_m3",
        "name": "Green Tee & Glasses",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": True,
        "tags": ["glasses", "curly", "crewneck"],
        "asset": "avatar_m3.png",
        "url": "/static/avatars/avatar_m3.png",
    },
    {
        "id": "avatar_m4",
        "name": "Black Collared Shirt",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": False,
        "tags": ["button-up", "wavy", "minimal"],
        "asset": "avatar_m4.png",
        "url": "/static/avatars/avatar_m4.png",
    },
    {
        "id": "avatar_f2",
        "name": "Pink Tee with Fringe",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": False,
        "tags": ["straight", "fringe", "casual"],
        "asset": "avatar_f2.png",
        "url": "/static/avatars/avatar_f2.png",
    },
    {
        "id": "avatar_m5",
        "name": "Beige Crewneck Fade",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": False,
        "tags": ["fade", "buzz-cut", "modern"],
        "asset": "avatar_m5.png",
        "url": "/static/avatars/avatar_m5.png",
    },
    {
        "id": "avatar_f3",
        "name": "Lavender Ponytail Hoodie",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": False,
        "tags": ["ponytail", "hoodie", "sporty"],
        "asset": "avatar_f3.png",
        "url": "/static/avatars/avatar_f3.png",
    },
    {
        "id": "avatar_f4",
        "name": "Yellow Dungarees Bob",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": True,
        "tags": ["dungarees", "bob", "bangs"],
        "asset": "avatar_f4.png",
        "url": "/static/avatars/avatar_f4.png",
    },
    {
        "id": "avatar_m6",
        "name": "Green Hoodie & Round Glasses",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": True,
        "tags": ["glasses", "hoodie", "curly"],
        "asset": "avatar_m6.png",
        "url": "/static/avatars/avatar_m6.png",
    },
    {
        "id": "avatar_f5",
        "name": "Striped Top Wavy Curls",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": True,
        "tags": ["striped", "long-hair", "wavy"],
        "asset": "avatar_f5.png",
        "url": "/static/avatars/avatar_f5.png",
    },
    {
        "id": "avatar_m7",
        "name": "Blue Denim Jacket",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": False,
        "tags": ["denim", "parted", "classic"],
        "asset": "avatar_m7.png",
        "url": "/static/avatars/avatar_m7.png",
    },
    {
        "id": "avatar_m8",
        "name": "Lilac Tee Messy Bangs",
        "category": "masculine",
        "gender_presentation": "masculine",
        "is_neutral": False,
        "tags": ["lilac", "messy-hair", "casual"],
        "asset": "avatar_m8.png",
        "url": "/static/avatars/avatar_m8.png",
    },
    {
        "id": "avatar_f6",
        "name": "Turtleneck High Bun",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": False,
        "tags": ["bun", "turtleneck", "elegant"],
        "asset": "avatar_f6.png",
        "url": "/static/avatars/avatar_f6.png",
    },
    {
        "id": "avatar_f7",
        "name": "Classic Black Hijab",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": False,
        "tags": ["hijab", "modest", "warm"],
        "asset": "avatar_f7.png",
        "url": "/static/avatars/avatar_f7.png",
    },
    {
        "id": "avatar_f8",
        "name": "Terracotta Natural Curls",
        "category": "feminine",
        "gender_presentation": "feminine",
        "is_neutral": False,
        "tags": ["curly", "volume", "natural"],
        "asset": "avatar_f8.png",
        "url": "/static/avatars/avatar_f8.png",
    },
]

VALID_AVATAR_IDS = {a["id"] for a in AVATAR_CATALOG}
DEFAULT_FALLBACK_AVATAR_ID = "avatar_m1"

MASCULINE_AVATARS = [a for a in AVATAR_CATALOG if a["category"] == "masculine"]
FEMININE_AVATARS = [a for a in AVATAR_CATALOG if a["category"] == "feminine"]
NEUTRAL_AVATARS = [a for a in AVATAR_CATALOG if a.get("is_neutral", False)]


def is_valid_avatar(avatar_id: str) -> bool:
    """Validates if given avatar_id is part of the approved catalog."""
    return avatar_id in VALID_AVATAR_IDS


def get_avatar_meta(avatar_id: str) -> Optional[Dict[str, Any]]:
    """Returns avatar metadata dictionary or None."""
    for a in AVATAR_CATALOG:
        if a["id"] == avatar_id:
            return a
    return None


def resolve_avatar(avatar_id: Optional[str], identifier: Any, preference: Optional[str] = None) -> str:
    """
    Returns the user's explicit avatar if valid, or computes a deterministic
    stable fallback based on the user's identifier (roll number / ID / username).
    Guarantees stable, persistent assignment without changing across refreshes.
    """
    if avatar_id and is_valid_avatar(avatar_id):
        return avatar_id

    pool = AVATAR_CATALOG
    if preference:
        p = preference.strip().lower()
        if p == "masculine":
            pool = MASCULINE_AVATARS
        elif p == "feminine":
            pool = FEMININE_AVATARS
        elif p == "neutral":
            pool = NEUTRAL_AVATARS

    if not pool:
        pool = AVATAR_CATALOG

    # Deterministic index using MD5 of identifier
    key = str(identifier or "user_default")
    h = int(hashlib.md5(key.encode("utf-8")).hexdigest(), 16)
    idx = h % len(pool)
    return pool[idx]["id"]
