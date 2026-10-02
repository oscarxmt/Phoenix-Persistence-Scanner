from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

results_path = BASE_DIR / "data" / "scan_results.json"

config_path = BASE_DIR / "config.json"

if not config_path.exists():
    print(f"[X] Error: {config_path} not found. Please check if the configuration file is in the correct location.")
    exit()

if not results_path.exists():
    print(f"[X] Error: {results_path} not found. Please check if the results file is in the correct location.")
    exit()
