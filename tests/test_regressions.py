import contextlib
import io
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import uuid

import report_generator
import risk_rules


class RiskReportTests(unittest.TestCase):
    def run_report(self, findings, *options):
        with tempfile.TemporaryDirectory() as directory:
            source = Path(directory) / "scan.json"
            report = Path(directory) / "report.txt"
            original = json.dumps({"results": findings, "errors": []})
            source.write_text(original, encoding="utf-8")
            with contextlib.redirect_stdout(io.StringIO()):
                result = risk_rules.main([
                    "--input", str(source), "--report", str(report), *options,
                ])
            self.assertEqual(result, 0)
            self.assertEqual(source.read_text(encoding="utf-8"), original)
            return report.read_text(encoding="utf-8")

    def test_normal_findings_are_assessed_without_saved_risk(self):
        finding = {
            "type": "Service", "name": "Example", "location": "test",
            "command": "powershell.exe -e AAAA", "enabled": True, "evidence": {},
        }
        report = self.run_report([finding])
        self.assertIn("1 findings flagged for review", report)
        self.assertIn("[SUSPICIOUS] Example", report)
        self.assertIn("PowerShell encoded command", report)

    def test_empty_report(self):
        self.assertIn("No command rules matched", self.run_report([]))

    def test_all_includes_unknown_findings(self):
        report = self.run_report([{"name": "Ordinary", "command": "example.exe"}], "--all")
        self.assertIn("[UNKNOWN] Ordinary", report)

    def test_saved_verdict_is_recomputed(self):
        report = self.run_report([{
            "name": "Example", "command": "mshta.exe",
            "risk": {"verdict": "clean", "reasons": []},
        }])
        self.assertIn("[SUSPICIOUS] Example", report)


class PowerShellRuleTests(unittest.TestCase):
    def test_encoded_command_abbreviations(self):
        for executable in ("powershell.exe", "pwsh.exe"):
            for switch in ("e", "en", "enc", "EncodedComm", "EncodedCommand"):
                with self.subTest(executable=executable, switch=switch):
                    self.assertTrue(risk_rules.check_encoded_powershell({
                        "command": f"{executable} -NoProfile -{switch} AAAA",
                    }))

    def test_unrelated_switches_and_executables_do_not_match(self):
        for command in (
            "powershell.exe -ExecutionPolicy Bypass",
            "powershell.exe -EncodedArguments AAAA",
            "powershell.exe -File example.ps1",
            "example.exe -enc AAAA",
        ):
            with self.subTest(command=command):
                self.assertEqual(risk_rules.check_encoded_powershell({"command": command}), [])


class SignaturePathTests(unittest.TestCase):
    def test_supported_paths_reach_signature_checker(self):
        paths = [
            r"C:\Windows\System32\drivers\example.sys",
            r"\SystemRoot\System32\drivers\example.sys",
            r"System32\drivers\example.sys",
            r"%SystemRoot%\System32\drivers\example.sys",
            r"\\server\share\example.sys",
            r"C:\Program Files\Example\example.exe",
        ]
        data = {"results": [{"command": f'"{path}"'} for path in paths]}
        with patch.object(report_generator.subprocess, "run") as run:
            run.return_value.returncode = 0
            run.return_value.stdout = "[]"
            report_generator.verify_binaries(data)
        submitted = [json.loads(line) for line in run.call_args.kwargs["input"].splitlines()]
        self.assertEqual(submitted, paths)
        for path in paths:
            with self.subTest(path=path):
                match = report_generator.PATH_PATTERN.search(path)
                self.assertIsNotNone(match)
                self.assertEqual(match.group("unquoted"), path)

    @unittest.skipUnless(os.name == "nt", "Uses Windows PowerShell")
    def test_driver_paths_resolve_and_missing_files_are_reported(self):
        filename = f"phoenix-test-{uuid.uuid4().hex}.sys"
        paths = [
            rf"\SystemRoot\System32\drivers\{filename}",
            rf"System32\drivers\{filename}",
        ]
        results = report_generator.verify_binaries({
            "results": [{"command": path} for path in paths],
        })
        self.assertEqual(len(results), 2)
        expected = Path(os.environ["SystemRoot"]) / "System32" / "drivers" / filename
        for original, result in zip(paths, results):
            self.assertEqual(result["original_path"], original)
            self.assertEqual(Path(result["path"]), expected)
            self.assertEqual(result["error"], "File does not exist")


if __name__ == "__main__":
    unittest.main()
