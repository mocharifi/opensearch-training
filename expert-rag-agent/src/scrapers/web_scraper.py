import time
from selenium import webdriver
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.options import Options
from markdownify import markdownify
from scrapers.base_scraper import BaseScraper

class WebScraper(BaseScraper):
    def __init__(self, system_name):
        super().__init__(system_name)
        self.url = self.config["url"]
        self.content_selector = self.config["content_selector"]

    def fetch_content(self):
        chrome_options = Options()
        chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")

        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=chrome_options)

        driver.get(self.url)
        time.sleep(5)

        try:
            content_element = driver.find_element(By.CLASS_NAME, self.content_selector)
            extracted_html = content_element.get_attribute("outerHTML")
            extracted_text = markdownify(extracted_html)
        except Exception as e:
            print(f"Error: {e}")
            extracted_text = "Failed to extract documentation."

        driver.quit()
        return extracted_text