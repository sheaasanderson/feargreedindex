# Analyzing Historical Fear & Greed Indexes

I want to collect historical Fear & Greed Index values for the last 10+ years and compare them to the S&P 500 stock prices.

## Description

The Fear & Greed Index is a relatively new gauge of market sentiment. But I'm wondering how the S&P 500 stock prices rise and fall in relation to the FGI values. Ideally, I'll find patterns that can direct stock buying/selling behavior based on the FGI index categories. 

## Getting Started

### Dependencies

* Python libraries: csv, pandas, yfinance, pytz, lxml, json, datetime
* MySQL

### Installing
```
import csv
import pandas
import yfinance
import pytz
import requests
import lxml
import json
from datetime import datetime
```

## Version History

* 0.1
    * Initial Release

## License

N/A

## Acknowledgments

Prior FGI Values Data (2011-2020) courtesy of: 
* [hackingthemarkets](https://github.com/hackingthemarkets/sentiment-fear-and-greed/blob/master/datasets/fear-greed.csv)
