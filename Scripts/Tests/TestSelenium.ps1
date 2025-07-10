# Start a new Chrome session
$driver=Start-SeChrome

# Navigate to a URL
Enter-SeUrl -Url "https://www.google.com" -Driver $driver

# Close the browser and the driver session
#Stop-SeDriver -Driver $driver
