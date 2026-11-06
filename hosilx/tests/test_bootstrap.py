"""Render'dagi joylashuv: fayllar to'g'ridan-to'g'ri hosilx/bot/ ichida va start buyrug'i "python main.py" (paket nomi yo'q)."""
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


class Bootstrap(unittest.TestCase):
    def _run(self, folder_name: str) -> subprocess.CompletedProcess:
        with tempfile.TemporaryDirectory() as tmp:
            flat = os.path.join(tmp, "hosilx", folder_name)
            shutil.copytree(os.path.join(ROOT, "bot"), flat, ignore=shutil.ignore_patterns("__pycache__"))
            runner = textwrap.dedent(f"""
                import os, runpy, sys
                sys.path.insert(0, {os.path.join(ROOT, 'tests')!r})
                import test_import_smoke   # aiogram o'rnatilmagan bo'lsa o'rinbosarlarni o'rnatadi
                os.chdir({flat!r})
                runpy.run_path("main.py", run_name="__main__")
            """)
            secrets = ("TELEGRAM_BOT_TOKEN", "BOT_TOKEN", "SUPABASE_URL", "SUPABASE_SERVICE_KEY")
            env = {k: v for k, v in os.environ.items() if k not in secrets}
            return subprocess.run([sys.executable, "-c", runner], capture_output=True, text=True, env=env, timeout=60)

    def test_flat_layout_runs_as_script_and_reaches_config_validation(self):
        for name in ("bot", "hosil_bot_papka"):  # papka nomi ahamiyatsiz
            with self.subTest(folder=name):
                p = self._run(name)
                self.assertEqual(p.returncode, 2, p.stderr[-1000:])             # ConfigError -> 2: butun import zanjiri muvaffaqiyatli
                self.assertIn("Sozlama xatosi", p.stderr)
                self.assertNotIn("relative import", p.stderr)


if __name__ == "__main__":
    unittest.main()
