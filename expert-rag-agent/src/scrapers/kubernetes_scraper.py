import os
import time
import requests
from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.options import Options
from markdownify import markdownify
from scrapers.base_scraper import BaseScraper

class KubernetesScraper(BaseScraper):
    def __init__(self, system_name):
        super().__init__(system_name)
        self.base_url = self.config["base_url"]
        self.doc_page = self.config["doc_page"]
        self.content_selector = self.config["content_selector"]
        self.link_selector = self.config["link_selector"]

    def get_all_doc_links(self):
        """Find all documentation links from the main Kubernetes docs page."""
        response = requests.get(self.doc_page)
        if response.status_code != 200:
            print(f"❌ Error fetching {self.doc_page}")
            return []

        soup = BeautifulSoup(response.text, "html.parser")
        links = set()

        for link in soup.select(self.link_selector):
            href = link.get("href")
            if href and href.startswith("/docs/"):
                full_url = self.base_url + href
                links.add(full_url)

        return list(links)

    def fetch_content(self):
        """Scrape and merge all Kubernetes documentation pages."""
        doc_links = self.get_all_doc_links()
        content = ""

        chrome_options = Options()
        chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")

        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)

        for url in doc_links:
            try:
                driver.get(url)
                time.sleep(2)

                page_source = driver.page_source
                soup = BeautifulSoup(page_source, "html.parser")
                doc_content = soup.select_one(self.content_selector)

                if doc_content:
                    page_text = markdownify(doc_content.prettify())
                    content += f"\n\n## {url}\n\n" + page_text
                    print(f"✅ Scraped: {url}")
                else:
                    print(f"❌ No content found: {url}")

            except Exception as e:
                print(f"❌ Error scraping {url}: {e}")

        driver.quit()
        return content