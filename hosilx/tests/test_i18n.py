import glob
import re
import unittest

from bot.i18n import LANGS, STRINGS, _S, has_key, tr, variants
from bot.utils import ai_prompts
from bot.utils.finance import EXT_EXPENSE, EXT_INCOME, BASIC_EXPENSE, BASIC_INCOME

CODE_KEY = re.compile(r"\bt2?\(\s*[\"']([a-z0-9_]+)[\"']")
TR_KEY = re.compile(r"\btr\(\s*[^,()]+(?:\([^)]*\))?\s*,\s*[\"']([a-z0-9_]+)[\"']")
MENU_KEY = re.compile(r"menu_texts\([\"']([a-z0-9_]+)[\"']")
MENU = ("m_home", "m_market", "m_wh", "m_logistics", "m_machinery", "m_agro", "m_diary", "m_goals", "m_finance", "m_ai", "m_passport", "m_notif", "m_profile", "m_settings", "m_help")


def used_keys() -> set[str]:
    keys: set[str] = set()
    for f in glob.glob("bot/**/*.py", recursive=True):
        if f.endswith("i18n.py"):
            continue
        s = open(f, encoding="utf-8").read()
        for rx in (CODE_KEY, TR_KEY, MENU_KEY):
            keys |= set(rx.findall(s))
    return keys


class I18n(unittest.TestCase):
    def test_every_key_has_three_nonempty_texts(self):
        for k, v in _S.items():
            self.assertEqual(len(v), 3, k)
            self.assertTrue(all(x.strip() for x in v), k)

    def test_placeholders_match_across_languages(self):
        for k, v in _S.items():
            ph = [frozenset(re.findall(r"\{(\w+)\}", x)) for x in v]
            self.assertEqual(ph[0], ph[1], k)
            self.assertEqual(ph[0], ph[2], k)

    def test_html_tags_balanced(self):
        for k, v in _S.items():
            for lang, x in zip(LANGS, v):
                for tag in ("b", "i", "code"):
                    self.assertEqual(x.count(f"<{tag}>"), x.count(f"</{tag}>"), f"{lang}/{k}")
                self.assertNotRegex(re.sub(r"</?(b|i|code)>", "", x), r"[<>&]", f"{lang}/{k}")

    def test_no_mixed_scripts_inside_a_word(self):
        cyr, lat = re.compile("[\u0400-\u04FF]"), re.compile("[A-Za-z]")
        for k, v in _S.items():
            for lang, x in zip(LANGS, v):
                for w in re.findall(r"[^\W\d_]+", x):
                    self.assertFalse(cyr.search(w) and lat.search(w), f"{lang}/{k}: {w}")

    def test_all_keys_used_in_code_exist(self):
        # "fc_" + c kabi birlashtirilgan prefikslar dinamik testda tekshiriladi
        missing = sorted(k for k in used_keys() if not k.endswith("_") and not has_key(k))
        self.assertEqual(missing, [])

    def test_dynamic_keys_exist(self):
        dyn = [f"ai_{m}" for m in ai_prompts.MODES] + [f"ai_prompt_{m}" for m in ai_prompts.MODES]
        dyn += [f"fc_{c}" for c in {*BASIC_INCOME, *BASIC_EXPENSE, *EXT_INCOME, *EXT_EXPENSE}]
        dyn += ["fin_income", "fin_expense"] + [f"role_{r}" for r in ("farmer", "buyer", "warehouse_owner", "admin")]
        dyn += [f"rp_{r}" for r in ("spam", "fraud", "wrong", "other")]
        dyn += [f"st_{s}" for s in ("active", "hidden", "sold", "cold", "dry", "vegetable", "grain", "other")]
        dyn += ["notif_new_inquiry", "notif_product_approved", "notif_product_rejected", "reminder"]
        self.assertEqual(sorted(k for k in dyn if not has_key(k)), [])

    def test_menu_buttons_are_unique_across_languages(self):
        seen: dict[str, str] = {}
        for k in MENU:
            self.assertEqual(len(variants(k)), 3, k)
            for text in variants(k):
                self.assertNotIn(text, seen, f"{k} va {seen.get(text)} bir xil matn")
                seen[text] = k

    def test_tr_fallbacks(self):
        self.assertEqual(tr("xx", "cancelled"), STRINGS["uz"]["cancelled"])
        self.assertEqual(tr("ru", "no_such_key"), "no_such_key")
        self.assertIn("Ali", tr("en", "welcome_back", name="Ali"))
        self.assertIn("{name}", tr("en", "welcome_back"))  # to'ldirgichsiz chaqirilsa ham yiqilmaydi


if __name__ == "__main__":
    unittest.main()
