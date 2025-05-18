from eiogram.types import InlineKeyboardButton, InlineKeyboardMarkup

VERSION = "v0.2.0"
GITHUB = "https://github.com/erfjab/fohshgirbot"
OWNER = "ErfJab"

START_KEYBOARD = InlineKeyboardMarkup(
    [
        [InlineKeyboardButton(text="📝 توسعه‌ دهنده", url=f"https://t.me/{OWNER}")],
        [InlineKeyboardButton(text="🔍 سورس", url=GITHUB)],
        [InlineKeyboardButton(text=f"🔒 ورژن: {VERSION}", copy_text=VERSION)],
    ]
)
