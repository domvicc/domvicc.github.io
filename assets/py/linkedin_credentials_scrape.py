# import libraries we need for web scraping and file handling
import time
import csv  # needed to write the certification data to a csv file
from selenium import webdriver  # controls the web browser automatically
from selenium.webdriver.common.by import By  # helps find elements on web pages
from selenium.webdriver.common.keys import Keys  # allows us to press keyboard keys like enter
from bs4 import BeautifulSoup  # parses html content to extract data

# put your actual linkedin login info here
username = "xxxxxxxxx"
password = "xxxxxxxxx"

# start up chrome browser and go to linkedin login page
driver = webdriver.Chrome()
driver.get("https://www.linkedin.com/login")

# automatically fill in username and password then press enter to login
driver.find_element(By.ID, "username").send_keys(username)
driver.find_element(By.ID, "password").send_keys(password)
driver.find_element(By.ID, "password").send_keys(Keys.RETURN)

time.sleep(3)  # give linkedin a few seconds to process the login

# navigate to the certifications section of dominic's profile
driver.get("https://www.linkedin.com/in/dominicvicchiollo/details/certifications/")
time.sleep(5)  # wait for the page to fully load all the certification cards

# get the html source code of the page and prepare it for data extraction
soup = BeautifulSoup(driver.page_source, "html.parser")

# find all the certification cards on the page (each cert is in a list item)
certs = soup.find_all("li", {"class": "artdeco-list__item"})

# where to save the csv file on the computer
output_path = r"C:/Users/dominicvicchiollo/Downloads/credentials.csv"

# create a new csv file and start writing certification data to it
with open(output_path, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    # write the column headers first
    writer.writerow(["Title", "Issuer", "Date", "Credential ID/Details"])
    
    # go through each certification card and extract the important info
    for cert in certs:
        # look for specific html elements that contain certification details
        title = cert.find("h3")  # certification name is usually in an h3 tag
        issuer = cert.find("span", {"class": "t-14"})  # company that issued the cert
        date = cert.find("span", {"class": "t-14 t-normal"})  # when the cert was earned
        credential = cert.find("span", {"class": "t-14 t-normal t-black--light"})  # credential id or extra details
        
        # extract the actual text from each element, or use empty string if not found
        title_text = title.get_text(strip=True) if title else ""
        issuer_text = issuer.get_text(strip=True) if issuer else ""
        date_text = date.get_text(strip=True) if date else ""
        credential_text = credential.get_text(strip=True) if credential else ""
        
        # write this certification's data as a new row in the csv file
        writer.writerow([title_text, issuer_text, date_text, credential_text])

# let the user know the scraping is complete and where the file was saved
print(f" Certifications exported to {output_path}")

# close the browser window
driver.quit()