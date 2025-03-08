import datetime
import logging
import os
import sys
import enum
import functools


@enum.unique
class ScraperTarget(enum.StrEnum):
    Firebase = "firebase"
    SQLite = "sqlite"


@functools.cache  # cache to avoid changing time
def get_scraper_run_id() -> str:
    return f"scraper_run_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}"


def configure_logging(scraper: ScraperTarget):
    if not os.path.exists("logs"):
        os.makedirs("logs")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(f"logs/{scraper.value}_{get_scraper_run_id()}.log"),
            logging.StreamHandler(sys.stdout),
        ],
    )
