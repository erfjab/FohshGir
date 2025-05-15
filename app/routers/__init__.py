from eiogram.core._router import Router
from . import _commands, _group


def setup_routers() -> Router:
    router = Router()
    router.include_router(_commands.router)
    router.include_router(_group.router)
    return router


__all__ = ["setup_routers"]
