import os
import sys
import types

import pytest

pytest.importorskip("aiogram")
sys.modules["supabase"] = types.SimpleNamespace(create_client=lambda *a, **k: None)
os.environ.setdefault("SUPABASE_URL", "http://localhost")
os.environ.setdefault("SUPABASE_SERVICE_KEY", "x")

import main  # noqa: E402


@pytest.mark.parametrize("name", ["T", "P", "N", "PH"])
def test_all_languages_present(name):
    d = getattr(main, name)
    assert set(d) == {"uz", "ru", "en"}


@pytest.mark.parametrize("name", ["T", "P"])
def test_same_keys_in_every_language(name):
    d = getattr(main, name)
    assert set(d["uz"]) == set(d["ru"]) == set(d["en"])


def test_menu_has_add_product_button():
    kb = main.menu_kb("uz")
    data = [b.callback_data for row in kb.inline_keyboard for b in row]
    assert "addp" in data and "market" in data
