from pathlib import Path
from openai import OpenAI
import subprocess

BASE_DIR = Path(__file__).resolve().parent
REPORT_PATH = BASE_DIR / "data" / "report.txt"

# I WILL COUNTINE THIS HERE AND THEN IM DONE WITH THIS PROJECT LOL FML
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
    subprocess.Popen(
        ""
        ""
    )    # add the commadn for running llama server.exe here
    # TODO start the llama localhost server before running this script.
    client = OpenAI(
        base_url="http://localhost:8080/v1",
        api_key="not-needed",
    )

    response = client.chat.completions.create(
        model="local-model",
        messages=[
            {"role": "user", "content": "Hello!"},
        ],
    )

    print(response.choices[0].message.content)




if __name__ == "__main__":
    raise SystemExit(main())
