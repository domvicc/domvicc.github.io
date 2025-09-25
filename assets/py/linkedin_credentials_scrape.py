import time
import csv  # Added to fix NameError: name 'csv' is not defined
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from bs4 import BeautifulSoup

# your linkedin credentials
username = "xxxxxxxxx"
password = "xxxxxxxxx"

# set up selenium (make sure you have Chrome + chromedriver installed)
driver = webdriver.Chrome()
driver.get("https://www.linkedin.com/login")

# login
driver.find_element(By.ID, "username").send_keys(username)
driver.find_element(By.ID, "password").send_keys(password)
driver.find_element(By.ID, "password").send_keys(Keys.RETURN)

time.sleep(3)  # wait for login

# go to certifications page
driver.get("https://www.linkedin.com/in/dominicvicchiollo/details/certifications/")
time.sleep(5)  # wait for page load

# parse with beautifulsoup
soup = BeautifulSoup(driver.page_source, "html.parser")

# find certification cards
certs = soup.find_all("li", {"class": "artdeco-list__item"})

# file path to save
output_path = r"C:/Users/dominicvicchiollo/Downloads/credentials.csv"

# write to csv
with open(output_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(["Title", "Issuer", "Date", "Credential ID/Details"])
    
    for cert in certs:
        title = cert.find("h3")
        issuer = cert.find("span", {"class": "t-14"})
        date = cert.find("span", {"class": "t-14 t-normal"})
        credential = cert.find("span", {"class": "t-14 t-normal t-black--light"})
        
        title_text = title.get_text(strip=True) if title else ""
        issuer_text = issuer.get_text(strip=True) if issuer else ""
        date_text = date.get_text(strip=True) if date else ""
        credential_text = credential.get_text(strip=True) if credential else ""
        
        writer.writerow([title_text, issuer_text, date_text, credential_text])

print(f"✅ Certifications exported to {output_path}")

driver.quit()