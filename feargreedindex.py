#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Fri Feb  3 15:01:27 2023

"""

import csv
import pandas
import yfinance
import pytz
import requests
import lxml
import json
from datetime import datetime


## GETTING INFORMATION FROM CNN FEAR/GREED INDEX VIA SCRAPE
BASE_URL = "https://production.dataviz.cnn.io/index/fearandgreed/graphdata"
START_DATE = '2020-09-19'

headers = {
    'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_13_6) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36'}
r = requests.get("{}/{}".format(BASE_URL, START_DATE), headers=headers)
data = r.json()

print(json.dumps(data, indent=2))



## CONVERTING JSON DICT INTO CSV AND ALTERING 'X' TO READ AS DATETIME
fg_data = data['fear_and_greed_historical']['data']

fear_greed_values = {}

FEAR_GREED_CSV_FILENAME = '/Users/slimsheady/Desktop/fear-greed-2020-2023.csv'

with open(FEAR_GREED_CSV_FILENAME, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(['Date,,,,Fear Greed'])

    for data in fg_data:
        dt = datetime.fromtimestamp(data['x'] / 1000, tz=pytz.utc)
        fear_greed_values[dt.date()] = int(data['y'])
        writer.writerow([dt.date(), "", "", "", int(data['y'])])


        
        
        