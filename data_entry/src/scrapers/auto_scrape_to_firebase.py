import datetime
import sys
import subprocess


def get_terms():
    terms_map = (
        [["Spring"]] * 3
        + [["Fall", "FirstSummer", "SecondSummer", "ExtendedSummer"]] * 3
        + [["Fall", "SecondSummer", "ExtendedSummer"]] * 1
        + [["Fall"]] * 3
        + [["Spring"]] * 2
    )
    now = datetime.datetime.now()
    year = now.year - (1 if now.month <= 3 else 0)
    terms = terms_map[now.month - 1]
    return [(term, year) for term in terms]


def main():
    for term, year in get_terms():
        print(f"Starting scraper with term={term}, year={year}")
        subprocess.run(
            f"poetry run python src/scrapers/scrape_to_firebase.py -t {term} -y {year} --no-ssh",
            shell=True,
        )


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nOperation cancelled by user. Exiting...")
        sys.exit(0)
