# Used to import the webdriver from selenium
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import time
import json
import requests
import subprocess

#Function to send notification to Slack
def send_slack_message(webhook_url, message, icon_emoji=":x:"):
    payload = {
        "text": message,
        "icon_emoji": icon_emoji
    }
    response = requests.post(webhook_url, data={"payload": json.dumps(payload)})

    if response.status_code != 200:
        print("Error sending Slack message: ", response.text)
    else:
        print("Slack message sent successfully!")

#Function to define and run FFMPEG
def publish_with_ffmpeg(output, rtmp_url):

# Start FFmpeg process
  ffmpeg_command = ['ffmpeg', '-re', '-f', 'lavfi', '-i', 'smptebars', '-c:v', 'libx264', '-preset', 'veryfast', '-tune', 'zerolatency', '-profile:v', 'baseline']
  ffmpeg_command += ['-c:a', 'aac', '-b:a', '128k', '-t', '30', '-f', output , rtmp_url]

  ffmpeg_process = subprocess.Popen(ffmpeg_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
  stdout, stderr = ffmpeg_process.communicate()

#Function to close the old tab and open new one
def switch_to_first_tab(driver):
    driver.close()
    driver.switch_to.window(driver.window_handles[0])

webhook_url = "https://hooks.slack.com/services/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"
icon_emoji = ":x:"

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
            message = "Virtual background test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-virtual-background/"
            send_slack_message(webhook_url, message, icon_emoji)
            continue

switch_to_first_tab(driver)

#Testing WebRTC and HLS Comparison Live Demo Page
try:
    driver.execute_script("window.open('https://antmedia.io/live-demo/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[1]").click()
    time.sleep(15)
    driver.find_element(By.XPATH,"/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[2]").click()
    time.sleep(3)
    print("Live demo is successful")

except:
    message = "Livedemo test is failed, check -> https://antmedia.io/live-demo/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

#Testing WebRTC to WebRTC Sample Page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH,"/html/body/div/div/div[7]/div[1]/a").click()
    time.sleep(5)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[2]").click()
    time.sleep(3)
    print("WebRTC to WebRTC is successful")

except:
    message = "WebRTC to WebRTC test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

#Testing WebRTC to HLS Sample Page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-publish-hls-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH,"/html/body/div/div/div[7]/div[1]/a").click()
    time.sleep(5)
    driver.find_element(By.XPATH,"/html/body/div/div/div[8]/button[2]").click()
    time.sleep(5)
    print("WebRTC to HLS is successful")

except:
    message = "WebRTC to HLS test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

#Testing WebRTC audio publish sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-audio-publish-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(5)
    driver.switch_to.frame(0)
    time.sleep(2)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[1]").click()
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[5]/div[1]/a").click()
    driver.switch_to.window(driver.window_handles[2])
    time.sleep(2)
    driver.switch_to.frame(0)
    time.sleep(2)
    driver.find_element(By.XPATH,"/html/body/div/div/div[4]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH,"/html/body/div/div/div[4]/button[2]").click()
    time.sleep(2)
    print("WebRTC audio publish is successful")

except:
    message = "WebRTC audio publish and play test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-audio-publish-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

#Testing RTMP to WebRTC sample page
try:
   driver.execute_script("window.open('https://antmedia.io/webrtc-samples/rtmp-publish-webrtc-play/', '_blank');")
   driver.switch_to.window(driver.window_handles[1])
   time.sleep(15)
   driver.switch_to.frame(0)
   time.sleep(5)
   rtmp_element = driver.find_element(By.XPATH,"/html/body/div/div/div[3]/div[1]/div")
   rtmp_url = rtmp_element.text
   output= 'flv'
   publish_with_ffmpeg(output, rtmp_url)
   print("RTMP to WebRTC is successful")

except:
    message = "RTMP to WebRTC test is failed, check -> https://antmedia.io/webrtc-samples/rtmp-publish-wertc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

#Testing RTMP to HLS sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/rtmp-publish-hls-play/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(5)
    rtmp_element = driver.find_element(By.XPATH,"/html/body/div/div/div[3]/div[1]/div")
    rtmp_url = rtmp_element.text
    output= 'flv'
    publish_with_ffmpeg(output, rtmp_url)
    print("RTMP to HLS is successful")

except:
    message = "RTMP to HLS test is failed, check -> https://antmedia.io/webrtc-samples/rtmp-publish-wertc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

#Testing WebRTC data channel sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-data-channel-only/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[1]").click()
    time.sleep(5)
    text = driver.find_element(By.ID,'dataTextbox') 
    text.send_keys("Hello, how are you ?")
    driver.find_element(By.XPATH,"/html/body/div/div/div[3]/div/div[2]/button").click()
    time.sleep(20)
    driver.find_element(By.XPATH,"/html/body/div/div/div[6]/button[2]").click()
    time.sleep(3)
    print("WebRTC data channel is successful")

except:
    message = "WebRTC data channel test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-data-channel-only/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.quit()
