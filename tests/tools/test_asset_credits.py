"""Issue #29: the credits audit passes on the repo and detects missing rows, unknown licences, missing files."""
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools" / "validation"))
import check_asset_credits as cc  # noqa: E402


class Credits(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        (self.tmp / "docs").mkdir()
        shutil.copy(ROOT / "docs/ASSET_CREDITS.md", self.tmp / "docs/ASSET_CREDITS.md")
        shutil.copytree(ROOT / "assets/generated", self.tmp / "assets/generated", ignore=shutil.ignore_patterns("*.png", "*.import"))
        for f in ("scripts/presentation/sfx_bank.gd", "scripts/presentation/fixture_presenter.gd"):
            (self.tmp / f).parent.mkdir(parents=True, exist_ok=True)
            (self.tmp / f).write_text("x")

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def edit(self, old, new):
        p = self.tmp / "docs/ASSET_CREDITS.md"
        p.write_text(p.read_text(encoding="utf-8").replace(old, new, 1), encoding="utf-8")

    def test_repo_passes(self):
        self.assertEqual(cc.problems(ROOT), [])

    def test_all_twenty_eight_fixtures_and_three_customers_are_listed(self):
        ids = {r["asset_id"] for r in cc.parse(ROOT)}
        self.assertEqual(len([i for i in ids if i.startswith("fixture_")]), 28)
        self.assertEqual(len([i for i in ids if i.startswith("customer_")]), 3)

    def test_a_row_with_the_wrong_cell_count_is_reported(self):
        ledger = self.tmp / "docs" / "ASSET_CREDITS.md"
        ledger.write_text(ledger.read_text(encoding="utf-8") + "\n|short_row|assets/generated|code|yes|\n", encoding="utf-8")
        self.assertTrue(any("short_row: ledger row has 4 cells" in p for p in cc.problems(self.tmp)))

    def test_unlisted_asset_is_found(self):
        (self.tmp / "assets/generated/fixtures/new_thing").mkdir()
        self.assertTrue(any("without a ledger row" in p for p in cc.problems(self.tmp)))

    def test_unknown_license_and_redistribution(self):
        self.edit("自作(箱ジオメトリ、外部素材・テクスチャなし)。プロジェクトのライセンスに従う", "unknown")
        self.assertTrue(any("licence unknown" in p for p in cc.problems(self.tmp)))
        self.edit("|yes|", "|no|")
        self.assertTrue(any("redistribution" in p for p in cc.problems(self.tmp)))

    def test_missing_file_and_bad_source_type(self):
        self.edit("assets/generated/fixtures/shelf_bread", "assets/generated/fixtures/shelf_gone")
        probs = cc.problems(self.tmp)
        self.assertTrue(any("path missing" in p for p in probs))
        self.edit("|Blender|tools/assets/figures.py", "|magic|tools/assets/figures.py")
        self.assertTrue(any("unknown source_type" in p for p in cc.problems(self.tmp)))

    def test_ui_icon_set_is_listed_with_its_provenance(self):
        rows = {r["asset_id"]: r for r in cc.parse(ROOT)}
        self.assertIn("ui_icons", rows)
        self.assertEqual(rows["ui_icons"]["path"], "assets/ui/icons")
        self.assertEqual(rows["ui_icons"]["redistribution"], "yes")
        svgs = sorted(p.name for p in (ROOT / "assets/ui/icons").glob("*.svg"))
        self.assertGreaterEqual(len(svgs), 25)   # the README must name every icon, however many there are
        readme = (ROOT / "assets/ui/icons/README.md").read_text(encoding="utf-8")
        for name in svgs:
            self.assertIn(name[:-4], readme, "README names " + name)

    def test_ai_rows_need_a_prompt_or_link(self):
        self.edit("|Blender|tools/assets/figures.py", "|AI|tools/assets/figures.py")
        self.assertTrue(any("need the prompt" in p for p in cc.problems(self.tmp)))


if __name__ == "__main__":
    unittest.main()
