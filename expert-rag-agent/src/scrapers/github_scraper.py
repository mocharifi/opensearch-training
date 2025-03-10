import os
import re
import shutil
import subprocess
from scrapers.base_scraper import BaseScraper

class GitHubCloneScraper(BaseScraper):
    def __init__(self, system_name):
        super().__init__(system_name)
        self.repo_url = self.config["repo_url"]
        self.branch = self.config.get("branch", "main")
        self.content_path = self.config.get("content_path", "")  # Where to extract docs
        self.filter_folders = self.config.get("filter_folders", None)  # Optional filtering
        self.tmp_dir = "/tmp/github_clone"

    def fetch_content(self):
        """Clone the GitHub repository and extract Markdown documentation."""
        # Step 1: Clone the repo
        print(f"🔄 Cloning {self.repo_url} (branch: {self.branch})...")
        if os.path.exists(self.tmp_dir):
            shutil.rmtree(self.tmp_dir)  # Clean previous clone
        subprocess.run(["git", "clone", "--branch", self.branch, "--depth", "1", self.repo_url, self.tmp_dir], check=True)

        content_dir = os.path.join(self.tmp_dir, self.content_path)
        if not os.path.exists(content_dir):
            print(f"❌ Error: Folder {content_dir} does not exist in the repo.")
            return

        # Step 2: Apply system-specific filtering logic
        if self.filter_folders:
            print(f"🔍 Filtering folders using regex: {self.filter_folders}")
            for folder in os.listdir(content_dir):
                folder_path = os.path.join(content_dir, folder)
                if os.path.isdir(folder_path) and re.match(self.filter_folders, folder):
                    target_path = os.path.join(self.output_dir, folder)
                    os.makedirs(os.path.dirname(target_path), exist_ok=True)
                    shutil.move(folder_path, target_path)
                    print(f"✅ Keeping: {folder}")
        else:
            # Copy only .md files while preserving structure
            print(f"📂 Copying all .md files from {content_dir}")
            for root, _, files in os.walk(content_dir):
                for file in files:
                    if file.endswith(".md"):
                        src_file_path = os.path.join(root, file)
                        rel_path = os.path.relpath(src_file_path, content_dir)  # Preserve folder structure
                        dest_file_path = os.path.join(self.output_dir, rel_path)

                        os.makedirs(os.path.dirname(dest_file_path), exist_ok=True)
                        shutil.copy2(src_file_path, dest_file_path)
                        print(f"✅ Copied: {dest_file_path}")

        # Step 3: Cleanup
        shutil.rmtree(self.tmp_dir)
        print(f"🗑️ Deleted temp clone at {self.tmp_dir}")