import datetime
import logging
import os
import sys
import enum


@enum.unique
class ScraperTarget(enum.StrEnum):
    Firebase = "firebase"
    SQLite = "sqlite"


def configure_logging(scraper: ScraperTarget):
    if not os.path.exists("logs"):
        os.makedirs("logs")

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s - %(levelname)s - %(message)s",
        handlers=[
            logging.FileHandler(
                f"logs/{scraper.value}_scraper_run_{datetime.datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
            ),
            logging.StreamHandler(sys.stdout),
        ],
    )
