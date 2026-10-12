"""Go-On branding shared by the PDF and Excel report renderers.

Single source for the product name and the official-logo asset so both exports
always show the same brand. Presentation only - no report data lives here.
"""
from __future__ import annotations

import logging
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

BRAND_NAME = "Go-On"

# Official Go-On logo on its Espresso tile (derived from the same supplied logo
# as the mobile/web assets by scripts/generate_go_on_brand_assets.py).
_BADGE_PATH = Path(__file__).resolve().parent.parent / "assets" / "branding" / "go_on_badge.png"


def badge_path() -> Optional[Path]:
    """Path to the logo badge, or None (with a warning) if the asset is missing.

    Callers must still render the "Go-On" text so a missing asset never breaks
    report generation.
    """
    if _BADGE_PATH.is_file():
        return _BADGE_PATH
    logger.warning("Go-On logo asset missing at %s; exporting text-only branding", _BADGE_PATH)
    return None
