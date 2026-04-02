# filepath: /rpi3-trixie-installer/python/src/main.py
import json
import requests

def fetch_data_from_nodered(url):
    try:
        response = requests.get(url)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Error fetching data from Node-RED: {e}")
        return None

def main():
    nodered_url = "http://localhost:1880/api/data"  # Example URL for Node-RED API
    data = fetch_data_from_nodered(nodered_url)
    
    if data:
        print("Data fetched from Node-RED:")
        print(json.dumps(data, indent=4))
    else:
        print("No data retrieved.")

if __name__ == "__main__":
    main()