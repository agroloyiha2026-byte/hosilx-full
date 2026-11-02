"""Hududlar (web va mobil ilova bilan bir xil o'zbekcha qiymatlar bazada saqlanadi)."""
REGIONS = ["Toshkent shahri", "Toshkent viloyati", "Andijon", "Buxoro", "Farg'ona", "Jizzax", "Xorazm", "Namangan", "Navoiy",
           "Qashqadaryo", "Qoraqalpog'iston", "Samarqand", "Sirdaryo", "Surxondaryo"]
_NAMES = {
    "Toshkent shahri": ("Ташкент (город)", "Tashkent city"), "Toshkent viloyati": ("Ташкентская область", "Tashkent region"),
    "Andijon": ("Андижан", "Andijan"), "Buxoro": ("Бухара", "Bukhara"), "Farg'ona": ("Фергана", "Fergana"), "Jizzax": ("Джизак", "Jizzakh"),
    "Xorazm": ("Хорезм", "Khorezm"), "Namangan": ("Наманган", "Namangan"), "Navoiy": ("Навои", "Navoi"), "Qashqadaryo": ("Кашкадарья", "Kashkadarya"),
    "Qoraqalpog'iston": ("Каракалпакстан", "Karakalpakstan"), "Samarqand": ("Самарканд", "Samarkand"), "Sirdaryo": ("Сырдарья", "Syrdarya"),
    "Surxondaryo": ("Сурхандарья", "Surkhandarya"),
}


def region_label(value: str, lang: str) -> str:
    n = _NAMES.get(value)
    return value if not n else (n[0] if lang == "ru" else n[1] if lang == "en" else value)


def region_by_index(i: int) -> str | None:
    return REGIONS[i] if 0 <= i < len(REGIONS) else None
