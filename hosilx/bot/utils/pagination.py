from __future__ import annotations
from typing import Sequence, TypeVar

T = TypeVar("T")


def paginate(items: Sequence[T], page: int, size: int) -> tuple[list[T], int, int]:
    """(sahifadagi elementlar, haqiqiy sahifa, jami sahifalar)."""
    pages = max(1, -(-len(items) // size))
    page = min(max(page, 0), pages - 1)
    return list(items[page * size:(page + 1) * size]), page, pages


def db_window(page: int, size: int) -> tuple[int, int]:
    """Supabase .range() uchun: size+1 ta qator olinadi (keyingi sahifa borligini bilish uchun)."""
    start = max(page, 0) * size
    return start, start + size


def split_extra(rows: Sequence[T], size: int) -> tuple[list[T], bool]:
    return list(rows[:size]), len(rows) > size
