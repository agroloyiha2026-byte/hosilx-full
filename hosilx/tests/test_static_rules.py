"""Statik qoidalar: aiogram'ni ishga tushirmasdan ham ushlanadigan xatolar."""
import ast
import glob
import re
import unittest
import uuid

# aiogram handlerga parametrlarni NOM bo'yicha beradi: faqat quyidagilar mavjud (middleware/workflow_data/aiogram)
INJECTABLE = {"message", "cb", "event", "state", "user", "draft", "lang", "t", "repo", "ctx", "settings", "ai", "bot", "db_ok", "tg_id"}


class StaticRules(unittest.TestCase):
    def test_handlers_only_request_injectable_parameters(self):
        bad = []
        for f in sorted(glob.glob("bot/handlers/*.py")):
            for n in ast.walk(ast.parse(open(f, encoding="utf-8").read())):
                if isinstance(n, ast.AsyncFunctionDef) and n.decorator_list:
                    extra = [a.arg for a in n.args.args if a.arg not in INJECTABLE]
                    if extra:
                        bad.append((f, n.name, extra))
        self.assertEqual(bad, [])

    def test_no_mutation_of_frozen_aiogram_objects(self):
        rx = re.compile(r"\b(cb|message|event|callback)\.(data|text|message|from_user|chat|contact|photo)\s*=[^=]")
        hits = [(f, i) for f in glob.glob("bot/**/*.py", recursive=True) for i, l in enumerate(open(f, encoding="utf-8"), 1) if rx.search(l)]
        self.assertEqual(hits, [])

    def test_callback_data_within_telegram_limit(self):
        u = str(uuid.uuid4())
        samples = [f"mk:p:{u}", f"mk:i:{u}", f"mk:s:{u}", f"mk:tg:{u}", f"rp:p:{u}", f"rp:w:{u}", f"wh:d:{u}", f"wh:q:{u}", f"wh:ft:{u}",
                   f"wh:rs:{u}:a", f"tk:d:{u}", f"tk:x:{u}", "fn:ok:" + uuid.uuid4().hex, "mk:c:" + "x" * 30, "ap:c:" + "x" * 30]
        for s in samples:
            self.assertLessEqual(len(s.encode()), 64, s)

    def test_every_html_message_text_comes_from_escaped_or_static_sources(self):
        """Handlerlarda foydalanuvchi/baza maydonlari f-string ichida faqat esc(...) orqali bo'lishi kerak (taxminiy tekshiruv)."""
        risky = re.compile(r"\{(?:p|w|r|n|d|s|user|draft)\[[\"'](?:title|name|message|full_name|body|note|address|conditions|product_type|description)[\"']\]\}")
        hits = []
        for f in glob.glob("bot/handlers/*.py") + ["bot/services/notifier.py"]:
            for i, l in enumerate(open(f, encoding="utf-8"), 1):
                if risky.search(l) and "esc(" not in l and not l.strip().startswith("key = f"):  # key = f"notif_{...}" tarjima kaliti, chiqariladigan matn emas
                    hits.append((f, i))
        self.assertEqual(hits, [])


if __name__ == "__main__":
    unittest.main()
