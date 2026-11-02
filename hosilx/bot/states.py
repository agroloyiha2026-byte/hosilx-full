from aiogram.fsm.state import State, StatesGroup


class Reg(StatesGroup):
    name = State(); role = State(); phone = State(); region = State()
    district = State(); business = State(); consent = State(); confirm = State()


class Search(StatesGroup):
    query = State(); wh_query = State()


class Inq(StatesGroup):
    message = State(); offer = State()


class Rep(StatesGroup):
    reason = State(); text = State()


class AddProd(StatesGroup):
    title = State(); ptype = State(); category = State(); price = State(); currency = State()
    unit = State(); quantity = State(); region = State(); photo = State(); confirm = State()


class Stor(StatesGroup):
    ptype = State(); tons = State(); message = State()


class FreeT(StatesGroup):
    tons = State()


class TaskS(StatesGroup):
    title = State(); due = State()


class Fin(StatesGroup):
    category = State(); amount = State(); currency = State(); date = State(); note = State(); confirm = State()


class AiS(StatesGroup):
    chat = State()
