# Used to import the webdriver from selenium
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time

options = Options()
options.add_argument('--headless')
options.add_argument("--use-fake-ui-for-media-stream")
options.add_argument("--use-fake-device-for-media-stream")
driver = webdriver.Chrome(options=options)
driver.maximize_window()

driver.get("https://antmedia.io/webrtc-samples/")

#Testing Virtual Background Sample Page
for i in range(2):
    try:
        driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-virtual-background/', '_blank');")
        driver.switch_to.window(driver.window_handles[1])
        time.sleep(20)
        driver.switch_to.frame(0)
        time.sleep(3)
        driver.find_element(By.XPATH,"/html/body/div/div/div[4]/div[3]/img").click()
        time.sleep(5)
        driver.find_element(By.XPATH,"/html/body/div/div/div[7]/button[1]").click()
        time.sleep(15)
        driver.find_element(By.XPATH,"/html/body/div/div/div[7]/button[2]").click()
        time.sleep(3)
        print("WebRTC virtual background is successful")
        break

    except:
        if i==1:
            print("An error occurred in Vitual background test case.")
            continue

#Testing WebRTC and HLS Comparison Live Demo Page
try:
    driver.execute_script("window.open('https://antmedia.io/live-demo/', '_blank');")
    driver.switch_to.window(driver.window_handles[2])
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[1]").click()
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[2]").click()
    time.sleep(3)
    print("Live demo is successful")

except:
    print("An error occurred in live demo test case.")

#Testing WebRTC publlish Sample Page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[3])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[1]").click()
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[2]").click()
    time.sleep(3)
    print("WebRTC publish is successful")

except:
    print("An error occurred in WebRTC publish test case.")

#Testing WebRTC audio publish sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-audio-publish-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[4])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[1]").click()
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[2]").click()
    time.sleep(3)
    print("WebRTC audio publish is successful")

except:
    print("An error occurred in audio publish test case.")

#Testing WebRTC data channel sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-data-channel-only/', '_blank');")
    driver.switch_to.window(driver.window_handles[5])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[1]").click()
    time.sleep(3)
    text = driver.find_element(By.ID,'dataTextbox') 
    text.send_keys("Hello, how are you ?")
    driver.find_element(By.XPATH,"/html/body/div/div/div[3]/div/div[2]/button").click()
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[2]").click()
    time.sleep(3)
    print("WebRTC data channel is successful")

except:
    print("An error occurred in data channel test case.")

driver.quit()
