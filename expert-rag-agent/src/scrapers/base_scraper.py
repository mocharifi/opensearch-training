import os
import yaml
from abc import ABC, abstractmethod

class BaseScraper(ABC):
    def __init__(self, system_name):
        with open("src/systems.yaml", "r", encoding="utf-8") as file:
            self.config = yaml.safe_load(file)[system_name]

        self.system_name = system_name
        self.output_dir = self.config["output_dir"]
        os.makedirs(self.output_dir, exist_ok=True)

    @abstractmethod
    def fetch_content(self):
        pass

    def save_markdown(self, content):
        md_file_path = os.path.join(self.output_dir, f"{self.system_name}_documentation.md")
        with open(md_file_path, "w", encoding="utf-8") as file:
            file.write(f"# {self.system_name.capitalize()} Documentation\n\n{content}")
        print(f"✅ Documentation saved at: {md_file_path}")