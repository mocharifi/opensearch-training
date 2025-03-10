import argparse
import yaml
import importlib

with open("src/systems.yaml", "r", encoding="utf-8") as file:
    systems = yaml.safe_load(file)

parser = argparse.ArgumentParser(description="Run the scraper for a specific system.")
parser.add_argument("--system", type=str, choices=systems.keys(), required=True, help="System to scrape (e.g., kafka, opensearch)")
args = parser.parse_args()

system_config = systems[args.system]
scraper_module = importlib.import_module(system_config["module"])
scraper_class = getattr(scraper_module, system_config["class"])

scraper = scraper_class(args.system)
content = scraper.fetch_content()
scraper.save_markdown(content)