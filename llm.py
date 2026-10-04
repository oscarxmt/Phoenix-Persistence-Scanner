from pathlib import Path
import sys
BASE_DIR = Path(__file__).resolve().parent

RESULTS_PATH = BASE_DIR / "data" / "scan_results.json"

CONFIG_PATH = BASE_DIR / "config.json"

if not CONFIG_PATH.exists():
    print(f"[X] Error: {CONFIG_PATH} not found. Please check if the configuration file is in the correct location.")
    sys.exit(1)

if not RESULTS_PATH.exists():
    print(f"[X] Error: {RESULTS_PATH} not found. Please check if the results file is in the correct location.")
    sys.exit(1)

def main():
    print(f"[!] Configuration file found at: {CONFIG_PATH}")
    print(f"[!] Results file found at: {RESULTS_PATH}")
    





if __name__ == "__main__":
    main()
