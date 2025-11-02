import os
from flask import Flask, request, jsonify
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException

# Initialize Flask App
app = Flask(__name__)

def get_streaming_link(imdb_id, provider_name="Prime Video"):
    """
    The core scraping logic, adapted for a server environment.
    """
    if not imdb_id or not imdb_id.startswith("tt"):
        return {"error": "Invalid or missing IMDb ID format."}

    url = f"https://www.imdb.com/title/{imdb_id}/"

    # --- Selenium Setup for Render (Linux Environment) ---
    options = webdriver.ChromeOptions()
    options.binary_location = os.environ.get("GOOGLE_CHROME_BIN") # Path to Chrome binary
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    
    # Disable images and CSS for speed
    prefs = {"profile.managed_default_content_settings.images": 2, "profile.default_content_setting_values.css": 2}
    options.add_experimental_option("prefs", prefs)
    
    # Path to chromedriver
    driver_path = os.environ.get("CHROMEDRIVER_PATH")
    driver = webdriver.Chrome(executable_path=driver_path, options=options)
    
    link = None
    try:
        driver.get(url)
        aria_label_text = f"Watch on {provider_name}"
        
        # Wait up to 10 seconds for the link to appear
        wait = WebDriverWait(driver, 10)
        link_element = wait.until(
            EC.presence_of_element_located((By.CSS_SELECTOR, f"a[aria-label='{aria_label_text}']"))
        )
        link = link_element.get_attribute('href')

    except TimeoutException:
        print(f"Timed out waiting for element with aria-label: {aria_label_text}")
        return {"error": f"Link for '{provider_name}' not found on the page."}
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        return {"error": "An internal error occurred during scraping."}
    finally:
        driver.quit()

    return {"streaming_url": link}

# --- API Endpoint ---
@app.route('/api/get-link', methods=['GET'])
def api_get_link():
    # Get imdb_id from query parameter (e.g., ?imdb_id=tt5950044)
    imdb_id = request.args.get('imdb_id')
    
    if not imdb_id:
        return jsonify({"error": "imdb_id parameter is required"}), 400

    # For this example, we'll hardcode Prime Video, but you could also
    # make the provider a query parameter.
    result = get_streaming_link(imdb_id, provider_name="Prime Video")
    
    if "error" in result:
        return jsonify(result), 404 # Not Found or other appropriate error
    
    return jsonify(result), 200

if __name__ == "__main__":
    # Port is set by Render's environment variable. Default to 10000 for local testing.
    port = int(os.environ.get('PORT', 10000))
    app.run(host='0.0.0.0', port=port)