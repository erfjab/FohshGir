from logging import getLogger
from typing import Dict, Any

from uvicorn import Config, Server
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from eiogram.core._dispatcher import Dispatcher
from eiogram.types._update import Update

from app.config import (
    BOT,
    TELEGRAM_WEBHOOK_HOST,
    TELEGRAM_WEBHOOK_SECRET_KEY,
    UVICORN_SSL_KEYFILE,
    UVICORN_SSL_CERTFILE,
    UVICORN_PORT,
)
from app.routers import setup_routers

app = FastAPI()
logger = getLogger(__name__)
dp = Dispatcher(bot=BOT)


@app.post("/api/webhook")
async def handle_webhook(request: Request) -> JSONResponse:
    """Handle incoming Telegram webhook updates."""
    try:
        update_data: Dict[str, Any] = await request.json()
        update: Update = Update.from_dict(update_data)
        await dp.process(update)
    except Exception as e:
        logger.error(f"Failed to process update: {str(e)}", exc_info=True)
    return JSONResponse(content={"status": "processed"}, status_code=200)


async def setup_application() -> None:
    """Configure application components."""
    dp.include_router(setup_routers())
    await BOT.set_webhook(
        url=TELEGRAM_WEBHOOK_HOST,
        secret_token=TELEGRAM_WEBHOOK_SECRET_KEY,
        allowed_updates=["message"],
    )


async def main() -> None:
    """Entry point for the application."""
    await setup_application()
    config = Config(
        app=app,
        host="0.0.0.0",
        port=UVICORN_PORT,
        ssl_certfile=UVICORN_SSL_CERTFILE,
        ssl_keyfile=UVICORN_SSL_KEYFILE,
        workers=1,
    )
    server = Server(config)
    await server.serve()
