import os
import time
import json
import shlex
import requests
import subprocess
import urllib.parse
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC


# Function to send notification to Slack
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


# Function to start FFMPEG process
def publish_with_ffmpeg(url, protocol='rtmp'):
    if protocol == 'rtmp':
        # Start FFmpeg process for RTMP streaming
        quoted_url = shlex.quote(url)
        ffmpeg_command = 'ffmpeg -re -f lavfi -i smptebars -c:v libx264 -preset veryfast -tune zerolatency -profile:v baseline -c:a aac -b:a 128k -t 30 -f flv' + ' ' + quoted_url
        ffmpeg_args = shlex.split(ffmpeg_command)
        ffmpeg_process = subprocess.Popen(ffmpeg_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = ffmpeg_process.communicate()

    elif protocol == 'srt':
        # Start FFmpeg process for SRT streaming
        quoted_url = urllib.parse.quote(url, safe=':/?=')
        ffmpeg_command = 'ffmpeg -f lavfi -re -i smptebars=duration=60:size=1280x720:rate=30 -f lavfi -re -i sine=frequency=1000:duration=60:sample_rate=44100 -pix_fmt yuv420p -c:v libx264 -b:v 1000k -g 30 -keyint_min 120 -profile:v baseline -preset veryfast -t 30 -f mpegts udp://127.0.0.1:5000?pkt_size=1316'
        ffmpeg_args = shlex.split(ffmpeg_command)
        ffmpeg_process = subprocess.Popen(ffmpeg_args, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        srt_command = ['srt-live-transmit', 'udp://127.0.0.1:5000', '-t', '30', quoted_url]
        srt_process = subprocess.Popen(srt_command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        stdout, stderr = ffmpeg_process.communicate()
        srt_stdout, srt_stderr = srt_process.communicate()
        srt_exit_code = srt_process.returncode
        return srt_exit_code


# Function to close the previous tabs before starting the new test
def switch_to_first_tab(driver):
    if len(driver.window_handles) > 1:
        driver.close()
        driver.switch_to.window(driver.window_handles[0])


# Function to remove advertisement from sample pages
def remove_ad(driver):
    wait = WebDriverWait(driver, 10)
    button = wait.until(EC.element_to_be_clickable((By.XPATH, "/html/body/div[2]/div/button")))
    button.click()

# Function to switch to new window and close the advertisement block
def switch_window_and_frame(driver):
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(2)
    remove_ad(driver)
    time.sleep(15)
    driver.switch_to.frame(0)
    time.sleep(3)

webhook_url = os.environ['WEBHOOK_URL']
icon_emoji = ":x:"

options = Options()
options.add_argument('--headless')
options.add_argument("--use-fake-ui-for-media-stream")
options.add_argument("--use-fake-device-for-media-stream")
driver = webdriver.Chrome(options=options)
driver.maximize_window()

driver.get("https://antmedia.io/webrtc-samples/")
remove_ad(driver)

# Testing Virtual Background Sample Page
for i in range(2):
    try:
        driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-virtual-background/', '_blank');")
        driver.switch_to.window(driver.window_handles[1])
        time.sleep(2)
        remove_ad(driver)
        time.sleep(20)
        driver.switch_to.frame(0)
        time.sleep(3)
        driver.find_element(By.XPATH, "/html/body/div/div/div[4]/div[3]/img").click()
        time.sleep(5)
        driver.find_element(By.XPATH, "/html/body/div/div/div[7]/button[1]").click()
        time.sleep(15)
        driver.find_element(By.XPATH, "/html/body/div/div/div[7]/button[2]").click()
        time.sleep(3)
        print("WebRTC virtual background is successful")
        break

    except:
        if i==1:
            message = "Virtual background test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-virtual-background/"
            send_slack_message(webhook_url, message, icon_emoji)
            continue

switch_to_first_tab(driver)

# Testing WebRTC and HLS Comparison Live Demo Page
try:
    driver.execute_script("window.open('https://antmedia.io/live-demo/', '_blank');")
    driver.switch_to.window(driver.window_handles[1])
    time.sleep(2)
    remove_ad(driver)
    time.sleep(15)
    driver.find_element(By.XPATH, "/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[1]").click()
    time.sleep(15)
    driver.find_element(By.XPATH, "/html/body/div/div/article[2]/div[2]/div[1]/div[1]/div/div/p/button[2]").click()
    time.sleep(3)
    print("Live demo is successful")

except:
    message = "Livedemo test is failed, check -> https://antmedia.io/live-demo/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

# Testing WebRTC to WebRTC Sample Page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/', '_blank');")
    switch_window_and_frame(driver)
    driver.find_element(By.XPATH, "/html/body/div/div/div[8]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH, "/html/body/div/div/div[7]/div[1]/a").click()
    time.sleep(5)
    driver.find_element(By.XPATH, "/html/body/div/div/div[8]/button[2]").click()
    time.sleep(3)
    print("WebRTC to WebRTC is successful")

except:
    message = "WebRTC to WebRTC test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-publish-webrtc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

# Testing WebRTC to HLS Sample Page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-publish-hls-play/', '_blank');")
    switch_window_and_frame(driver)
    driver.find_element(By.XPATH, "/html/body/div/div/div[8]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH, "/html/body/div/div/div[7]/div[1]/a").click()
    time.sleep(5)
    driver.find_element(By.XPATH, "/html/body/div/div/div[8]/button[2]").click()
    time.sleep(5)
    print("WebRTC to HLS is successful")

except:
    message = "WebRTC to HLS test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-publish-hls-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

# Testing WebRTC audio publish sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-audio-publish-play/', '_blank');")
    switch_window_and_frame(driver)
    driver.find_element(By.XPATH, "/html/body/div/div/div[6]/button[1]").click()
    time.sleep(3)
    driver.find_element(By.XPATH, "/html/body/div/div/div[5]/div[1]/a").click()
    driver.switch_to.window(driver.window_handles[2])
    time.sleep(2)
    driver.switch_to.frame(0)
    time.sleep(2)
    driver.find_element(By.XPATH, "/html/body/div/div/div[4]/button[1]").click()
    time.sleep(10)
    driver.find_element(By.XPATH, "/html/body/div/div/div[4]/button[2]").click()
    time.sleep(2)
    print("WebRTC audio publish and play is successful")

except:
    message = "WebRTC audio publish test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-audio-publish-play/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.close()
driver.switch_to.window(driver.window_handles[1])
switch_to_first_tab(driver)

# Testing RTMP to WebRTC sample page
try:
   driver.execute_script("window.open('https://antmedia.io/webrtc-samples/rtmp-publish-webrtc-play/', '_blank');")
   switch_window_and_frame(driver)
   rtmp_element = driver.find_element(By.XPATH, "/html/body/div/div/div[3]/div[1]/div")
   url = rtmp_element.text
   publish_with_ffmpeg(url, protocol='rtmp')
   print("RTMP to WebRTC is successful")

except:
    message = "RTMP to WebRTC test is failed, check -> https://antmedia.io/webrtc-samples/rtmp-publish-wertc-play/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

# Testing RTMP to HLS sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/rtmp-publish-hls-play/', '_blank');")
    switch_window_and_frame(driver)
    rtmp_element = driver.find_element(By.XPATH, "/html/body/div/div/div[3]/div[1]/div")
    url = rtmp_element.text
    publish_with_ffmpeg(url, protocol='rtmp')
    print("RTMP to HLS is successful")

except:
    message = "RTMP to HLS test is failed, check -> https://antmedia.io/webrtc-samples/rtmp-publish-hls-play/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

# Testing SRT to WebRTC sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/srt-publish-webrtc-play/', '_blank');")
    switch_window_and_frame(driver)
    srt_element = driver.find_element(By.XPATH, "/html/body/div/div/div[3]/div[1]/div")
    url = srt_element.text
    srt_exit_code = publish_with_ffmpeg(url, protocol='srt')
    if srt_exit_code == 0:
        print("SRT to WebRTC is successful")
    else:
        raise Exception("SRT to WebRTC test is failed")

except:
    message = "SRT to WebRTC test is failed, check -> https://antmedia.io/webrtc-samples/srt-publish-webrtc-play/"
    send_slack_message(webhook_url, message, icon_emoji)
                          
switch_to_first_tab(driver)
                  
# Testing SRT to HLS sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/srt-publish-hls-play/', '_blank');")
    switch_window_and_frame(driver)
    srt_element = driver.find_element(By.XPATH, "/html/body/div/div/div[3]/div[1]/div")
    url = srt_element.text
    srt_exit_code = publish_with_ffmpeg(url, protocol='srt')
    if srt_exit_code == 0:
        print("SRT to HLS is successful")
    else:
        raise Exception("SRT to HLS test is failed")

except:
    message = "SRT to HLS test is failed, check -> https://antmedia.io/webrtc-samples/srt-publish-hls-play/"
    send_slack_message(webhook_url, message, icon_emoji)

switch_to_first_tab(driver)

# Testing WebRTC data channel sample page
try:
    driver.execute_script("window.open('https://antmedia.io/webrtc-samples/webrtc-data-channel-only/', '_blank');")
    switch_window_and_frame(driver)
    driver.find_element(By.XPATH, "/html/body/div/div/div[6]/button[1]").click()
    time.sleep(5)
    text = driver.find_element(By.ID, 'dataTextbox')
    text.send_keys("Hello, how are you ?")
    driver.find_element(By.XPATH, "/html/body/div/div/div[3]/div/div[2]/button").click()
    time.sleep(20)
    driver.find_element(By.XPATH, "/html/body/div/div/div[6]/button[2]").click()
    time.sleep(3)
    print("WebRTC data channel is successful")

except:
    message = "WebRTC data channel test is failed, check -> https://antmedia.io/webrtc-samples/webrtc-data-channel-only/"
    send_slack_message(webhook_url, message, icon_emoji)

driver.quit()
