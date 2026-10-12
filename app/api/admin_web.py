import os
from fastapi import APIRouter, Depends, Request, HTTPException, status
from fastapi.responses import HTMLResponse, RedirectResponse
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.config import settings
from app.api.deps import get_current_user
from app.models.user import UserRole

router = APIRouter(tags=["Admin Web Panel"])

@router.get("/admin", response_class=HTMLResponse)
def admin_panel_page(request: Request):
    template_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "templates", "admin_panel.html")
    if os.path.exists(template_path):
        with open(template_path, "r", encoding="utf-8") as f:
            return f.read()
    return "<h1>Admin Panel</h1><p>Admin panel template not found.</p>"
