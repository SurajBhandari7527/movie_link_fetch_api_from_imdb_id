# Use a standard Python base image
FROM python:3.10-slim

# Set the working directory in the container
WORKDIR /app

# --- START OF CORRECTED SECTION ---
# Install system dependencies, NOW INCLUDING JQ and UNZIP
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    jq \
    unzip \
    --no-install-recommends \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update && apt-get install -y \
    google-chrome-stable \
    --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*
# --- END OF CORRECTED SECTION ---

# Download and install the matching version of ChromeDriver
# This command chain can now succeed because all tools (wget, jq, unzip) are installed.
RUN CHROME_VERSION=$(google-chrome --version | cut -d " " -f3) \
    && DRIVER_VERSION_URL=$(wget -qO- "https://googlechromelabs.github.io/chrome-for-testing/known-good-versions-with-downloads.json" | jq -r ".versions[] | select(.version | startswith(\"${CHROME_VERSION%.*}\")) | .downloads.chromedriver[] | select(.platform==\"linux64\") | .url" | tail -n 1) \
    && wget -q ${DRIVER_VERSION_URL} -O chromedriver_linux64.zip \
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