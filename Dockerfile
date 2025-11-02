# Use a standard Python base image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# --- START OF CORRECTED CHROME INSTALLATION ---
# Install necessary system dependencies using the modern, reliable method.
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    --no-install-recommends \
    # 1. Download Google's signing key and save it to the trusted keyrings directory
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    # 2. Add the Google Chrome repository to the sources list, signed by the new key
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    # 3. Update package lists and install Chrome
    && apt-get update && apt-get install -y \
    google-chrome-stable \
    --no-install-recommends \
    # 4. Clean up the apt cache to keep the image small
    && rm -rf /var/lib/apt/lists/*
# --- END OF CORRECTED CHROME INSTALLATION ---

# This part for chromedriver can remain similar, but let's make it more robust.
RUN CHROME_VERSION=$(google-chrome --version | cut -d " " -f3) \
    && DRIVER_VERSION=$(wget -qO- "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | jq -r ".versions[] | select(.version | startswith(\"${CHROME_VERSION%.*}\")) | .downloads.chromedriver[0].url" | tail -n 1) \
    && wget -q ${DRIVER_VERSION} -O chromedriver_linux64.zip \
    && unzip chromedriver_linux64.zip \
    && mv chromedriver-linux64/chromedriver /usr/bin/chromedriver \
    && chmod +x /usr/bin/chromedriver \
    && rm -rf chromedriver_linux64.zip chromedriver-linux64

# Set environment variables for the Python app to find Chrome and the driver
ENV GOOGLE_CHROME_BIN=/usr/bin/google-chrome-stable
ENV CHROMEDRIVER_PATH=/usr/bin/chromedriver

# Copy and install Python requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the Flask app code into the container
COPY . .

# Set the command to run the application using gunicorn
CMD ["gunicorn", "--bind", "0.0.0.0:10000", "app:app"]