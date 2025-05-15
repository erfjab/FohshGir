from decouple import config
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_API_TOKEN = config("TELEGRAM_API_TOKEN", default="", cast=str)
TELEGRAM_WEBHOOK_SECRET_KEY = config("TELEGRAM_WEBHOOK_SECRET_KEY", cast=str)
TELEGRAM_WEBHOOK_HOST = config("TELEGRAM_WEBHOOK_HOST", cast=str)
TELEGRAM_CONTECT_ID = config("TELEGRAM_CONTECT_ID", cast=str)
