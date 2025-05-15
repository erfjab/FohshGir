from eiogram.core import Router
from eiogram.types import Message
from eiogram.utils._filters import Command, IsPrivate
from app.config import Texts, TELEGRAM_CONTECT_ID, FOHSH, START_KEYBOARD

router = Router(name="commands")


@router.message(IsPrivate() & Command("start"))
async def start_handler(message: Message):
    return await message.answer(Texts.START, reply_markup=START_KEYBOARD)


@router.message(IsPrivate() & Command("add") | Command("del"))
async def operation_handler(message: Message):
    text = message.context
    parts = text.strip().split(maxsplit=1)
    if len(parts) < 2:
        return await message.answer(Texts.CHECK_FAILED.format(command=text))
    await message.answer(Texts.CHECK_SUCCESS)
    await message.bot.send_message(chat_id=TELEGRAM_CONTECT_ID, text=text)
    return


@router.message(IsPrivate() & Command("db"))
async def db_handler(message: Message):
    return await message.answer(" ،".join(fohsh for fohsh in FOHSH))
