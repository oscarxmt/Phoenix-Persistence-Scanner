from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "data" / "report.txt"


def load_report(report_path=REPORT_PATH):
    return Path(report_path).read_text(encoding="utf-8")


def analyze_report(report_text):
    raise NotImplementedError("Configure a local model adapter in llm.py first")


def main():
    if not REPORT_PATH.exists():
        print(f"[X] Report not found: {REPORT_PATH}")
        return 1
    print(f"[i] Report ready for a local LLM: {REPORT_PATH}")
    print(f"[i] Characters available: {len(load_report())}")
    print("[i] No model is configured yet; the scanner does not download one automatically.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
