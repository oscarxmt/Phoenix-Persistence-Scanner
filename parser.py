import os
from pathlib import Path


RESULTS_DIR = Path(__file__).resolve().parent 
REPORT_DIR = RESULTS_DIR / "Report.txt"


def parser():
    print("[!] Parsering Json Results to Report...")


def main():
    parser()

if __name__ == "__main__":
    main()