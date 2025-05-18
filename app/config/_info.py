from eiogram.types import InlineKeyboardButton, InlineKeyboardMarkup

VERSION = "v0.1.1"
GITHUB = "https://github.com/erfjab/fohshnadebot"
OWNER = "ErfJab"

START_KEYBOARD = InlineKeyboardMarkup(
    [
        [InlineKeyboardButton(text="📝 توسعه‌ دهنده", url=f"https://t.me/{OWNER}")],
        [InlineKeyboardButton(text="🔍 سورس", url=GITHUB)],
        [InlineKeyboardButton(text=f"🔒 ورژن: {VERSION}", copy_text=VERSION)],
    ]
)
