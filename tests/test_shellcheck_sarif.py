"""Tests for the shellcheck to SARIF converter."""

import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "tools"))

import shellcheck_sarif


class ConvertTest(unittest.TestCase):
    def test_converts_a_json1_document(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "shellcheck.json"
            target = Path(tmp) / "shellcheck.sarif"
            source.write_text(
                json.dumps(
                    {
                        "comments": [
                            {
                                "file": "script.sh",
                                "line": 2,
                                "endLine": 2,
                                "column": 6,
                                "endColumn": 15,
                                "level": "warning",
                                "code": 2086,
                                "message": "Double quote to prevent globbing.",
                            }
                        ]
                    }
                ),
                encoding="utf-8",
            )

            self.assertEqual(
                shellcheck_sarif.main(["sarif", str(source), str(target)]), 0
            )
            document = json.loads(target.read_text(encoding="utf-8"))
            run = document["runs"][0]
            self.assertEqual(run["tool"]["driver"]["name"], "ShellCheck")
            self.assertEqual(run["results"][0]["ruleId"], "SC2086")
            self.assertEqual(run["results"][0]["level"], "warning")

    def test_rejects_a_non_list(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "bad.json"
            target = Path(tmp) / "out.sarif"
            source.write_text('{"comments": 3}', encoding="utf-8")
            self.assertEqual(
                shellcheck_sarif.main(["sarif", str(source), str(target)]), 1
            )


if __name__ == "__main__":
    unittest.main()
