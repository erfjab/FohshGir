from datetime import datetime, timedelta
from eiogram.core import Router
from eiogram.types import Message
from eiogram.utils._filters import Text, IsGroup, IsForum, IsSuperGroup
from app.config import FOHSH_PATTERNS

router = Router(name="group")


@router.message(IsGroup() | IsForum() | IsSuperGroup(), Text())
async def fohsh_handler(message: Message):
    text = message.context
    if not text:
        return None
    text = text.replace("\u200c", "")
    if not any(pattern.search(text) for pattern in FOHSH_PATTERNS):
        return

    try:
        await message.delete()
    except Exception:
        pass

    try:
        await message.mute(
            until_date=int((datetime.now() + timedelta(minutes=5)).timestamp())
        )
    except Exception:
        pass
    return
